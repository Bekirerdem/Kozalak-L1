// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {KozaCollection} from "../../src/templates/erc721-collection/KozaCollection.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ERC721CollectionTest
 * @notice Unit + fuzz tests for KozaCollection (Phase 1, Template 2).
 * @dev Foundry suite covering constructor, allowlist mint, public mint, phase control,
 *      per-wallet cap, max supply, royalty, withdraw, ownership.
 *      Invariant tests are in ERC721Collection.invariants.t.sol.
 */
contract ERC721CollectionTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    KozaCollection internal nft;

    address internal owner;
    address internal alice;
    address internal bob;
    address internal charlie;
    address internal royalty;
    address payable internal treasury;

    string internal constant NAME = "Koza Genesis";
    string internal constant SYMBOL = "KOZA";
    string internal constant BASE_URI = "ipfs://QmExampleCID/";
    uint256 internal constant MAX_SUPPLY = 100;
    uint256 internal constant MINT_PRICE = 0.1 ether;
    uint96 internal constant ROYALTY_BPS = 500; // %5

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        royalty = makeAddr("royalty");
        treasury = payable(makeAddr("treasury"));

        nft = new KozaCollection(NAME, SYMBOL, BASE_URI, MAX_SUPPLY, MINT_PRICE, royalty, ROYALTY_BPS, owner);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsMetadata() public view {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.maxSupply(), MAX_SUPPLY);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertEq(nft.totalMinted(), 0);
        assertEq(nft.owner(), owner);
        assertEq(nft.pendingOwner(), address(0));
        assertEq(uint8(nft.phase()), uint8(KozaCollection.Phase.Closed));
        assertEq(nft.merkleRoot(), bytes32(0));

        (address rcv, uint256 amount) = nft.royaltyInfo(1, 10_000);
        assertEq(rcv, royalty);
        assertEq(amount, 500); // %5 of 10000
    }

    function test_Constructor_SupportsInterfaces() public view {
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC2981).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC165).interfaceId));
    }

    function test_RevertWhen_ConstructorMaxSupplyZero() public {
        vm.expectRevert(KozaCollection.MaxSupplyZero.selector);
        new KozaCollection(NAME, SYMBOL, BASE_URI, 0, MINT_PRICE, royalty, ROYALTY_BPS, owner);
    }

    function test_RevertWhen_ConstructorOwnerIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new KozaCollection(NAME, SYMBOL, BASE_URI, MAX_SUPPLY, MINT_PRICE, royalty, ROYALTY_BPS, address(0));
    }

    function test_RevertWhen_ConstructorRoyaltyTooHigh() public {
        // OZ ERC2981: bps > 10000 reverts ERC2981InvalidDefaultRoyalty
        vm.expectRevert(abi.encodeWithSelector(ERC2981.ERC2981InvalidDefaultRoyalty.selector, 10_001, 10_000));
        new KozaCollection(NAME, SYMBOL, BASE_URI, MAX_SUPPLY, MINT_PRICE, royalty, 10_001, owner);
    }

    function test_RevertWhen_ConstructorRoyaltyReceiverIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(ERC2981.ERC2981InvalidDefaultRoyaltyReceiver.selector, address(0)));
        new KozaCollection(NAME, SYMBOL, BASE_URI, MAX_SUPPLY, MINT_PRICE, address(0), ROYALTY_BPS, owner);
    }

    /*//////////////////////////////////////////////////////////////
                              PUBLIC MINT
    //////////////////////////////////////////////////////////////*/

    function test_PublicMint_Succeeds() public {
        _setPhase(KozaCollection.Phase.Public);
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        nft.publicMint{value: MINT_PRICE * 3}(3);

        assertEq(nft.balanceOf(alice), 3);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.ownerOf(3), alice);
        assertEq(nft.totalMinted(), 3);
        assertEq(nft.mintedPerWallet(alice), 3);
        assertEq(address(nft).balance, MINT_PRICE * 3);
    }

    function test_PublicMint_TokenURI() public {
        _setPhase(KozaCollection.Phase.Public);
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        nft.publicMint{value: MINT_PRICE}(1);

        assertEq(nft.tokenURI(1), string(abi.encodePacked(BASE_URI, "1")));
    }

    function test_RevertWhen_PublicMintInClosedPhase() public {
        vm.deal(alice, 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                KozaCollection.WrongPhase.selector, KozaCollection.Phase.Closed, KozaCollection.Phase.Public
            )
        );
        vm.prank(alice);
        nft.publicMint{value: MINT_PRICE}(1);
    }

    function test_RevertWhen_PublicMintInAllowlistPhase() public {
        _setPhase(KozaCollection.Phase.Allowlist);
        vm.deal(alice, 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                KozaCollection.WrongPhase.selector, KozaCollection.Phase.Allowlist, KozaCollection.Phase.Public
            )
        );
        vm.prank(alice);
        nft.publicMint{value: MINT_PRICE}(1);
    }

    function test_RevertWhen_PublicMintZeroQuantity() public {
        _setPhase(KozaCollection.Phase.Public);
        vm.expectRevert(KozaCollection.ZeroQuantity.selector);
        vm.prank(alice);
        nft.publicMint{value: 0}(0);
    }

    function test_RevertWhen_PublicMintIncorrectPayment() public {
        _setPhase(KozaCollection.Phase.Public);
        vm.deal(alice, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(KozaCollection.IncorrectPayment.selector, 0, MINT_PRICE * 2));
        vm.prank(alice);
        nft.publicMint{value: 0}(2);
    }

    function test_RevertWhen_PublicMintOverpaid() public {
        _setPhase(KozaCollection.Phase.Public);
        vm.deal(alice, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(KozaCollection.IncorrectPayment.selector, MINT_PRICE * 2, MINT_PRICE));
        vm.prank(alice);
        nft.publicMint{value: MINT_PRICE * 2}(1);
    }

    function test_RevertWhen_PublicMintExceedsPerWalletLimit() public {
        _setPhase(KozaCollection.Phase.Public);
        vm.deal(alice, 100 ether);

        vm.startPrank(alice);
        nft.publicMint{value: MINT_PRICE * 10}(10); // hits MAX_PER_WALLET
        vm.expectRevert(abi.encodeWithSelector(KozaCollection.ExceedsPerWalletLimit.selector, 10, 1, 10));
        nft.publicMint{value: MINT_PRICE}(1);
        vm.stopPrank();
    }

    function test_RevertWhen_PublicMintExceedsMaxSupply() public {
        // Deploy a smaller collection so we can exhaust supply within MAX_PER_WALLET
        KozaCollection small = new KozaCollection(NAME, SYMBOL, BASE_URI, 5, MINT_PRICE, royalty, ROYALTY_BPS, owner);
        vm.prank(owner);
        small.setPhase(KozaCollection.Phase.Public);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        vm.prank(alice);
        small.publicMint{value: MINT_PRICE * 5}(5);

        vm.expectRevert(abi.encodeWithSelector(KozaCollection.MaxSupplyReached.selector, 5, 6));
        vm.prank(bob);
        small.publicMint{value: MINT_PRICE}(1);
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOWLIST MINT
    //////////////////////////////////////////////////////////////*/

    function test_AllowlistMint_Succeeds() public {
        // 2-yapraklı ağaç: alice + bob
        bytes32 root = _buildTwoLeafRoot(alice, bob);
        vm.startPrank(owner);
        nft.setMerkleRoot(root);
        nft.setPhase(KozaCollection.Phase.Allowlist);
        vm.stopPrank();

        bytes32[] memory proof = _twoLeafProof(bob);
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        nft.allowlistMint{value: MINT_PRICE * 2}(2, proof);

        assertEq(nft.balanceOf(alice), 2);
        assertTrue(nft.allowlistClaimed(alice));
    }

    function test_RevertWhen_AllowlistMintWrongPhase() public {
        bytes32[] memory proof = new bytes32[](0);
        vm.expectRevert(
            abi.encodeWithSelector(
                KozaCollection.WrongPhase.selector, KozaCollection.Phase.Closed, KozaCollection.Phase.Allowlist
            )
        );
        vm.prank(alice);
        nft.allowlistMint{value: 0}(1, proof);
    }

    function test_RevertWhen_AllowlistMintInvalidProof() public {
        bytes32 root = _buildTwoLeafRoot(alice, bob);
        vm.startPrank(owner);
        nft.setMerkleRoot(root);
        nft.setPhase(KozaCollection.Phase.Allowlist);
        vm.stopPrank();

        // charlie listede değil
        bytes32[] memory proof = _twoLeafProof(bob);
        vm.deal(charlie, 1 ether);
        vm.expectRevert(KozaCollection.InvalidProof.selector);
        vm.prank(charlie);
        nft.allowlistMint{value: MINT_PRICE}(1, proof);
    }

    function test_RevertWhen_AllowlistAlreadyClaimed() public {
        bytes32 root = _buildTwoLeafRoot(alice, bob);
        vm.startPrank(owner);
        nft.setMerkleRoot(root);
        nft.setPhase(KozaCollection.Phase.Allowlist);
        vm.stopPrank();

        bytes32[] memory proof = _twoLeafProof(bob);
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);
        nft.allowlistMint{value: MINT_PRICE}(1, proof);
        vm.expectRevert(abi.encodeWithSelector(KozaCollection.AlreadyClaimed.selector, alice));
        nft.allowlistMint{value: MINT_PRICE}(1, proof);
        vm.stopPrank();
    }

    function test_AllowlistMintRespectsMaxPerWallet() public {
        bytes32 root = _buildTwoLeafRoot(alice, bob);
        vm.startPrank(owner);
        nft.setMerkleRoot(root);
        nft.setPhase(KozaCollection.Phase.Allowlist);
        vm.stopPrank();

        bytes32[] memory proof = _twoLeafProof(bob);
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(KozaCollection.ExceedsPerWalletLimit.selector, 0, 11, 10));
        nft.allowlistMint{value: MINT_PRICE * 11}(11, proof);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_SetMerkleRoot_OnlyOwner() public {
        bytes32 root = bytes32(uint256(0xCAFEBABE));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setMerkleRoot(root);

        vm.expectEmit(true, false, false, false);
        emit KozaCollection.MerkleRootSet(root);
        vm.prank(owner);
        nft.setMerkleRoot(root);
        assertEq(nft.merkleRoot(), root);
    }

    function test_SetPhase_OnlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setPhase(KozaCollection.Phase.Public);

        vm.expectEmit(true, false, false, false);
        emit KozaCollection.PhaseChanged(KozaCollection.Phase.Public);
        vm.prank(owner);
        nft.setPhase(KozaCollection.Phase.Public);
        assertEq(uint8(nft.phase()), uint8(KozaCollection.Phase.Public));
    }

    function test_SetBaseURI_OnlyOwner() public {
        string memory newURI = "https://meta.koza.dev/";
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setBaseURI(newURI);

        vm.prank(owner);
        nft.setBaseURI(newURI);

        // Mint and verify URI uses new prefix
        vm.prank(owner);
        nft.setPhase(KozaCollection.Phase.Public);
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        nft.publicMint{value: MINT_PRICE}(1);
        assertEq(nft.tokenURI(1), string(abi.encodePacked(newURI, "1")));
    }

    function test_SetMintPrice_OnlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setMintPrice(0.5 ether);

        vm.prank(owner);
        nft.setMintPrice(0.5 ether);
        assertEq(nft.mintPrice(), 0.5 ether);
    }

    function test_SetDefaultRoyalty_OnlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.setDefaultRoyalty(charlie, 1000);

        vm.prank(owner);
        nft.setDefaultRoyalty(charlie, 1000); // %10
        (address rcv, uint256 amount) = nft.royaltyInfo(1, 10_000);
        assertEq(rcv, charlie);
        assertEq(amount, 1000);
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function test_Withdraw_Succeeds() public {
        _setPhase(KozaCollection.Phase.Public);
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        nft.publicMint{value: MINT_PRICE * 5}(5);

        uint256 balanceBefore = treasury.balance;
        vm.expectEmit(true, false, false, true);
        emit KozaCollection.Withdrawn(treasury, MINT_PRICE * 5);
        vm.prank(owner);
        nft.withdraw(treasury);

        assertEq(treasury.balance, balanceBefore + MINT_PRICE * 5);
        assertEq(address(nft).balance, 0);
    }

    function test_Withdraw_OnlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.withdraw(treasury);
    }

    function test_RevertWhen_WithdrawToRejectingContract() public {
        _setPhase(KozaCollection.Phase.Public);
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        nft.publicMint{value: MINT_PRICE}(1);

        RejectingReceiver rejecter = new RejectingReceiver();
        vm.expectRevert(KozaCollection.WithdrawFailed.selector);
        vm.prank(owner);
        nft.withdraw(payable(address(rejecter)));
    }

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP TRANSFER
    //////////////////////////////////////////////////////////////*/

    function test_OwnershipTransfer_TwoStep() public {
        vm.prank(owner);
        nft.transferOwnership(alice);
        assertEq(nft.owner(), owner);
        assertEq(nft.pendingOwner(), alice);

        vm.prank(alice);
        nft.acceptOwnership();
        assertEq(nft.owner(), alice);
        assertEq(nft.pendingOwner(), address(0));
    }

    function test_OwnershipTransfer_CancelByNewTransfer() public {
        vm.prank(owner);
        nft.transferOwnership(alice);

        // Owner overrides pendingOwner with another address
        vm.prank(owner);
        nft.transferOwnership(bob);
        assertEq(nft.pendingOwner(), bob);

        // Alice can no longer accept
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        nft.acceptOwnership();
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PublicMint_QuantityWithinLimits(uint256 qty) public {
        qty = bound(qty, 1, 10);
        _setPhase(KozaCollection.Phase.Public);
        uint256 cost = MINT_PRICE * qty;
        vm.deal(alice, cost);

        vm.prank(alice);
        nft.publicMint{value: cost}(qty);
        assertEq(nft.balanceOf(alice), qty);
        assertEq(nft.totalMinted(), qty);
    }

    function testFuzz_AllowlistMint_DoesNotAllowDoubleClaim(uint256 qty) public {
        qty = bound(qty, 1, 5);
        bytes32 root = _buildTwoLeafRoot(alice, bob);
        vm.startPrank(owner);
        nft.setMerkleRoot(root);
        nft.setPhase(KozaCollection.Phase.Allowlist);
        vm.stopPrank();

        bytes32[] memory proof = _twoLeafProof(bob);
        vm.deal(alice, 10 ether);

        vm.startPrank(alice);
        nft.allowlistMint{value: MINT_PRICE * qty}(qty, proof);
        vm.expectRevert(abi.encodeWithSelector(KozaCollection.AlreadyClaimed.selector, alice));
        nft.allowlistMint{value: MINT_PRICE}(1, proof);
        vm.stopPrank();
    }

    function testFuzz_RoyaltyCalculation(uint96 bps, uint256 salePrice) public {
        bps = uint96(bound(bps, 0, 10_000));
        salePrice = bound(salePrice, 0, type(uint128).max);

        vm.prank(owner);
        nft.setDefaultRoyalty(charlie, bps);

        (address rcv, uint256 amount) = nft.royaltyInfo(1, salePrice);
        assertEq(rcv, charlie);
        assertEq(amount, salePrice * bps / 10_000);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setPhase(KozaCollection.Phase p) internal {
        vm.prank(owner);
        nft.setPhase(p);
    }

    /// @dev OZ MerkleProof commutative hash kullanır (sıralanmış pair). 2 yaprak için
    ///      kök = keccak256(sorted(leaf1, leaf2)).
    function _buildTwoLeafRoot(address a, address b) internal pure returns (bytes32) {
        bytes32 leafA = keccak256(abi.encodePacked(a));
        bytes32 leafB = keccak256(abi.encodePacked(b));
        return _commutativeHash(leafA, leafB);
    }

    /// @dev `addr` için kanıt = diğer yaprağın hash'i (2 yapraklı ağaçta).
    function _twoLeafProof(address other) internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked(other));
        return proof;
    }

    function _commutativeHash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}

/// @dev `receive`/`fallback` olmayan kontrat — withdraw target reddi senaryosu için.
contract RejectingReceiver {
    // no receive/fallback → ETH transfer fails
}
