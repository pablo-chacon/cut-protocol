// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import {CUTTypes} from "./CUTTypes.sol";

interface ICUTSceneRegistryMinimal {
    function sceneExists(bytes32 sceneId) external view returns (bool);
}

/// @notice Album primitive for CUT.
///  - permissionless minting
///  - albums bind to a sceneId (must exist in registry)
///  - each album commits to a radioRoot (Merkle)
///  - optional contentRoot commitment
///  - no upgradeability, no admin, no pausing, no blacklists
///  - tokenURI is immutable post-mint (stored, no setters)

contract CUTAlbum is ERC721 {
    using CUTTypes for CUTTypes.RadioLeaf;

    event AlbumMinted(
        uint256 indexed albumId,
        bytes32 indexed sceneId,
        address indexed creator,
        address owner,
        bytes32 radioRoot,
        bytes32 contentRoot,
        string tokenURI
    );

    error UnknownScene(bytes32 sceneId);
    error InvalidRadioRoot();
    error InvalidRecipient();
    error NonexistentAlbum(uint256 albumId);

    ICUTSceneRegistryMinimal public immutable sceneRegistry;

    uint256 private _nextId = 1;

    mapping(uint256 => CUTTypes.AlbumData) private _albums;
    mapping(uint256 => string) private _tokenURIs;

    constructor(address sceneRegistry_, string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        sceneRegistry = ICUTSceneRegistryMinimal(sceneRegistry_);
    }

    /// @notice Mint a new album NFT.
    /// @param to Recipient/owner.
    /// @param sceneId Scene namespace (must exist in registry).
    /// @param radioRoot Merkle root committing to the radio field track set.
    /// @param contentRoot Optional Merkle root / hash committing to album bundle manifest.
    /// @param tokenURI_ Metadata URI (can be ipfs://CID/...); stored immutably.

    function mintAlbum(
        address to,
        bytes32 sceneId,
        bytes32 radioRoot,
        bytes32 contentRoot,
        string calldata tokenURI_
    ) external returns (uint256 albumId) {
        if (to == address(0)) revert InvalidRecipient();
        if (!sceneRegistry.sceneExists(sceneId)) revert UnknownScene(sceneId);
        if (radioRoot == bytes32(0)) revert InvalidRadioRoot();

        albumId = _nextId++;
        _safeMint(to, albumId);

        _albums[albumId] = CUTTypes.AlbumData({
            sceneId: sceneId,
            radioRoot: radioRoot,
            contentRoot: contentRoot,
            creator: msg.sender
        });

        _tokenURIs[albumId] = tokenURI_;

        emit AlbumMinted(albumId, sceneId, msg.sender, to, radioRoot, contentRoot, tokenURI_);
    }

    // Read primitives

    function albumScene(uint256 albumId) external view returns (bytes32) {
        _requireExists(albumId);
        return _albums[albumId].sceneId;
    }

    function albumRadioRoot(uint256 albumId) external view returns (bytes32) {
        _requireExists(albumId);
        return _albums[albumId].radioRoot;
    }

    function albumContentRoot(uint256 albumId) external view returns (bytes32) {
        _requireExists(albumId);
        return _albums[albumId].contentRoot;
    }

    function albumCreator(uint256 albumId) external view returns (address) {
        _requireExists(albumId);
        return _albums[albumId].creator;
    }

    /// @notice Token-gating primitive used by clients.
    function hasAccess(address user, uint256 albumId) external view returns (bool) {
        // access = ownership (v0)
        if (!_exists(albumId)) return false;
        return ownerOf(albumId) == user;
    }

    /// @notice Verify a track leaf is in an album's committed radio field.
    /// @param albumId Album id.
    /// @param leafHash keccak256(abi.encode(trackId, uriHash, licenseHash, sceneTag, artistRef))
    /// @param merkleProof Proof path for leaf membership.

    function verifyRadioLeafMembership(
        uint256 albumId,
        bytes32 leafHash,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        _requireExists(albumId);
        return MerkleProof.verify(merkleProof, _albums[albumId].radioRoot, leafHash);
    }

    /// @notice Convenience overload using the canonical struct encoding.
    function verifyRadioLeafMembershipStruct(
        uint256 albumId,
        CUTTypes.RadioLeaf calldata leaf,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        _requireExists(albumId);
        bytes32 leafHash = CUTTypes.hashRadioLeafFields(
            leaf.trackId,
            leaf.uriHash,
            leaf.licenseHash,
            leaf.sceneTag,
            leaf.artistRef
        );
        return MerkleProof.verify(merkleProof, _albums[albumId].radioRoot, leafHash);
    }

    // ERC721 tokenURI (immutable)
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireExists(tokenId);
        return _tokenURIs[tokenId];
    }

    // internal
    function _exists(uint256 tokenId) internal view returns (bool) {
        // ERC721 in OZ v5 uses _ownerOf.
        // _ownerOf is internal, relies on _requireOwned in v5.
        // Existence via _albums presence AND minted.
        // albumId is minted iff _albums[tokenId].sceneId != 0 (sceneId cannot be 0).
        return _albums[tokenId].sceneId != bytes32(0);
    }

    function _requireExists(uint256 tokenId) internal view {
        if (!_exists(tokenId)) revert NonexistentAlbum(tokenId);
    }
}
