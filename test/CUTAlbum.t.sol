// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "forge-std/Test.sol";
import {CUTAlbum} from "../src/CUTAlbum.sol";
import {CUTSceneRegistry} from "../src/CUTSceneRegistry.sol";


contract CUTAlbumTest is Test {
    CUTSceneRegistry sceneRegistry;
    CUTAlbum album;

    address treasury = address(0xBEEF);
    address seller   = address(0xA11CE);
    address buyer    = address(0xB0B);

    bytes32 sceneId;

    function setUp() external {
        // Fund actors
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);

        // Deploy scene registry
        sceneRegistry = new CUTSceneRegistry();

        // Create a scene
        sceneId = keccak256("scene:test");
        vm.prank(seller);
        sceneRegistry.createScene(sceneId, bytes32(0));

        // Deploy album contract
        album = new CUTAlbum(
            address(sceneRegistry),
            treasury,
            "CUT Album",
            "CUT"
        );
    }

    /* -------------------------------------------------------------
       Test 1: protocol fee math (0.5%)
       ------------------------------------------------------------- */

    function test_protocolFeeIsExactlyPointFivePercent() external {
        uint256 price = 10 ether;
        uint256 expectedFee = (price * 50) / 10_000;

        vm.prank(seller);
        album.mintAlbum{value: price}(
            buyer,
            sceneId,
            keccak256("radioRoot"),
            keccak256("contentRoot"),
            "ipfs://album",
            price
        );

        assertEq(address(treasury).balance, expectedFee, "protocol fee incorrect");
    }

    /* -------------------------------------------------------------
       Test 2: treasury receives fee, seller receives remainder
       ------------------------------------------------------------- */

    function test_feeAndSellerProceedsSplitCorrectly() external {
        uint256 price = 5 ether;
        uint256 expectedFee = (price * 50) / 10_000;
        uint256 expectedSeller = price - expectedFee;

        uint256 sellerBefore = seller.balance;
        uint256 treasuryBefore = treasury.balance;

        vm.prank(seller);
        album.mintAlbum{value: price}(
            buyer,
            sceneId,
            keccak256("radioRoot"),
            keccak256("contentRoot"),
            "ipfs://album",
            price
        );

        assertEq(
            seller.balance,
            sellerBefore + expectedSeller,
            "seller proceeds incorrect"
        );

        assertEq(
            treasury.balance,
            treasuryBefore + expectedFee,
            "treasury proceeds incorrect"
        );
    }

    /* -------------------------------------------------------------
       Test 3: free mint (price = 0) transfers no ETH
       ------------------------------------------------------------- */

    function test_freeMintTransfersNoEth() external {
        uint256 sellerBefore = seller.balance;
        uint256 treasuryBefore = treasury.balance;

        vm.prank(seller);
        album.mintAlbum(
            buyer,
            sceneId,
            keccak256("radioRoot"),
            keccak256("contentRoot"),
            "ipfs://album",
            0
        );

        assertEq(seller.balance, sellerBefore, "seller balance changed");
        assertEq(treasury.balance, treasuryBefore, "treasury balance changed");
    }

    /* -------------------------------------------------------------
       Test 4: revert if msg.value != priceWei
       ------------------------------------------------------------- */

    function test_revertsOnIncorrectPayment() external {
        uint256 price = 1 ether;

        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidPayment(uint256,uint256)",
                price,
                price - 1
            )
        );

        album.mintAlbum{value: price - 1}(
            buyer,
            sceneId,
            keccak256("radioRoot"),
            keccak256("contentRoot"),
            "ipfs://album",
            price
        );
    }
}
