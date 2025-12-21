// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {CUTSceneRegistry} from "../src/CUTSceneRegistry.sol";
import {CUTAlbum} from "../src/CUTAlbum.sol";

contract DeployV0 is Script {
    function run() external {
        // Environment:
        // - PRIVATE_KEY: deployer key
        // - ALBUM_NAME: optional (default "CUT Album")
        // - ALBUM_SYMBOL: optional (default "CUT")
        uint256 pk = vm.envUint("PRIVATE_KEY");

        string memory name_ = vm.envOr("ALBUM_NAME", string("CUT Album"));
        string memory symbol_ = vm.envOr("ALBUM_SYMBOL", string("CUT"));

        vm.startBroadcast(pk);

        CUTSceneRegistry sceneRegistry = new CUTSceneRegistry();
        CUTAlbum album = new CUTAlbum(address(sceneRegistry), name_, symbol_);

        vm.stopBroadcast();

        console2.log("CUTSceneRegistry:", address(sceneRegistry));
        console2.log("CUTAlbum:", address(album));
    }
}
