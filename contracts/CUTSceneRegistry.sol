// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CUTTypes} from "./CUTTypes.sol";

/// @notice Scene registry primitive for CUT.
/// - creates immutable scene namespaces
/// - no curation lists, no ranking, no social graph
/// - no admin controls

contract CUTSceneRegistry {
    using CUTTypes for CUTTypes.Scene;

    event SceneCreated(bytes32 indexed sceneId, address indexed creator, bytes32 manifestHash);

    error SceneAlreadyExists(bytes32 sceneId);
    error InvalidSceneId();
    error InvalidManifestHash(); // optional: allow 0, but keep explicit checks available

    mapping(bytes32 => CUTTypes.Scene) private _scenes;

    /// @notice Create a scene namespace.
    /// @dev sceneId should be a stable, collision-resistant id created off-chain.
    /// Recommended: sceneId = keccak256(utf8("scene:<name-or-handle>:<salt>"))
    function createScene(bytes32 sceneId, bytes32 manifestHash) external {
        if (sceneId == bytes32(0)) revert InvalidSceneId();
        if (_scenes[sceneId].exists) revert SceneAlreadyExists(sceneId);

        _scenes[sceneId] = CUTTypes.Scene({
            creator: msg.sender,
            manifestHash: manifestHash,
            exists: true
        });

        emit SceneCreated(sceneId, msg.sender, manifestHash);
    }

    function sceneExists(bytes32 sceneId) external view returns (bool) {
        return _scenes[sceneId].exists;
    }

    function sceneCreator(bytes32 sceneId) external view returns (address) {
        return _scenes[sceneId].creator;
    }

    function sceneManifestHash(bytes32 sceneId) external view returns (bytes32) {
        return _scenes[sceneId].manifestHash;
    }
}
