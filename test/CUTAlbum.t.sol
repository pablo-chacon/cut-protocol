// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "forge-std/Test.sol";
import {CUTAlbum} from "../contracts/CUTAlbum.sol";
import {CUTSceneRegistry} from "../contracts/CUTSceneRegistry.sol";


contract CUTAlbumTest is Test {
    CUTSceneRegistry sceneRegistry;
    CUTAlbum album;

    address treasury = address(0xBEEF);
    address seller   = address(0xA11CE);
    address buyer    = address(0xB0B);

    bytes32 sceneId;
    uint256 albumId;


    function setUp() external {
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);

        sceneRegistry = new CUTSceneRegistry();

        sceneId = keccak256("scene:test");
        vm.prank(seller);
        sceneRegistry.createScene(sceneId, bytes32(0));

        album = new CUTAlbum(
            address(sceneRegistry),
            treasury,
            "CUT Album",
            "CUT"
        );

        // Create album once (Model A)
        vm.prank(seller);
        albumId = album.createAlbum(
            sceneId,
            keccak256("radioRoot"),
            keccak256("contentRoot"),
            10 // maxSupply
        );
    }

    /* -------------------------------------------------------------
       Test 1: protocol fee math (0.5%)
       ------------------------------------------------------------- */

    function test_protocolFeeIsExactlyPointFivePercent() external {
        uint256 price = 10 ether;
        uint256 expectedFee = (price * 50) / 10_000;

        vm.prank(seller);
        album.mintAlbumCopy{value: price}(
            albumId,
            buyer,
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
        album.mintAlbumCopy{value: price}(
            albumId,
            buyer,
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
       Test 3: free copy mint (price = 0) transfers no ETH
       ------------------------------------------------------------- */

    function test_freeMintTransfersNoEth() external {
        uint256 sellerBefore = seller.balance;
        uint256 treasuryBefore = treasury.balance;

        vm.prank(seller);
        album.mintAlbumCopy(
            albumId,
            buyer,
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

        album.mintAlbumCopy{value: price - 1}(
            albumId,
            buyer,
            "ipfs://album",
            price
        );
    }
}
