// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {KozaTokenHome} from "../src/KozaTokenHome.sol";
import {KozaTokenRemote} from "../src/KozaTokenRemote.sol";
import {TokenRemoteSettings} from "@ictt/TokenRemote/interfaces/ITokenRemote.sol";
import {ITeleporterMessenger} from "@teleporter/ITeleporterMessenger.sol";

/**
 * @title MockTeleporterRegistry
 * @notice Smoke test setup için minimal TeleporterRegistry stub. Sadece
 *         `__TeleporterRegistryApp_init`'in zero-check + version-compare
 *         adımlarını geçirebilmek için yeterli yüzeye sahip. send/receive
 *         flow burada test edilmez (Sprint 3G fork test'leri o iş için).
 */
contract MockTeleporterRegistry {
    address public messenger;
    uint256 public latestVersion = 1;

    constructor(address messenger_) {
        messenger = messenger_;
    }

    function getAddressFromVersion(uint256) external view returns (address) {
        return messenger;
    }

    function getLatestTeleporter() external view returns (ITeleporterMessenger) {
        return ITeleporterMessenger(messenger);
    }

    function getVersionFromAddress(address) external pure returns (uint256) {
        return 1;
    }
}

/**
 * @title MockERC20
 * @notice Sadece `decimals()` döndürmek için ihtiyaç var (Home init bunu çekmez,
 *         ama deploy sırasında ERC-20 referansı tutulur). Boş bir kontrat yeterli.
 */
contract MockERC20 {
    function decimals() external pure returns (uint8) {
        return 18;
    }
}

contract ICTTBridgeSmokeTest is Test {
    MockTeleporterRegistry internal registry;
    MockERC20 internal mockToken;
    address internal mockMessenger;
    address internal teleporterManager;

    bytes32 internal constant SAMPLE_HOME_BLOCKCHAIN_ID =
        bytes32(hex"abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd");
    address internal constant SAMPLE_HOME_ADDRESS = address(0xC0FFEE);

    /// @dev Warp Messenger precompile address (Avalanche Subnet-EVM yerleşik). Foundry
    ///      test EVM'inde mevcut değil; vm.etch + vm.mockCall ile sahte bir kontrat
    ///      koyup `getBlockchainID()` çağrısını yakalıyoruz. ICTT init için yeterli.
    address internal constant WARP_MESSENGER = 0x0200000000000000000000000000000000000005;

    function setUp() public {
        mockMessenger = makeAddr("messenger");
        teleporterManager = makeAddr("teleporterManager");
        registry = new MockTeleporterRegistry(mockMessenger);
        mockToken = new MockERC20();

        // Warp precompile mock: EVM call'unun "call to non-contract" hatası vermemesi için
        // bytecode etch et, sonra getBlockchainID()'yi mock'la.
        vm.etch(WARP_MESSENGER, hex"01");
        vm.mockCall(
            WARP_MESSENGER,
            abi.encodeWithSignature("getBlockchainID()"),
            abi.encode(bytes32(uint256(43_113))) // sembolik — Fuji chain ID
        );
    }

    /*//////////////////////////////////////////////////////////////
                        KOZA TOKEN HOME — SMOKE
    //////////////////////////////////////////////////////////////*/

    function test_KozaTokenHome_DeploysWithValidParams() public {
        KozaTokenHome home = new KozaTokenHome({
            teleporterRegistryAddress: address(registry),
            teleporterManager: teleporterManager,
            minTeleporterVersion: 1,
            tokenAddress: address(mockToken),
            tokenDecimals: 18
        });

        assertTrue(address(home) != address(0));
    }

    function test_KozaTokenHome_RevertsOnZeroRegistry() public {
        vm.expectRevert();
        new KozaTokenHome({
            teleporterRegistryAddress: address(0),
            teleporterManager: teleporterManager,
            minTeleporterVersion: 1,
            tokenAddress: address(mockToken),
            tokenDecimals: 18
        });
    }

    function test_KozaTokenHome_RevertsOnZeroMinVersion() public {
        vm.expectRevert();
        new KozaTokenHome({
            teleporterRegistryAddress: address(registry),
            teleporterManager: teleporterManager,
            minTeleporterVersion: 0,
            tokenAddress: address(mockToken),
            tokenDecimals: 18
        });
    }

    /*//////////////////////////////////////////////////////////////
                       KOZA TOKEN REMOTE — SMOKE
    //////////////////////////////////////////////////////////////*/

    function _defaultRemoteSettings() internal view returns (TokenRemoteSettings memory) {
        return TokenRemoteSettings({
            teleporterRegistryAddress: address(registry),
            teleporterManager: teleporterManager,
            minTeleporterVersion: 1,
            tokenHomeBlockchainID: SAMPLE_HOME_BLOCKCHAIN_ID,
            tokenHomeAddress: SAMPLE_HOME_ADDRESS,
            tokenHomeDecimals: 18
        });
    }

    function test_KozaTokenRemote_DeploysWithValidParams() public {
        KozaTokenRemote remote = new KozaTokenRemote(_defaultRemoteSettings(), "Wrapped Koza Gas", "wKGAS", 18);

        assertEq(remote.name(), "Wrapped Koza Gas");
        assertEq(remote.symbol(), "wKGAS");
        assertEq(remote.decimals(), 18);
        assertEq(remote.totalSupply(), 0);
    }

    function test_KozaTokenRemote_RevertsOnZeroHomeAddress() public {
        TokenRemoteSettings memory settings = _defaultRemoteSettings();
        settings.tokenHomeAddress = address(0);

        vm.expectRevert();
        new KozaTokenRemote(settings, "Wrapped Koza Gas", "wKGAS", 18);
    }

    function test_KozaTokenRemote_RevertsOnZeroHomeBlockchainID() public {
        TokenRemoteSettings memory settings = _defaultRemoteSettings();
        settings.tokenHomeBlockchainID = bytes32(0);

        vm.expectRevert();
        new KozaTokenRemote(settings, "Wrapped Koza Gas", "wKGAS", 18);
    }
}
