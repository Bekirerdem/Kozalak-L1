// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {DeployERC721Collection} from "../script/DeployERC721Collection.s.sol";
import {KozaCollection} from "../src/KozaCollection.sol";

/**
 * @title DeployERC721CollectionTest
 * @notice Smoke tests for the ERC-721 deploy script. Calls `deploy(...)` directly
 *         with explicit parameters; env-driven `run()` exercised on Fuji integration.
 */
contract DeployERC721CollectionTest is Test {
    function test_Deploy_WithDefaultParameters() public {
        DeployERC721Collection deployer = new DeployERC721Collection();
        address broadcaster = makeAddr("broadcaster");
        address royalty = makeAddr("royalty");

        (KozaCollection nft, address returnedDeployer) = deployer.deploy(
            "Koza Genesis", "KOZA", "ipfs://QmExampleCID/", 5000, 0.05 ether, royalty, 500, broadcaster, broadcaster
        );

        assertEq(nft.name(), "Koza Genesis");
        assertEq(nft.symbol(), "KOZA");
        assertEq(nft.maxSupply(), 5000);
        assertEq(nft.mintPrice(), 0.05 ether);
        assertEq(nft.owner(), broadcaster);
        assertEq(uint8(nft.phase()), uint8(KozaCollection.Phase.Closed));
        assertEq(returnedDeployer, broadcaster);

        (address rcv, uint256 amt) = nft.royaltyInfo(1, 10_000);
        assertEq(rcv, royalty);
        assertEq(amt, 500);
    }

    function test_Deploy_WithCustomParameters() public {
        DeployERC721Collection deployer = new DeployERC721Collection();
        address customOwner = makeAddr("customOwner");
        address customRoyalty = makeAddr("customRoyalty");
        address customBroadcaster = makeAddr("customBroadcaster");

        (KozaCollection nft,) = deployer.deploy(
            "Custom Art",
            "ART",
            "https://meta.example/",
            100,
            0.001 ether,
            customRoyalty,
            1000,
            customOwner,
            customBroadcaster
        );

        assertEq(nft.name(), "Custom Art");
        assertEq(nft.maxSupply(), 100);
        assertEq(nft.owner(), customOwner);

        (address rcv, uint256 amt) = nft.royaltyInfo(1, 10_000);
        assertEq(rcv, customRoyalty);
        assertEq(amt, 1000); // %10
    }

    function test_Deploy_FreeMintNoRoyalty() public {
        DeployERC721Collection deployer = new DeployERC721Collection();
        address broadcaster = makeAddr("broadcaster");
        address royalty = makeAddr("royalty");

        (KozaCollection nft,) =
            deployer.deploy("Free Drop", "FREE", "ipfs://QmFreeCID/", 1000, 0, royalty, 0, broadcaster, broadcaster);

        assertEq(nft.mintPrice(), 0);

        (, uint256 amt) = nft.royaltyInfo(1, 10_000);
        assertEq(amt, 0);
    }
}
