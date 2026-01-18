// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {CUTSceneRegistry} from "../contracts/CUTSceneRegistry.sol";
import {CUTMedia1155} from "../contracts/CUTMedia1155.sol";

contract DeployCUT is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("CUT_TREASURY");

        vm.startBroadcast(pk);

        CUTSceneRegistry sceneRegistry = new CUTSceneRegistry();
        CUTMedia1155 media = new CUTMedia1155(address(sceneRegistry), treasury);

        vm.stopBroadcast();

        console2.log("CUTSceneRegistry:", address(sceneRegistry));
        console2.log("CUTMedia1155:", address(media));
        console2.log("CUT_TREASURY:", treasury);
    }
}
