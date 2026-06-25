// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {KozaCredential} from "../../src/templates/soulbound-credential/KozaCredential.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @title SoulboundTest
 * @notice Unit + fuzz tests for KozaCredential (Phase 1, Template 4).
 * @dev Foundry suite covering constructor/roles, issue, soulbound transfer lock,
 *      revoke (flag), isValid, tokenURI, getCredential, AccessControl grant/revoke.
 *      Invariant tests are in Soulbound.invariants.t.sol.
 */
contract SoulboundTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    KozaCredential internal cred;

    address internal admin;
    address internal issuer;
    address internal alice;
    address internal bob;

    string internal constant NAME = "ARIA Hub Credential";
    string internal constant SYMBOL = "ARIA";
    string internal constant COURSE = "Avalanche L1 Workshop";

    bytes32 internal ISSUER_ROLE;
    bytes32 internal DEFAULT_ADMIN_ROLE;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        admin = makeAddr("admin");
        issuer = makeAddr("issuer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        cred = new KozaCredential(NAME, SYMBOL, admin, issuer);
        ISSUER_ROLE = cred.ISSUER_ROLE();
        DEFAULT_ADMIN_ROLE = cred.DEFAULT_ADMIN_ROLE();
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsMetadataAndRoles() public view {
        assertEq(cred.name(), NAME);
        assertEq(cred.symbol(), SYMBOL);
        assertEq(cred.totalIssued(), 0);
        assertTrue(cred.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(cred.hasRole(ISSUER_ROLE, issuer));
        assertFalse(cred.hasRole(ISSUER_ROLE, alice));
    }

    function test_Constructor_SupportsInterfaces() public view {
        assertTrue(cred.supportsInterface(type(IERC721).interfaceId));
        assertTrue(cred.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(cred.supportsInterface(type(IERC165).interfaceId));
    }

    /*//////////////////////////////////////////////////////////////
                                 ISSUE
    //////////////////////////////////////////////////////////////*/

    function test_Issue_Succeeds() public {
        vm.expectEmit(true, true, true, true);
        emit KozaCredential.CredentialIssued(1, alice, issuer, COURSE);

        vm.prank(issuer);
        uint256 tokenId = cred.issue(alice, COURSE);

        assertEq(tokenId, 1);
        assertEq(cred.ownerOf(1), alice);
        assertEq(cred.balanceOf(alice), 1);
        assertEq(cred.totalIssued(), 1);
        assertTrue(cred.isValid(1));

        KozaCredential.Credential memory c = cred.getCredential(1);
        assertEq(c.course, COURSE);
        assertEq(c.issuer, issuer);
        assertEq(c.issuedAt, uint64(block.timestamp));
        assertFalse(c.revoked);
    }

    function test_Issue_IncrementsTokenId() public {
        vm.startPrank(issuer);
        assertEq(cred.issue(alice, COURSE), 1);
        assertEq(cred.issue(bob, COURSE), 2);
        assertEq(cred.issue(alice, "Second Course"), 3);
        vm.stopPrank();

        assertEq(cred.totalIssued(), 3);
        assertEq(cred.balanceOf(alice), 2);
    }

    function test_Issue_RecordsTimestamp() public {
        vm.warp(1_900_000_000);
        vm.prank(issuer);
        cred.issue(alice, COURSE);
        assertEq(cred.getCredential(1).issuedAt, uint64(1_900_000_000));
    }

    function test_RevertWhen_IssueNotIssuer() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ISSUER_ROLE)
        );
        vm.prank(alice);
        cred.issue(bob, COURSE);
    }

    function test_RevertWhen_IssueEmptyCourse() public {
        vm.expectRevert(KozaCredential.EmptyCourse.selector);
        vm.prank(issuer);
        cred.issue(alice, "");
    }

    /*//////////////////////////////////////////////////////////////
                          SOULBOUND (NON-TRANSFER)
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_TransferFrom() public {
        vm.prank(issuer);
        cred.issue(alice, COURSE);

        vm.expectRevert(KozaCredential.Soulbound.selector);
        vm.prank(alice);
        cred.transferFrom(alice, bob, 1);
    }

    function test_RevertWhen_SafeTransferFrom() public {
        vm.prank(issuer);
        cred.issue(alice, COURSE);

        vm.expectRevert(KozaCredential.Soulbound.selector);
        vm.prank(alice);
        cred.safeTransferFrom(alice, bob, 1);
    }

    function test_RevertWhen_TransferAfterApprove() public {
        vm.prank(issuer);
        cred.issue(alice, COURSE);

        // approve is allowed (no-op effectively) but transfer still blocked
        vm.prank(alice);
        cred.approve(bob, 1);

        vm.expectRevert(KozaCredential.Soulbound.selector);
        vm.prank(bob);
        cred.transferFrom(alice, bob, 1);
    }

    /*//////////////////////////////////////////////////////////////
                                 REVOKE
    //////////////////////////////////////////////////////////////*/

    function test_Revoke_Succeeds() public {
        vm.prank(issuer);
        cred.issue(alice, COURSE);

        vm.expectEmit(true, true, false, false);
        emit KozaCredential.CredentialRevoked(1, issuer);
        vm.prank(issuer);
        cred.revoke(1);

        assertFalse(cred.isValid(1));
        assertTrue(cred.getCredential(1).revoked);
        // token is not burned — ownerOf still resolves
        assertEq(cred.ownerOf(1), alice);
    }

    function test_RevertWhen_RevokeNotIssuer() public {
        vm.prank(issuer);
        cred.issue(alice, COURSE);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ISSUER_ROLE)
        );
        vm.prank(alice);
        cred.revoke(1);
    }

    function test_RevertWhen_RevokeNonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 99));
        vm.prank(issuer);
        cred.revoke(99);
    }

    function test_RevertWhen_RevokeAlreadyRevoked() public {
        vm.startPrank(issuer);
        cred.issue(alice, COURSE);
        cred.revoke(1);
        vm.expectRevert(abi.encodeWithSelector(KozaCredential.AlreadyRevoked.selector, 1));
        cred.revoke(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                IS VALID
    //////////////////////////////////////////////////////////////*/

    function test_IsValid_FalseForNonexistent() public view {
        assertFalse(cred.isValid(1));
    }

    /*//////////////////////////////////////////////////////////////
                               TOKEN URI
    //////////////////////////////////////////////////////////////*/

    function test_TokenURI_IsOnChainJson() public {
        vm.prank(issuer);
        cred.issue(alice, COURSE);

        string memory uri = cred.tokenURI(1);
        assertTrue(_startsWith(uri, "data:application/json;base64,"), "tokenURI must be on-chain base64 JSON");
    }

    function test_TokenURI_ChangesAfterRevoke() public {
        vm.prank(issuer);
        cred.issue(alice, COURSE);
        string memory beforeURI = cred.tokenURI(1);

        vm.prank(issuer);
        cred.revoke(1);
        string memory afterURI = cred.tokenURI(1);

        // status flips Valid -> Revoked, so the encoded metadata must differ
        assertTrue(keccak256(bytes(beforeURI)) != keccak256(bytes(afterURI)), "metadata must reflect revoke");
    }

    function test_RevertWhen_TokenURINonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        cred.tokenURI(1);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_AdminCanGrantIssuerRole() public {
        vm.prank(admin);
        cred.grantRole(ISSUER_ROLE, bob);

        vm.prank(bob);
        uint256 tokenId = cred.issue(alice, COURSE);
        assertEq(tokenId, 1);
    }

    function test_AdminCanRevokeIssuerRole() public {
        vm.prank(admin);
        cred.revokeRole(ISSUER_ROLE, issuer);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, issuer, ISSUER_ROLE)
        );
        vm.prank(issuer);
        cred.issue(alice, COURSE);
    }

    function test_RevertWhen_NonAdminGrantsRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, DEFAULT_ADMIN_ROLE)
        );
        vm.prank(alice);
        cred.grantRole(ISSUER_ROLE, bob);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_IssuedCredentialsAreSoulbound(address to, address attacker) public {
        vm.assume(to != address(0) && to.code.length == 0);
        vm.assume(attacker != address(0));

        vm.prank(issuer);
        uint256 tokenId = cred.issue(to, COURSE);

        vm.expectRevert(KozaCredential.Soulbound.selector);
        vm.prank(to);
        cred.transferFrom(to, attacker, tokenId);
    }

    function testFuzz_RevokeInvalidatesCredential(uint64 ts) public {
        ts = uint64(bound(ts, 1, type(uint64).max));
        vm.warp(ts);

        vm.startPrank(issuer);
        cred.issue(alice, COURSE);
        assertTrue(cred.isValid(1));
        cred.revoke(1);
        vm.stopPrank();

        assertFalse(cred.isValid(1));
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory s = bytes(str);
        bytes memory p = bytes(prefix);
        if (s.length < p.length) return false;
        for (uint256 i = 0; i < p.length; i++) {
            if (s[i] != p[i]) return false;
        }
        return true;
    }
}
