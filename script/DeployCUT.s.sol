// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {CUTSceneRegistry} from "../contracts/CUTSceneRegistry.sol";
import {CUTMedia1155} from "../contracts/CUTMedia1155.sol";

/// @notice Deploys CUTSceneRegistry and CUTMedia1155.
///
/// Required environment variables:
///   PRIVATE_KEY          Deployer private key (hex, no 0x prefix)
///   CUT_TREASURY         Protocol treasury address (strongly recommended: Safe multisig)
///   ETHERSCAN_API_KEY    Required when deploying with --verify
///
/// Mainnet deploy command (use FOUNDRY_PROFILE=mainnet for higher optimizer runs):
///
///   FOUNDRY_PROFILE=mainnet forge script script/DeployCUT.s.sol \
///     --rpc-url "$RPC_URL" \
///     --broadcast \
///     --verify \
///     --etherscan-api-key "$ETHERSCAN_API_KEY"
///
/// After deployment, record both contract addresses and the treasury address
/// in a permanent deployment manifest. These addresses are canonical and immutable.
contract DeployCUT is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("CUT_TREASURY");

        require(treasury != address(0), "DeployCUT: CUT_TREASURY must be set to a non-zero address");

        vm.startBroadcast(pk);

        CUTSceneRegistry sceneRegistry = new CUTSceneRegistry();
        CUTMedia1155 media = new CUTMedia1155(address(sceneRegistry), treasury);

        vm.stopBroadcast();

        console2.log("=== CUT Protocol Deployment ===");
        console2.log("CUTSceneRegistry:", address(sceneRegistry));
        console2.log("CUTMedia1155:    ", address(media));
        console2.log("CUT_TREASURY:    ", treasury);
        console2.log("================================");
        console2.log("Record these addresses. They are immutable.");
    }
}
