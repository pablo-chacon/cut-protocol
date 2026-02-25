// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {CUTMedia1155} from "../contracts/CUTMedia1155.sol";
import {CUTSceneRegistry} from "../contracts/CUTSceneRegistry.sol";
import {CUTTypes} from "../contracts/CUTTypes.sol";

contract CUTMedia1155Test is Test {
    CUTSceneRegistry sceneRegistry;
    CUTMedia1155 media;

    address treasury = address(0xBEEF);
    address seller   = address(0xA11CE);
    address buyer    = address(0xB0B);

    bytes32 sceneId;
    uint256 releaseId;

    bytes32 mediumType;
    bytes32 radioRoot;
    bytes32 contentRoot;
    bytes32 artworkHash;

    string artworkURI;
    string metadataURI;

    function setUp() external {
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);

        sceneRegistry = new CUTSceneRegistry();

        sceneId = keccak256("scene:test");
        vm.prank(seller);
        sceneRegistry.createScene(sceneId, bytes32(0));

        media = new CUTMedia1155(address(sceneRegistry), treasury);

        mediumType  = keccak256("music");
        contentRoot = keccak256("contentRoot");
        artworkHash = keccak256("artworkHash");
        artworkURI  = "ipfs://artwork";
        metadataURI = "ipfs://metadata";
        radioRoot   = keccak256("radioRoot");

        vm.prank(seller);
        releaseId = media.createRelease(
            sceneId,
            mediumType,
            radioRoot,
            contentRoot,
            artworkHash,
            artworkURI,
            metadataURI,
            10
        );
    }

    function test_protocolFeeIsExactlyPointFivePercent() external {
        uint256 price = 10 ether;
        uint256 expectedFee = (price * 50) / 10_000;

        vm.prank(seller);
        media.mintReleaseCopy{value: price}(releaseId, buyer, 1, price);

        assertEq(address(treasury).balance, expectedFee);
    }

    function test_feeAndSellerProceedsSplitCorrectly() external {
        uint256 price = 5 ether;
        uint256 expectedFee = (price * 50) / 10_000;
        uint256 expectedSeller = price - expectedFee;

        uint256 sellerBefore = seller.balance;

        vm.prank(seller);
        media.mintReleaseCopy{value: price}(releaseId, buyer, 1, price);

        assertEq(seller.balance, sellerBefore + expectedSeller);
        assertEq(address(treasury).balance, expectedFee);
    }

    function test_freeMintTransfersNoEth() external {
        uint256 sellerBefore = seller.balance;
        uint256 treasuryBefore = treasury.balance;

        vm.prank(seller);
        media.mintReleaseCopy(releaseId, buyer, 1, 0);

        assertEq(seller.balance, sellerBefore);
        assertEq(treasury.balance, treasuryBefore);
    }

    function test_revertsOnIncorrectPayment() external {
        uint256 price = 1 ether;

        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(
                CUTMedia1155.InvalidPayment.selector,
                price,
                price - 1
            )
        );

        media.mintReleaseCopy{value: price - 1}(releaseId, buyer, 1, price);
    }

    function test_revertsWhenSupplyExceeded() external {
        uint256 price = 1 ether;

        vm.prank(seller);
        media.mintReleaseCopy{value: price}(releaseId, buyer, 10, price);

        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(
                CUTMedia1155.SupplyExceeded.selector,
                releaseId
            )
        );

        media.mintReleaseCopy{value: price}(releaseId, buyer, 1, price);
    }

    function test_hasAccessIsTrueAfterMint() external {
        assertEq(media.hasAccess(buyer, releaseId), false);

        uint256 price = 2 ether;
        vm.prank(seller);
        media.mintReleaseCopy{value: price}(releaseId, buyer, 1, price);

        assertEq(media.hasAccess(buyer, releaseId), true);
    }

    function test_verifyDiscoveryReturnsFalseWhenRootIsZero() external {
        bytes32 otherScene = keccak256("scene:other");

        vm.prank(seller);
        sceneRegistry.createScene(otherScene, bytes32(0));

        vm.prank(seller);
        uint256 noRootRelease = media.createRelease(
            otherScene,
            mediumType,
            bytes32(0),
            contentRoot,
            artworkHash,
            artworkURI,
            metadataURI,
            1
        );

        bytes32;

        bool ok = media.verifyDiscoveryLeafMembership(
            noRootRelease,
            keccak256("leaf"),
            emptyProof
        );

        assertEq(ok, false);
    }

    function test_verifyDiscoveryHappyPath_twoLeaves_hash() external {
        bytes32 leafA = keccak256("leafA");
        bytes32 leafB = keccak256("leafB");

        bytes32 root = _hashPairCommutative(leafA, leafB);

        bytes32 otherScene = keccak256("scene:merkle");

        vm.prank(seller);
        sceneRegistry.createScene(otherScene, bytes32(0));

        vm.prank(seller);
        uint256 merkleRelease = media.createRelease(
            otherScene,
            mediumType,
            root,
            contentRoot,
            artworkHash,
            artworkURI,
            metadataURI,
            1
        );

        bytes32;
        proofA[0] = leafB;

        assertTrue(media.verifyDiscoveryLeafMembership(merkleRelease, leafA, proofA));

        bytes32;
        proofB[0] = leafA;

        assertTrue(media.verifyDiscoveryLeafMembership(merkleRelease, leafB, proofB));
    }

    function _hashPairCommutative(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        if (a < b) return keccak256(abi.encodePacked(a, b));
        return keccak256(abi.encodePacked(b, a));
    }
}