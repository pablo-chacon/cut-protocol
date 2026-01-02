// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Canonical types + hashing for CUT v0.
/// Design intent:
///  - deterministic leaf hashing
///  - avoid string encoding ambiguity inside leaves
///  - keep on-chain data minimal and verifiable
library CUTTypes {

    // ---------------------------------------------------------------------
    // Scene
    // ---------------------------------------------------------------------

    struct Scene {
        address creator;
        bytes32 manifestHash; // optional commitment to off-chain scene manifest
        bool exists;
    }

    // ---------------------------------------------------------------------
    // Radio leaf
    // ---------------------------------------------------------------------

    /// @notice Canonical radio track leaf fields. All fixed-width to prevent ambiguity.
    /// @dev uriHash is keccak256(utf8(uri)), not the uri string.
    ///      licenseHash is keccak256(utf8(licenseText)) OR a precomputed hash.
    ///      sceneTag is optional tag hash; use bytes32(0) if unused.
    ///      artistRef is optional DID/ENS hash; use bytes32(0) if unused.
    struct RadioLeaf {
        bytes32 trackId;
        bytes32 uriHash;
        bytes32 licenseHash;
        bytes32 sceneTag;
        bytes32 artistRef;
    }

    /// @notice Canonical leaf hash.
    /// @dev This exact encoding must be used by off-chain tooling.
    function hashRadioLeaf(RadioLeaf memory leaf) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                leaf.trackId,
                leaf.uriHash,
                leaf.licenseHash,
                leaf.sceneTag,
                leaf.artistRef
            )
        );
    }

    /// @notice Convenience helper: hash leaf from individual fields.
    function hashRadioLeafFields(
        bytes32 trackId,
        bytes32 uriHash,
        bytes32 licenseHash,
        bytes32 sceneTag,
        bytes32 artistRef
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                trackId,
                uriHash,
                licenseHash,
                sceneTag,
                artistRef
            )
        );
    }
}

