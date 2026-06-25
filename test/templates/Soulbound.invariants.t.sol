// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {KozaCredential} from "../../src/templates/soulbound-credential/KozaCredential.sol";

/**
 * @title SoulboundHandler
 * @notice Foundry invariant testing handler. Bounded random calls into KozaCredential.
 * @dev Issues, revokes ve transfer denemeleri yapar. Transfer her zaman revert eder
 *      (soulbound); handler bunu yutar. Invariant runner her tx sonrası kontrol eder.
 */
contract SoulboundHandler is Test {
    KozaCredential public cred;
    address public issuer;
    address[] public actors;

    uint256 public callCount;
    uint256 public successfulIssues;
    uint256[] public revokedIds;

    string internal constant COURSE = "Avalanche L1 Workshop";

    constructor(KozaCredential _cred, address _issuer, address[] memory _actors) {
        cred = _cred;
        issuer = _issuer;
        actors = _actors;
    }

    function _pickActor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    /// @notice Issuer bir aktöre sertifika verir.
    function issue(uint256 actorSeed) external {
        callCount++;
        address to = _pickActor(actorSeed);
        vm.prank(issuer);
        try cred.issue(to, COURSE) returns (uint256) {
            successfulIssues++;
        } catch {}
    }

    /// @notice Issuer rastgele bir mevcut sertifikayı iptal eder.
    function revoke(uint256 idSeed) external {
        callCount++;
        uint256 total = cred.totalIssued();
        if (total == 0) return;
        uint256 id = (idSeed % total) + 1;
        vm.prank(issuer);
        try cred.revoke(id) {
            revokedIds.push(id);
        } catch {}
    }

    /// @notice Transfer denemesi — soulbound olduğu için DAİMA revert eder.
    function tryTransfer(uint256 toSeed, uint256 idSeed) external {
        callCount++;
        uint256 total = cred.totalIssued();
        if (total == 0) return;
        uint256 id = (idSeed % total) + 1;
        address owner = cred.ownerOf(id); // revoke token'ı silmez → her zaman çözülür
        address to = _pickActor(toSeed);
        vm.prank(owner);
        try cred.transferFrom(owner, to, id) {} catch {}
    }

    function revokedCount() external view returns (uint256) {
        return revokedIds.length;
    }

    function revokedIdAt(uint256 i) external view returns (uint256) {
        return revokedIds[i];
    }
}

/**
 * @title SoulboundInvariantTest
 * @notice Stateful fuzzing invariants for KozaCredential.
 *
 *         Tested invariants:
 *         1. sum(balanceOf(actors)) == totalIssued  (transfer imkansız, token leak yok)
 *         2. revoke edilen her sertifika asla isValid dönmez
 *         3. totalIssued == başarılı issue sayısı (monotonik, kayıpsız)
 */
contract SoulboundInvariantTest is Test {
    KozaCredential internal cred;
    SoulboundHandler internal handler;
    address internal admin;
    address internal issuer;
    address[] internal actors;

    function setUp() public {
        admin = makeAddr("admin");
        issuer = makeAddr("issuer");

        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
        actors.push(makeAddr("charlie"));
        actors.push(makeAddr("dave"));
        actors.push(makeAddr("eve"));

        cred = new KozaCredential("ARIA Hub Credential", "ARIA", admin, issuer);
        handler = new SoulboundHandler(cred, issuer, actors);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.issue.selector;
        selectors[1] = handler.revoke.selector;
        selectors[2] = handler.tryTransfer.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_SumOfBalancesEqualsTotalIssued() public view {
        uint256 sum;
        for (uint256 i = 0; i < actors.length; i++) {
            sum += cred.balanceOf(actors[i]);
        }
        assertEq(sum, cred.totalIssued(), "sum(balances) != totalIssued (transfer/leak detected)");
    }

    function invariant_RevokedAreNeverValid() public view {
        uint256 n = handler.revokedCount();
        for (uint256 i = 0; i < n; i++) {
            assertFalse(cred.isValid(handler.revokedIdAt(i)), "revoked credential reported valid");
        }
    }

    function invariant_TotalIssuedMatchesSuccessfulIssues() public view {
        assertEq(cred.totalIssued(), handler.successfulIssues(), "totalIssued != successful issues");
    }
}
