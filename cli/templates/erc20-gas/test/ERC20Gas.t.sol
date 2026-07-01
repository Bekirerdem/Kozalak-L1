// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {KozaGasToken} from "../src/KozaGasToken.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
 * @title ERC20GasTest
 * @notice Unit + fuzz tests for KozaGasToken (Phase 1, Template 1).
 * @dev Foundry test suite covering constructor, mint, burn, ERC-20 transfer, permit, ownership.
 *      Invariant tests are in ERC20Gas.invariants.t.sol.
 */
contract ERC20GasTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    KozaGasToken internal token;

    address internal owner;
    uint256 internal ownerKey;
    address internal alice;
    uint256 internal aliceKey;
    address internal bob;
    address internal charlie;

    string internal constant NAME = "Koza Gas Token";
    string internal constant SYMBOL = "KGAS";
    uint256 internal constant CAP = 1_000_000 ether;
    uint256 internal constant INITIAL_MINT = 100_000 ether;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        (owner, ownerKey) = makeAddrAndKey("owner");
        (alice, aliceKey) = makeAddrAndKey("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new KozaGasToken(NAME, SYMBOL, CAP, INITIAL_MINT, owner);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsMetadata() public view {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), 18);
        assertEq(token.cap(), CAP);
        assertEq(token.totalSupply(), INITIAL_MINT);
        assertEq(token.balanceOf(owner), INITIAL_MINT);
        assertEq(token.owner(), owner);
        assertEq(token.pendingOwner(), address(0));
    }

    function test_Constructor_DeploysWithoutInitialMint() public {
        KozaGasToken t = new KozaGasToken(NAME, SYMBOL, CAP, 0, owner);
        assertEq(t.totalSupply(), 0);
        assertEq(t.balanceOf(owner), 0);
    }

    function test_RevertWhen_ConstructorOwnerIsZero() public {
        // Ownable parent rejects zero address before our body executes
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new KozaGasToken(NAME, SYMBOL, CAP, INITIAL_MINT, address(0));
    }

    function test_RevertWhen_ConstructorCapIsZero() public {
        // ERC20Capped parent rejects zero cap before our body executes
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20InvalidCap.selector, 0));
        new KozaGasToken(NAME, SYMBOL, 0, 0, owner);
    }

    function test_RevertWhen_InitialMintExceedsCap() public {
        uint256 tooMuch = CAP + 1;
        vm.expectRevert(abi.encodeWithSelector(KozaGasToken.InitialMintExceedsCap.selector, CAP, tooMuch));
        new KozaGasToken(NAME, SYMBOL, CAP, tooMuch, owner);
    }

    /*//////////////////////////////////////////////////////////////
                                 MINT
    //////////////////////////////////////////////////////////////*/

    function test_Mint_OwnerCanMint() public {
        uint256 amount = 50_000 ether;
        vm.prank(owner);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), INITIAL_MINT + amount);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(alice, 1 ether);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        // ERC20 _mint rejects zero address with ERC20InvalidReceiver
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.mint(address(0), 1 ether);
    }

    function test_RevertWhen_MintZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(KozaGasToken.ZeroAmount.selector);
        token.mint(alice, 0);
    }

    function test_RevertWhen_MintExceedsCap() public {
        uint256 remaining = CAP - INITIAL_MINT;
        uint256 tooMuch = remaining + 1;

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, INITIAL_MINT + tooMuch, CAP));
        token.mint(alice, tooMuch);
    }

    function test_Mint_AtExactCapBoundary() public {
        uint256 remaining = CAP - INITIAL_MINT;
        vm.prank(owner);
        token.mint(alice, remaining);

        assertEq(token.totalSupply(), CAP);
        assertEq(token.balanceOf(alice), remaining);
    }

    /*//////////////////////////////////////////////////////////////
                                 BURN
    //////////////////////////////////////////////////////////////*/

    function test_Burn_HolderCanBurnOwnTokens() public {
        uint256 burnAmount = 10_000 ether;

        vm.prank(owner);
        token.burn(burnAmount);

        assertEq(token.balanceOf(owner), INITIAL_MINT - burnAmount);
        assertEq(token.totalSupply(), INITIAL_MINT - burnAmount);
    }

    function test_RevertWhen_BurnZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(KozaGasToken.ZeroAmount.selector);
        token.burn(0);
    }

    function test_RevertWhen_BurnExceedsBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1 ether));
        token.burn(1 ether);
    }

    function test_Burn_FreesCapHeadroom() public {
        // owner burns half, then mints back same amount → still under cap
        uint256 half = INITIAL_MINT / 2;

        vm.prank(owner);
        token.burn(half);

        vm.prank(owner);
        token.mint(alice, half);

        assertEq(token.totalSupply(), INITIAL_MINT);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-20 STANDARD
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_Standard() public {
        vm.prank(owner);
        bool ok = token.transfer(alice, 1000 ether);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 1000 ether);
        assertEq(token.balanceOf(owner), INITIAL_MINT - 1000 ether);
    }

    function test_Approve_AndTransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 500 ether);

        assertEq(token.allowance(owner, alice), 500 ether);

        vm.prank(alice);
        bool ok = token.transferFrom(owner, bob, 500 ether);

        assertTrue(ok);
        assertEq(token.balanceOf(bob), 500 ether);
        assertEq(token.allowance(owner, alice), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC-2612 PERMIT
    //////////////////////////////////////////////////////////////*/

    function test_Permit_ValidSignature() public {
        uint256 value = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Fund alice first
        vm.prank(owner);
        token.transfer(alice, 100 ether);

        bytes32 digest = _permitDigest(alice, bob, value, token.nonces(alice), deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, digest);

        token.permit(alice, bob, value, deadline, v, r, s);

        assertEq(token.allowance(alice, bob), value);
        assertEq(token.nonces(alice), 1);
    }

    function test_RevertWhen_PermitExpired() public {
        // Move forward so deadline=1 (a stale timestamp) is in the past relative to block.timestamp
        vm.warp(2 days);
        uint256 deadline = 1;

        bytes32 digest = _permitDigest(alice, bob, 100 ether, 0, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, digest);

        vm.expectRevert();
        token.permit(alice, bob, 100 ether, deadline, v, r, s);
    }

    function test_RevertWhen_PermitReplayed() public {
        uint256 value = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 digest = _permitDigest(alice, bob, value, token.nonces(alice), deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, digest);

        token.permit(alice, bob, value, deadline, v, r, s);

        // Replay should fail (nonce was consumed)
        vm.expectRevert();
        token.permit(alice, bob, value, deadline, v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNABLE2STEP
    //////////////////////////////////////////////////////////////*/

    function test_TransferOwnership_TwoStep() public {
        // Step 1: owner initiates transfer
        vm.prank(owner);
        token.transferOwnership(alice);

        assertEq(token.owner(), owner, "owner unchanged before accept");
        assertEq(token.pendingOwner(), alice, "alice is pending");

        // Step 2: alice accepts
        vm.prank(alice);
        token.acceptOwnership();

        assertEq(token.owner(), alice, "alice is now owner");
        assertEq(token.pendingOwner(), address(0), "pending cleared");
    }

    function test_RevertWhen_NonPendingAcceptsOwnership() public {
        vm.prank(owner);
        token.transferOwnership(alice);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        token.acceptOwnership();
    }

    function test_TransferOwnership_OldOwnerCanCancel() public {
        vm.prank(owner);
        token.transferOwnership(alice);

        // owner overrides with another transfer (pending update)
        vm.prank(owner);
        token.transferOwnership(charlie);

        assertEq(token.pendingOwner(), charlie);

        // alice can no longer accept
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.acceptOwnership();
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_MINT);

        vm.prank(owner);
        bool ok = token.transfer(alice, amount);
        assertTrue(ok);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(owner), INITIAL_MINT - amount);
    }

    function testFuzz_MintRespectsCap(uint256 amount) public {
        // Bound to avoid uint256 overflow on INITIAL_MINT + amount
        amount = bound(amount, 1, type(uint128).max);

        uint256 remaining = CAP - INITIAL_MINT;

        vm.prank(owner);
        if (amount > remaining) {
            vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, INITIAL_MINT + amount, CAP));
        }
        token.mint(alice, amount);

        assertLe(token.totalSupply(), CAP);
    }

    function testFuzz_BurnDoesNotUnderflow(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_MINT);

        vm.prank(owner);
        token.burn(amount);

        assertEq(token.balanceOf(owner), INITIAL_MINT - amount);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _permitDigest(
        address ownerAddr,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    )
        internal
        view
        returns (bytes32)
    {
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, ownerAddr, spender, value, nonce, deadline));
        return keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
    }
}
