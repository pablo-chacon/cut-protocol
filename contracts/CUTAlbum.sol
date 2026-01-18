// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {CUTTypes} from "./CUTTypes.sol";

interface ICUTSceneRegistryMinimal {
    function sceneExists(bytes32 sceneId) external view returns (bool);
}

/// @notice CUT Album primitive (v0, Model A).
/// - Albums are defined once with capped supply
/// - Each buyer receives a unique ERC-721 copy
/// - Sale settlement at mint (ETH only) with immutable 0.5% protocol fee
/// - No admin controls, no upgrades, no pausability
contract CUTAlbum is ERC721 {

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PROTOCOL_FEE_BPS = 50; // 0.5%

    address public immutable protocolTreasury;
    ICUTSceneRegistryMinimal public immutable sceneRegistry;

    // ---------------------------------------------------------------------
    // Album storage (album-level)
    // ---------------------------------------------------------------------

    struct Album {
        bytes32 sceneId;
        bytes32 radioRoot;
        bytes32 contentRoot;
        address creator;
        uint256 maxSupply;
        uint256 minted;
    }

    uint256 private _nextAlbumId = 1;
    mapping(uint256 => Album) private _albums;

    // ---------------------------------------------------------------------
    // Token storage (copy-level)
    // ---------------------------------------------------------------------

    uint256 private _nextTokenId = 1;
    mapping(uint256 => uint256) private _tokenToAlbum;
    mapping(uint256 => string) private _tokenURIs;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event AlbumCreated(
        uint256 indexed albumId,
        bytes32 indexed sceneId,
        address indexed creator,
        uint256 maxSupply,
        bytes32 radioRoot,
        bytes32 contentRoot
    );

    event AlbumCopyMinted(
        uint256 indexed albumId,
        uint256 indexed tokenId,
        address indexed seller,
        address owner,
        uint256 priceWei,
        uint256 protocolFeeWei,
        string tokenURI
    );

    event ProtocolFeePaid(uint256 indexed albumId, address indexed treasury, uint256 feeWei);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error UnknownScene(bytes32 sceneId);
    error InvalidRadioRoot();
    error InvalidRecipient();
    error InvalidTreasury();
    error InvalidPayment(uint256 expected, uint256 received);
    error EthTransferFailed(address to, uint256 amount);
    error NonexistentAlbum(uint256 albumId);
    error SupplyExceeded(uint256 albumId);

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

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

    // ---------------------------------------------------------------------
    // Album creation (once)
    // ---------------------------------------------------------------------

    function createAlbum(
        bytes32 sceneId,
        bytes32 radioRoot,
        bytes32 contentRoot,
        uint256 maxSupply
    ) external returns (uint256 albumId) {
        if (!sceneRegistry.sceneExists(sceneId)) revert UnknownScene(sceneId);
        if (radioRoot == bytes32(0)) revert InvalidRadioRoot();
        if (maxSupply == 0) revert SupplyExceeded(0);

        albumId = _nextAlbumId++;

        _albums[albumId] = Album({
            sceneId: sceneId,
            radioRoot: radioRoot,
            contentRoot: contentRoot,
            creator: msg.sender,
            maxSupply: maxSupply,
            minted: 0
        });

        emit AlbumCreated(
            albumId,
            sceneId,
            msg.sender,
            maxSupply,
            radioRoot,
            contentRoot
        );
    }

    // ---------------------------------------------------------------------
    // Copy mint (many, capped)
    // ---------------------------------------------------------------------

    function mintAlbumCopy(
        uint256 albumId,
        address to,
        string calldata tokenURI_,
        uint256 priceWei
    ) external payable returns (uint256 tokenId) {
        Album storage album = _albums[albumId];
        if (album.sceneId == bytes32(0)) revert NonexistentAlbum(albumId);
        if (album.minted >= album.maxSupply) revert SupplyExceeded(albumId);
        if (to == address(0)) revert InvalidRecipient();
        if (msg.value != priceWei) revert InvalidPayment(priceWei, msg.value);

        album.minted += 1;

        tokenId = _nextTokenId++;
        _tokenToAlbum[tokenId] = albumId;
        _tokenURIs[tokenId] = tokenURI_;

        _safeMint(to, tokenId);

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

        emit AlbumCopyMinted(
            albumId,
            tokenId,
            msg.sender,
            to,
            priceWei,
            fee,
            tokenURI_
        );
    }

    // ---------------------------------------------------------------------
    // Read primitives
    // ---------------------------------------------------------------------

    function albumScene(uint256 albumId) external view returns (bytes32) {
        _requireAlbumExists(albumId);
        return _albums[albumId].sceneId;
    }

    function albumRadioRoot(uint256 albumId) external view returns (bytes32) {
        _requireAlbumExists(albumId);
        return _albums[albumId].radioRoot;
    }

    function albumContentRoot(uint256 albumId) external view returns (bytes32) {
        _requireAlbumExists(albumId);
        return _albums[albumId].contentRoot;
    }

    function albumCreator(uint256 albumId) external view returns (address) {
        _requireAlbumExists(albumId);
        return _albums[albumId].creator;
    }

    function tokenAlbum(uint256 tokenId) external view returns (uint256) {
        if (!_exists(tokenId)) revert NonexistentAlbum(tokenId);
        return _tokenToAlbum[tokenId];
    }

    function hasAccess(address user, uint256 tokenId) external view returns (bool) {
        return _exists(tokenId) && ownerOf(tokenId) == user;
    }

    // ---------------------------------------------------------------------
    // Radio verification (unchanged semantics)
    // ---------------------------------------------------------------------

    function verifyRadioLeafMembership(
        uint256 albumId,
        bytes32 leafHash,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        _requireAlbumExists(albumId);
        return MerkleProof.verify(merkleProof, _albums[albumId].radioRoot, leafHash);
    }

    function verifyRadioLeafMembershipStruct(
        uint256 albumId,
        CUTTypes.RadioLeaf calldata leaf,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        _requireAlbumExists(albumId);

        bytes32 leafHash = CUTTypes.hashRadioLeafFields(
            leaf.trackId,
            leaf.uriHash,
            leaf.licenseHash,
            leaf.sceneTag,
            leaf.artistRef
        );

        return MerkleProof.verify(merkleProof, _albums[albumId].radioRoot, leafHash);
    }

    // ---------------------------------------------------------------------
    // ERC721 metadata
    // ---------------------------------------------------------------------

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert NonexistentAlbum(tokenId);
        return _tokenURIs[tokenId];
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _requireAlbumExists(uint256 albumId) internal view {
        if (_albums[albumId].sceneId == bytes32(0)) revert NonexistentAlbum(albumId);
    }

    function _safeTransferEth(address to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert EthTransferFailed(to, amount);
    }
}
