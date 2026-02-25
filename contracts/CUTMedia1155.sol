// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {CUTTypes} from "./CUTTypes.sol";


interface ICUTSceneRegistryMinimal {
    function sceneExists(bytes32 sceneId) external view returns (bool);
}

/// @notice CUT Release primitive (Version: X, Model A, cross-medium).
/// - Releases are defined once with capped supply
/// - Each buyer receives ERC-1155 copies (amount = 1 per copy)
/// - Sale settlement at mint (ETH only) with immutable 0.5% protocol fee
///     - 0.5% to protocolTreasury
///     - 99.5% to seller (msg.sender)
/// - Artwork is committed on-chain via hash (+ optional URI)
/// - Optional discovery/demo commitment via Merkle root (can be 0)
/// - No admin controls, no upgrades, no pausability
contract CUTMedia1155 is ERC1155 {
    
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PROTOCOL_FEE_BPS = 50; // 0.5%

    address public immutable protocolTreasury;
    ICUTSceneRegistryMinimal public immutable sceneRegistry;


    struct Release {
        
        bytes32 sceneId;

        // Cross-medium abstraction:
        bytes32 mediumType;     // e.g. keccak256("music"), keccak256("book"), ...
        bytes32 contentRoot;    // commitment to paid content inventory (files/chapters/tracks/etc)
        bytes32 radioRoot;      // optional: commitment to discovery/demo set (can be 0)
        bytes32 artworkHash;    // commitment to artwork bytes or canonical image reference
        string  artworkURI;     // optional convenience pointer (IPFS/Arweave)

        address creator;
        uint256 maxSupply;
        uint256 minted;
        string  metadataURI;    // ERC-1155 uri(id) override uses per-release stored URI
    }


    uint256 private _nextReleaseId = 1;
    mapping(uint256 => Release) private _releases;


    event ReleaseCreated(
        uint256 indexed releaseId,
        bytes32 indexed sceneId,
        bytes32 indexed mediumType,
        address creator,
        uint256 maxSupply,
        bytes32 radioRoot,
        bytes32 contentRoot,
        bytes32 artworkHash,
        string artworkURI,
        string metadataURI
    );


    event ReleaseCopyMinted(
        uint256 indexed releaseId,
        address indexed seller,
        address indexed to,
        uint256 amount,
        uint256 priceWei,
        uint256 protocolFeeWei
    );


    event ProtocolFeePaid(uint256 indexed releaseId, address indexed treasury, uint256 feeWei);


    error UnknownScene(bytes32 sceneId);
    error InvalidRecipient();
    error InvalidTreasury();
    error InvalidPayment(uint256 expected, uint256 received);
    error EthTransferFailed(address to, uint256 amount);
    error NonexistentRelease(uint256 releaseId);
    error SupplyExceeded(uint256 releaseId);
    error InvalidMediumType();
    error InvalidMetadataURI();
    error InvalidMaxSupply();
    error InvalidAmount();


    constructor(address sceneRegistry_, address protocolTreasury_)
        ERC1155("") // we use per-release metadataURI, so base is empty
    {
        if (sceneRegistry_ == address(0)) revert InvalidRecipient();
        if (protocolTreasury_ == address(0)) revert InvalidTreasury();

        sceneRegistry = ICUTSceneRegistryMinimal(sceneRegistry_);
        protocolTreasury = protocolTreasury_;
    }

    // Release creation
    function createRelease(

        bytes32 sceneId,
        bytes32 mediumType,
        bytes32 radioRoot,       // allow 0 for non-music or unused discovery/demo
        bytes32 contentRoot,
        bytes32 artworkHash,     // allow 0 if you really want, but recommended non-zero
        string calldata artworkURI,
        string calldata metadataURI,
        uint256 maxSupply

    ) external returns (uint256 releaseId) {

        if (!sceneRegistry.sceneExists(sceneId)) revert UnknownScene(sceneId);
        if (mediumType == bytes32(0)) revert InvalidMediumType();
        if (maxSupply == 0) revert InvalidMaxSupply();
        if (bytes(metadataURI).length == 0) revert InvalidMetadataURI();


        releaseId = _nextReleaseId++;


        _releases[releaseId] = Release({
            sceneId: sceneId,
            mediumType: mediumType,
            contentRoot: contentRoot,
            radioRoot: radioRoot,
            artworkHash: artworkHash,
            artworkURI: artworkURI,
            creator: msg.sender,
            maxSupply: maxSupply,
            minted: 0,
            metadataURI: metadataURI
        });


        emit ReleaseCreated(
            releaseId,
            sceneId,
            mediumType,
            msg.sender,
            maxSupply,
            radioRoot,
            contentRoot,
            artworkHash,
            artworkURI,
            metadataURI
        );
    }

    // Copy mint (many, capped)
    /// @notice Mint copies of a release to `to`.
    /// @dev Typical usage: amount=1 (buy one copy).
    /// `priceWei` is the total payment for this mint call.
    function mintReleaseCopy(
        uint256 releaseId,
        address to,
        uint256 amount,
        uint256 priceWei
    ) external payable {

        Release storage rel = _releases[releaseId];
        if (rel.sceneId == bytes32(0)) revert NonexistentRelease(releaseId);
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();


        uint256 newMinted = rel.minted + amount;
        if (newMinted > rel.maxSupply) revert SupplyExceeded(releaseId);
        if (msg.value != priceWei) revert InvalidPayment(priceWei, msg.value);


        rel.minted = newMinted;

        _mint(to, releaseId, amount, "");

        uint256 protocolFee = 0;


        if (priceWei > 0) {
            protocolFee = (priceWei * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
            uint256 sellerProceeds = priceWei - protocolFee;

            if (protocolFee > 0) {
                _safeTransferEth(protocolTreasury, protocolFee);
                emit ProtocolFeePaid(releaseId, protocolTreasury, protocolFee);
            }

            if (sellerProceeds > 0) {
                _safeTransferEth(msg.sender, sellerProceeds);
            }
        }


        emit ReleaseCopyMinted(
            releaseId,
            msg.sender,
            to,
            amount,
            priceWei,
            protocolFee
        );
    }

    // Read primitives
    function releaseScene(uint256 releaseId) external view returns (bytes32) {
        _requireReleaseExists(releaseId);
        return _releases[releaseId].sceneId;
    }


    function releaseMediumType(uint256 releaseId) external view returns (bytes32) {
        _requireReleaseExists(releaseId);
        return _releases[releaseId].mediumType;
    }


    function releaseRadioRoot(uint256 releaseId) external view returns (bytes32) {
        _requireReleaseExists(releaseId);
        return _releases[releaseId].radioRoot;
    }


    function releaseContentRoot(uint256 releaseId) external view returns (bytes32) {
        _requireReleaseExists(releaseId);
        return _releases[releaseId].contentRoot;
    }


    function releaseArtworkHash(uint256 releaseId) external view returns (bytes32) {
        _requireReleaseExists(releaseId);
        return _releases[releaseId].artworkHash;
    }


    function releaseArtworkURI(uint256 releaseId) external view returns (string memory) {
        _requireReleaseExists(releaseId);
        return _releases[releaseId].artworkURI;
    }


    function releaseCreator(uint256 releaseId) external view returns (address) {
        _requireReleaseExists(releaseId);
        return _releases[releaseId].creator;
    }


    function releaseSupply(uint256 releaseId) external view returns (uint256 minted, uint256 maxSupply) {
        _requireReleaseExists(releaseId);
        Release storage rel = _releases[releaseId];
        return (rel.minted, rel.maxSupply);
    }

    /// @notice Authorization primitive: owning any copy grants access.
    function hasAccess(address user, uint256 releaseId) external view returns (bool) {
        if (_releases[releaseId].sceneId == bytes32(0)) return false;
        return balanceOf(user, releaseId) > 0;
    }

    // Discovery verification
    function verifyDiscoveryLeafMembership(
        uint256 releaseId,
        bytes32 leafHash,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        _requireReleaseExists(releaseId);
        bytes32 root = _releases[releaseId].radioRoot;
        if (root == bytes32(0)) return false;
        return MerkleProof.verify(merkleProof, root, leafHash);
    }


    function verifyDiscoveryLeafMembershipStruct(
        uint256 releaseId,
        CUTTypes.DiscoveryLeaf calldata leaf,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        _requireReleaseExists(releaseId);
        bytes32 root = _releases[releaseId].radioRoot;
        if (root == bytes32(0)) return false;

        bytes32 leafHash = CUTTypes.hashDiscoveryLeafFields(
            leaf.itemId,
            leaf.uriHash,
            leaf.licenseHash,
            leaf.sceneTag,
            leaf.creatorRef
        );

        return MerkleProof.verify(merkleProof, root, leafHash);
    }

    // ERC-1155 metadata
    function uri(uint256 releaseId) public view override returns (string memory) {
        _requireReleaseExists(releaseId);
        return _releases[releaseId].metadataURI;
    }

    // Internal helpers
    function _requireReleaseExists(uint256 releaseId) internal view {
        if (_releases[releaseId].sceneId == bytes32(0)) revert NonexistentRelease(releaseId);
    }


    function _safeTransferEth(address to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert EthTransferFailed(to, amount);
    }
}
