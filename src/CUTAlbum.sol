// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {CUTTypes} from "./CUTTypes.sol";


interface ICUTSceneRegistryMinimal {
    function sceneExists(bytes32 sceneId) external view returns (bool);
}

/// @notice CUT Album primitive (v0).
/// - Permissionless minting
/// - Sale settlement at mint (ETH only) with immutable 0.5% protocol fee
/// - No admin controls, no upgrades, no pausability, no blacklists
contract CUTAlbum is ERC721 {
    
    // Immutable protocol economics 
    /// @notice Basis points denominator (100% = 10,000 bps)
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Immutable protocol fee: 0.5% = 50 bps
    uint256 public constant PROTOCOL_FEE_BPS = 50;

    /// @notice Immutable treasury recipient of protocol fee.
    address public immutable protocolTreasury;

    // External dependencies 

    ICUTSceneRegistryMinimal public immutable sceneRegistry;

    // Storage

    uint256 private _nextId = 1;

    mapping(uint256 => CUTTypes.AlbumData) private _albums;
    mapping(uint256 => string) private _tokenURIs;

    // Events

    event AlbumMinted(
        uint256 indexed albumId,
        bytes32 indexed sceneId,
        address indexed seller,
        address owner,
        uint256 priceWei,
        uint256 protocolFeeWei,
        bytes32 radioRoot,
        bytes32 contentRoot,
        string tokenURI
    );

    event ProtocolFeePaid(uint256 indexed albumId, address indexed treasury, uint256 feeWei);

    // Errors

    error UnknownScene(bytes32 sceneId);
    error InvalidRadioRoot();
    error InvalidRecipient();
    error InvalidTreasury();
    error NonexistentAlbum(uint256 albumId);
    error InvalidPayment(uint256 expected, uint256 received);
    error EthTransferFailed(address to, uint256 amount);

    // Constructor

    constructor(
        address sceneRegistry_,
        address protocolTreasury_,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {
        if (sceneRegistry_ == address(0)) revert InvalidRecipient();
        if (protocolTreasury_ == address(0)) revert InvalidTreasury();

        sceneRegistry = ICUTSceneRegistryMinimal(sceneRegistry_);
        protocolTreasury = protocolTreasury_;
    }

    // Primary sale mint

    /// @notice Mint a new album NFT with primary sale settlement.
    /// @dev Buyer sends `msg.value == priceWei`. Seller is msg.sender and receives proceeds minus fee.
    ///      Use priceWei=0 for free mint (no fee, no transfers).
    ///
    /// @param to Recipient/owner (buyer).
    /// @param sceneId Scene namespace (must exist).
    /// @param radioRoot Merkle root commitment of the album's radio field.
    /// @param contentRoot Optional content commitment (album bundle manifest hash/root).
    /// @param tokenURI_ Metadata URI (stored immutably).
    /// @param priceWei Primary sale price in wei.
    function mintAlbum(
        address to,
        bytes32 sceneId,
        bytes32 radioRoot,
        bytes32 contentRoot,
        string calldata tokenURI_,
        uint256 priceWei
    ) external payable returns (uint256 albumId) {
        if (to == address(0)) revert InvalidRecipient();
        if (!sceneRegistry.sceneExists(sceneId)) revert UnknownScene(sceneId);
        if (radioRoot == bytes32(0)) revert InvalidRadioRoot();

        if (msg.value != priceWei) revert InvalidPayment(priceWei, msg.value);

        // Mint first (checks-effects-interactions)
        albumId = _nextId++;
        _safeMint(to, albumId);

        _albums[albumId] = CUTTypes.AlbumData({
            sceneId: sceneId,
            radioRoot: radioRoot,
            contentRoot: contentRoot,
            creator: msg.sender
        });

        _tokenURIs[albumId] = tokenURI_;

        // Settle payment
        uint256 fee = 0;
        if (priceWei > 0) {
            fee = (priceWei * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
            uint256 sellerProceeds = priceWei - fee;

            if (fee > 0) {
                _safeTransferEth(protocolTreasury, fee);
                emit ProtocolFeePaid(albumId, protocolTreasury, fee);
            }

            if (sellerProceeds > 0) {
                _safeTransferEth(msg.sender, sellerProceeds);
            }
        }

        emit AlbumMinted(
            albumId,
            sceneId,
            msg.sender,
            to,
            priceWei,
            fee,
            radioRoot,
            contentRoot,
            tokenURI_
        );
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
        if (!_exists(albumId)) return false;
        return ownerOf(albumId) == user;
    }

    /// @notice Verify a leaf is in an album's committed radio field.
    function verifyRadioLeafMembership(
        uint256 albumId,
        bytes32 leafHash,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        _requireExists(albumId);
        return MerkleProof.verify(merkleProof, _albums[albumId].radioRoot, leafHash);
    }

    /// @notice Convenience overload using canonical struct encoding.
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

    // ERC721 tokenURI

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireExists(tokenId);
        return _tokenURIs[tokenId];
    }

    // Internal helpers

    function _exists(uint256 tokenId) internal view returns (bool) {
        // Existence is anchored by stored album data; sceneId cannot be zero for minted albums.
        return _albums[tokenId].sceneId != bytes32(0);
    }

    function _requireExists(uint256 tokenId) internal view {
        if (!_exists(tokenId)) revert NonexistentAlbum(tokenId);
    }

    function _safeTransferEth(address to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert EthTransferFailed(to, amount);
    }
}
