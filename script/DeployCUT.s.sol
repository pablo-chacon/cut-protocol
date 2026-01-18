// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {CUTSceneRegistry} from "../contracts/CUTSceneRegistry.sol";
import {CUTAlbum} from "../contracts/CUTAlbum.sol";

contract DeployCUT is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Required
        address treasury = vm.envAddress("CUT_TREASURY");

        // Optional
        string memory name_ = vm.envOr("ALBUM_NAME", string("CUT Album"));
        string memory symbol_ = vm.envOr("ALBUM_SYMBOL", string("CUT"));

        vm.startBroadcast(pk);

        CUTSceneRegistry sceneRegistry = new CUTSceneRegistry();
        CUTAlbum album = new CUTAlbum(address(sceneRegistry), treasury, name_, symbol_);

        vm.stopBroadcast();

        console2.log("CUTSceneRegistry:", address(sceneRegistry));
        console2.log("CUTAlbum:", address(album));
        console2.log("CUT_TREASURY:", treasury);
    }
}
