// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {KozaGasToken} from "../src/KozaGasToken.sol";

/**
 * @title ERC20GasHandler
 * @notice Foundry invariant testing handler. Bounded random calls into KozaGasToken.
 * @dev Handler pattern (Foundry stateful fuzzing) — invariant'ların ihlal edilmediği
 *      her tx sırasında doğrulanır. Owner pranking ile yönetim fonksiyonlarına erişim
 *      sağlanır.
 */
contract ERC20GasHandler is Test {
    KozaGasToken public token;
    address public owner;
    address[] public actors;

    // Mevcut tüm transfer/mint/burn aksiyon sayıları (debug için)
    uint256 public callCount;

    constructor(KozaGasToken _token, address _owner, address[] memory _actors) {
        token = _token;
        owner = _owner;
        actors = _actors;
    }

    function _pickActor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    /// @notice Bounded random transfer between actors.
    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        callCount++;
        address from = _pickActor(fromSeed);
        address to = _pickActor(toSeed);

        uint256 fromBalance = token.balanceOf(from);
        if (fromBalance == 0) return;

        amount = bound(amount, 1, fromBalance);

        vm.prank(from);
        try token.transfer(to, amount) returns (bool) {} catch {}
    }

    /// @notice Bounded random mint by owner.
    function mint(uint256 toSeed, uint256 amount) external {
        callCount++;
        address to = _pickActor(toSeed);

        uint256 cap = token.cap();
        uint256 totalSupply = token.totalSupply();
        if (totalSupply >= cap) return;

        // Avoid uint256 overflow by capping at type(uint128).max
        amount = bound(amount, 1, cap - totalSupply);

        vm.prank(owner);
        try token.mint(to, amount) {} catch {}
    }

    /// @notice Bounded random burn by an actor.
    function burn(uint256 actorSeed, uint256 amount) external {
        callCount++;
        address actor = _pickActor(actorSeed);

        uint256 balance = token.balanceOf(actor);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        vm.prank(actor);
        try token.burn(amount) {} catch {}
    }

    /// @notice Returns the current actor list (used by invariant test).
    function getActors() external view returns (address[] memory) {
        return actors;
    }
}

/**
 * @title ERC20GasInvariantTest
 * @notice Stateful fuzzing invariants for KozaGasToken. Foundry's invariant runner
 *         randomly calls handler functions and asserts these invariants hold after
 *         every call.
 *
 *         Tested invariants:
 *         1. totalSupply() <= cap()        — never exceeds the cap
 *         2. sum(balanceOf(actors)) == totalSupply()  — balance accounting consistent
 */
contract ERC20GasInvariantTest is Test {
    KozaGasToken internal token;
    ERC20GasHandler internal handler;
    address internal owner;
    address[] internal actors;

    uint256 internal constant CAP = 10_000_000 ether;
    uint256 internal constant INITIAL_MINT = 1_000_000 ether;

    function setUp() public {
        owner = makeAddr("owner");

        // Set up 5 actors and seed first one with the initial mint
        actors.push(owner);
        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
        actors.push(makeAddr("charlie"));
        actors.push(makeAddr("dave"));

        token = new KozaGasToken("Koza Gas Token", "KGAS", CAP, INITIAL_MINT, owner);
        handler = new ERC20GasHandler(token, owner, actors);

        // Configure Foundry invariant runner to only call our handler
        targetContract(address(handler));

        // Restrict the function selectors that can be invoked
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.transfer.selector;
        selectors[1] = handler.mint.selector;
        selectors[2] = handler.burn.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice totalSupply must never exceed cap.
    function invariant_TotalSupplyDoesNotExceedCap() public view {
        assertLe(token.totalSupply(), token.cap(), "totalSupply > cap");
    }

    /// @notice Sum of balances across all actors must equal totalSupply.
    function invariant_SumOfBalancesEqualsTotalSupply() public view {
        uint256 sum;
        for (uint256 i = 0; i < actors.length; i++) {
            sum += token.balanceOf(actors[i]);
        }
        assertEq(sum, token.totalSupply(), "sum(balances) != totalSupply");
    }

    /// @notice Owner remains constant during invariant runs (no ownership change exposed).
    function invariant_OwnerDoesNotChange() public view {
        assertEq(token.owner(), owner, "owner mutated unexpectedly");
    }
}
