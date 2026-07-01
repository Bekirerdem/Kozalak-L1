// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {KozaCollection} from "../src/KozaCollection.sol";

/**
 * @title ERC721CollectionHandler
 * @notice Foundry invariant testing handler. Bounded random calls into KozaCollection.
 * @dev Mints and transfers between actors. Phase ve fiyat değişiklikleri owner tarafından
 *      yapılır. Invariant runner her tx sonrası invariant fonksiyonlarını çağırır.
 */
contract ERC721CollectionHandler is Test {
    KozaCollection public nft;
    address public owner;
    address[] public actors;

    uint256 public callCount;

    /// @notice Toplam kontrata ödenen ETH (mint ile). Withdraw'lar ayrı tutulur.
    uint256 public totalPaid;

    /// @notice Owner tarafından çekilen toplam ETH (cumulative).
    uint256 public totalWithdrawn;

    constructor(KozaCollection _nft, address _owner, address[] memory _actors) {
        nft = _nft;
        owner = _owner;
        actors = _actors;

        // Faz başlangıçta Public — handler basit kalsın diye
        vm.prank(owner);
        nft.setPhase(KozaCollection.Phase.Public);
    }

    function _pickActor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    /// @notice Random public mint by an actor.
    function publicMint(uint256 actorSeed, uint256 quantity) external {
        callCount++;
        address actor = _pickActor(actorSeed);

        uint256 maxSupply = nft.maxSupply();
        uint256 minted = nft.totalMinted();
        if (minted >= maxSupply) return;

        uint256 walletMinted = nft.mintedPerWallet(actor);
        uint256 maxPerWallet = nft.MAX_PER_WALLET();
        if (walletMinted >= maxPerWallet) return;

        uint256 maxQty = maxSupply - minted;
        uint256 walletRoom = maxPerWallet - walletMinted;
        uint256 cap = maxQty < walletRoom ? maxQty : walletRoom;

        quantity = bound(quantity, 1, cap);
        uint256 cost = nft.mintPrice() * quantity;

        vm.deal(actor, cost);

        vm.prank(actor);
        try nft.publicMint{value: cost}(quantity) {
            totalPaid += cost;
        } catch {}
    }

    /// @notice Random NFT transfer between actors.
    function transfer(uint256 fromSeed, uint256 toSeed, uint256 idSeed) external {
        callCount++;
        address from = _pickActor(fromSeed);
        address to = _pickActor(toSeed);

        uint256 balance = nft.balanceOf(from);
        if (balance == 0) return;

        // Token id'leri 1..totalMinted aralığında. From'un sahip olduğu bir id'yi bul.
        uint256 totalMinted = nft.totalMinted();
        if (totalMinted == 0) return;

        uint256 startId = (idSeed % totalMinted) + 1;
        uint256 foundId;
        for (uint256 i = 0; i < totalMinted; i++) {
            uint256 candidate = ((startId - 1 + i) % totalMinted) + 1;
            if (nft.ownerOf(candidate) == from) {
                foundId = candidate;
                break;
            }
        }
        if (foundId == 0) return;

        vm.prank(from);
        try nft.transferFrom(from, to, foundId) {} catch {}
    }

    /// @notice Owner withdraw kontratı boşaltır.
    function withdraw() external {
        callCount++;
        uint256 balance = address(nft).balance;
        if (balance == 0) return;

        vm.prank(owner);
        try nft.withdraw(payable(owner)) {
            totalWithdrawn += balance;
        } catch {}
    }
}

/**
 * @title ERC721CollectionInvariantTest
 * @notice Stateful fuzzing invariants for KozaCollection.
 *
 *         Tested invariants:
 *         1. totalMinted <= maxSupply
 *         2. sum(balanceOf(actors)) == totalMinted (no token leaks)
 *         3. contract.balance == totalPaid - totalWithdrawn
 *         4. owner immutable during fuzz
 */
contract ERC721CollectionInvariantTest is Test {
    KozaCollection internal nft;
    ERC721CollectionHandler internal handler;
    address internal owner;
    address[] internal actors;

    string internal constant NAME = "Koza Genesis";
    string internal constant SYMBOL = "KOZA";
    string internal constant BASE_URI = "ipfs://QmExampleCID/";
    uint256 internal constant MAX_SUPPLY = 50;
    uint256 internal constant MINT_PRICE = 0.01 ether;
    uint96 internal constant ROYALTY_BPS = 500;

    function setUp() public {
        owner = makeAddr("owner");

        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
        actors.push(makeAddr("charlie"));
        actors.push(makeAddr("dave"));
        actors.push(makeAddr("eve"));

        address royalty = makeAddr("royalty");
        nft = new KozaCollection(NAME, SYMBOL, BASE_URI, MAX_SUPPLY, MINT_PRICE, royalty, ROYALTY_BPS, owner);
        handler = new ERC721CollectionHandler(nft, owner, actors);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.publicMint.selector;
        selectors[1] = handler.transfer.selector;
        selectors[2] = handler.withdraw.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_TotalMintedDoesNotExceedMaxSupply() public view {
        assertLe(nft.totalMinted(), nft.maxSupply(), "totalMinted > maxSupply");
    }

    function invariant_SumOfBalancesEqualsTotalMinted() public view {
        uint256 sum;
        for (uint256 i = 0; i < actors.length; i++) {
            sum += nft.balanceOf(actors[i]);
        }
        assertEq(sum, nft.totalMinted(), "sum(balances) != totalMinted (token leak)");
    }

    function invariant_ContractBalanceMatchesPaidMinusWithdrawn() public view {
        assertEq(
            address(nft).balance, handler.totalPaid() - handler.totalWithdrawn(), "contract balance != paid - withdrawn"
        );
    }

    function invariant_OwnerDoesNotChange() public view {
        assertEq(nft.owner(), owner, "owner mutated unexpectedly");
    }
}
