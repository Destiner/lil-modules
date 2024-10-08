// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";

import { TokenStaker } from "src/TokenValidator/TokenStaker.sol";
import { MintableERC20 } from "test/utils/MintableERC20.sol";
import { MintableERC721 } from "test/utils/MintableERC721.sol";
import { MintableERC1155 } from "test/utils/MintableERC1155.sol";

contract TokenStakerTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    TokenStaker internal _tokenStaker;

    /*//////////////////////////////////////////////////////////////////////////
                                CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    address public immutable ACCOUNT_A = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
    address public immutable ACCOUNT_B = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address private _account;
    IERC20 private _erc20Token;
    IERC721 private _erc721Token;
    IERC1155 private _erc1155Token;
    address[] private _owners;
    uint256[] private _ownerPks;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public {
        _owners = new address[](2);
        _ownerPks = new uint256[](2);

        (address _owner1, uint256 _owner1Pk) = makeAddrAndKey("validOwner1");
        _owners[0] = _owner1;
        _ownerPks[0] = _owner1Pk;
        (address _owner2, uint256 _owner2Pk) = makeAddrAndKey("validOwner2");
        _owners[1] = _owner2;
        _ownerPks[1] = _owner2Pk;

        MintableERC20 _mintableErc20 = new MintableERC20("TKN", "Token");
        _mintableErc20.mint(_owners[0], 100);
        _mintableErc20.mint(_owners[1], 200);
        _erc20Token = IERC20(address(_mintableErc20));

        MintableERC721 _mintableErc721 = new MintableERC721("NFT", "Non-Fungible Token");
        _mintableErc721.mint(_owners[0], 1);
        _mintableErc721.mint(_owners[0], 2);
        _mintableErc721.mint(_owners[1], 3);
        _erc721Token = IERC721(address(_mintableErc721));

        MintableERC1155 _mintableErc1155 = new MintableERC1155();
        _mintableErc1155.mint(_owners[0], 1, 10, "");
        _mintableErc1155.mint(_owners[0], 2, 5, "");
        _mintableErc1155.mint(_owners[1], 1, 5, "");
        _erc1155Token = IERC1155(address(_mintableErc1155));

        _tokenStaker = new TokenStaker();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_StakeErc20RevertWhen_InsufficientAllowance() public {
        vm.startPrank(_owners[0]);

        vm.expectRevert();
        _tokenStaker.stakeErc20(ACCOUNT_A, _erc20Token, 100);
    }

    function test_StakeErc20RevertWhen_InsufficientBalance() public {
        vm.startPrank(_owners[0]);

        _erc20Token.approve(address(_tokenStaker), 1000);

        vm.expectRevert();
        _tokenStaker.stakeErc20(ACCOUNT_A, _erc20Token, 1000);
    }

    function test_StakerErc20When_ValidBalance() public {
        vm.startPrank(_owners[0]);

        uint256 oldOwnerStake = _tokenStaker.erc20StakeOf(_owners[0], _erc20Token, ACCOUNT_A);
        uint256 oldOwnerTokenBalance = _erc20Token.balanceOf(_owners[0]);
        uint256 oldContractTokenBalance = _erc20Token.balanceOf(address(_tokenStaker));
        uint256 oldDiffAccountStake = _tokenStaker.erc20StakeOf(_owners[0], _erc20Token, ACCOUNT_B);
        uint256 oldDiffOwnerStake = _tokenStaker.erc20StakeOf(_owners[1], _erc20Token, ACCOUNT_A);

        _erc20Token.approve(address(_tokenStaker), 100);
        _tokenStaker.stakeErc20(ACCOUNT_A, _erc20Token, 100);

        uint256 newOwnerStake = _tokenStaker.erc20StakeOf(_owners[0], _erc20Token, ACCOUNT_A);
        assertEq(newOwnerStake - oldOwnerStake, 100);

        uint256 newOwnerTokenBalance = _erc20Token.balanceOf(_owners[0]);
        assertEq(oldOwnerTokenBalance - newOwnerTokenBalance, 100);

        uint256 newContractTokenBalance = _erc20Token.balanceOf(address(_tokenStaker));
        assertEq(newContractTokenBalance - oldContractTokenBalance, 100);

        uint256 newDiffAccountStake = _tokenStaker.erc20StakeOf(_owners[0], _erc20Token, ACCOUNT_B);
        assertEq(oldDiffAccountStake, newDiffAccountStake);

        uint256 newDiffOwnerStake = _tokenStaker.erc20StakeOf(_owners[1], _erc20Token, ACCOUNT_A);
        assertEq(oldDiffOwnerStake, newDiffOwnerStake);
    }

    function test_UnstakeErc20RevertWhen_InsufficientBalance() public {
        vm.startPrank(_owners[0]);
        _erc20Token.approve(address(_tokenStaker), 100);
        _tokenStaker.stakeErc20(ACCOUNT_A, _erc20Token, 100);

        vm.expectRevert();
        _tokenStaker.unstakeErc20(ACCOUNT_A, _erc20Token, 1000);
    }

    function test_UnstakeErc20RevertWhen_InvalidAccount() public {
        vm.startPrank(_owners[0]);
        _erc20Token.approve(address(_tokenStaker), 100);
        _tokenStaker.stakeErc20(ACCOUNT_A, _erc20Token, 100);

        vm.expectRevert();
        _tokenStaker.unstakeErc20(ACCOUNT_B, _erc20Token, 100);
    }

    function test_UnstakeErc20RevertWhen_InvalidOwner() public {
        vm.startPrank(_owners[0]);
        _erc20Token.approve(address(_tokenStaker), 100);
        _tokenStaker.stakeErc20(ACCOUNT_A, _erc20Token, 100);

        vm.startPrank(_owners[1]);
        vm.expectRevert();
        _tokenStaker.unstakeErc20(ACCOUNT_A, _erc20Token, 100);
    }

    function test_UnstakeErc20When_ValidOwnerAccountAmount() public {
        vm.startPrank(_owners[0]);
        _erc20Token.approve(address(_tokenStaker), 100);
        _tokenStaker.stakeErc20(ACCOUNT_A, _erc20Token, 100);

        uint256 oldOwnerTokenBalance = _erc20Token.balanceOf(_owners[0]);
        uint256 oldContractTokenBalance = _erc20Token.balanceOf(address(_tokenStaker));

        _tokenStaker.unstakeErc20(ACCOUNT_A, _erc20Token, 100);

        uint256 stake = _tokenStaker.erc20StakeOf(_owners[0], _erc20Token, ACCOUNT_A);
        assertEq(stake, 0);

        uint256 newOwnerTokenBalance = _erc20Token.balanceOf(_owners[0]);
        assertEq(newOwnerTokenBalance - oldOwnerTokenBalance, 100);

        uint256 newContractTokenBalance = _erc20Token.balanceOf(address(_tokenStaker));
        assertEq(oldContractTokenBalance - newContractTokenBalance, 100);
    }

    function test_StakeErc721RevertWhen_InsufficientAllowance() public {
        vm.startPrank(_owners[0]);

        vm.expectRevert();
        _tokenStaker.stakeErc721(ACCOUNT_A, _erc721Token, 1);
    }

    function test_StakeErc721RevertWhen_InsufficientBalance() public {
        vm.startPrank(_owners[0]);
        _erc721Token.setApprovalForAll(address(_tokenStaker), true);

        vm.expectRevert();
        _tokenStaker.stakeErc721(ACCOUNT_A, _erc721Token, 3);
    }

    function test_StakerErc721When_ValidBalance() public {
        vm.startPrank(_owners[0]);

        uint256[] memory allTokensIds = new uint256[](0);
        uint256[] memory diffTokenId = new uint256[](1);
        diffTokenId[0] = 2;

        uint256 oldOwnerStake =
            _tokenStaker.erc721StakeOf(_owners[0], _erc721Token, allTokensIds, ACCOUNT_A);
        uint256 oldOwnerTokenBalance = _erc721Token.balanceOf(_owners[0]);
        uint256 oldContractTokenBalance = _erc721Token.balanceOf(address(_tokenStaker));

        _erc721Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc721(ACCOUNT_A, _erc721Token, 1);

        uint256 newOwnerStake =
            _tokenStaker.erc721StakeOf(_owners[0], _erc721Token, allTokensIds, ACCOUNT_A);
        assertEq(newOwnerStake - oldOwnerStake, 1);

        uint256 newOwnerTokenBalance = _erc721Token.balanceOf(_owners[0]);
        assertEq(oldOwnerTokenBalance - newOwnerTokenBalance, 1);

        uint256 newContractTokenBalance = _erc721Token.balanceOf(address(_tokenStaker));
        assertEq(newContractTokenBalance - oldContractTokenBalance, 1);
    }

    function test_UnstakeErc721RevertWhen_InvalidTokenId() public {
        vm.startPrank(_owners[0]);
        _erc721Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc721(ACCOUNT_A, _erc721Token, 1);

        vm.expectRevert();
        _tokenStaker.unstakeErc721(ACCOUNT_A, _erc721Token, 2);
    }

    function test_UnstakeErc721RevertWhen_InvalidAccount() public {
        vm.startPrank(_owners[0]);
        _erc721Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc721(ACCOUNT_A, _erc721Token, 1);

        vm.expectRevert();
        _tokenStaker.unstakeErc721(ACCOUNT_B, _erc721Token, 1);
    }

    function test_UnstakeErc721RevertWhen_InvalidOwner() public {
        vm.startPrank(_owners[0]);
        _erc721Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc721(ACCOUNT_A, _erc721Token, 1);

        vm.startPrank(_owners[1]);
        vm.expectRevert();
        _tokenStaker.unstakeErc721(ACCOUNT_A, _erc721Token, 1);
    }

    function test_UnstakeErc721When_ValidOwnerAccountAmount() public {
        vm.startPrank(_owners[0]);
        _erc721Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc721(ACCOUNT_A, _erc721Token, 1);

        uint256 oldOwnerTokenBalance = _erc721Token.balanceOf(_owners[0]);
        uint256 oldContractTokenBalance = _erc721Token.balanceOf(address(_tokenStaker));

        _tokenStaker.unstakeErc721(ACCOUNT_A, _erc721Token, 1);

        uint256[] memory allTokensIds = new uint256[](0);
        uint256 stake =
            _tokenStaker.erc721StakeOf(_owners[0], _erc721Token, allTokensIds, ACCOUNT_A);
        assertEq(stake, 0);

        uint256 newOwnerTokenBalance = _erc721Token.balanceOf(_owners[0]);
        assertEq(newOwnerTokenBalance - oldOwnerTokenBalance, 1);

        uint256 newContractTokenBalance = _erc721Token.balanceOf(address(_tokenStaker));
        assertEq(oldContractTokenBalance - newContractTokenBalance, 1);
    }

    function test_StakeErc1155RevertWhen_InsufficientAllowance() public {
        vm.startPrank(_owners[0]);

        vm.expectRevert();
        _tokenStaker.stakeErc1155(ACCOUNT_A, _erc1155Token, 1, 10);
    }

    function test_StakeErc1155RevertWhen_InsufficientBalance() public {
        vm.startPrank(_owners[0]);
        _erc1155Token.setApprovalForAll(address(_tokenStaker), true);

        vm.expectRevert();
        _tokenStaker.stakeErc1155(ACCOUNT_A, _erc1155Token, 1, 100);
    }

    function test_StakerErc1155When_ValidBalance() public {
        vm.startPrank(_owners[0]);
        _erc1155Token.setApprovalForAll(address(_tokenStaker), true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256 oldOwnerStake =
            _tokenStaker.erc1155StakeOf(_owners[0], _erc1155Token, tokenIds, ACCOUNT_A);
        uint256 oldOwnerTokenBalance = _erc1155Token.balanceOf(_owners[0], 1);
        uint256 oldContractTokenBalance = _erc1155Token.balanceOf(address(_tokenStaker), 1);

        _tokenStaker.stakeErc1155(ACCOUNT_A, _erc1155Token, 1, 10);

        uint256 newOwnerStake =
            _tokenStaker.erc1155StakeOf(_owners[0], _erc1155Token, tokenIds, ACCOUNT_A);
        assertEq(newOwnerStake - oldOwnerStake, 10);

        uint256 newOwnerTokenBalance = _erc1155Token.balanceOf(_owners[0], 1);
        assertEq(oldOwnerTokenBalance - newOwnerTokenBalance, 10);

        uint256 newContractTokenBalance = _erc1155Token.balanceOf(address(_tokenStaker), 1);
        assertEq(newContractTokenBalance - oldContractTokenBalance, 10);
    }

    function test_UnstakeErc1155RevertWhen_InvalidTokenId() public {
        vm.startPrank(_owners[0]);
        _erc1155Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc1155(ACCOUNT_A, _erc1155Token, 1, 10);

        vm.expectRevert();
        _tokenStaker.unstakeErc1155(ACCOUNT_A, _erc1155Token, 2, 10);
    }

    function test_UnstakeErc1155RevertWhen_InvalidAccount() public {
        vm.startPrank(_owners[0]);
        _erc1155Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc1155(ACCOUNT_A, _erc1155Token, 1, 10);

        vm.expectRevert();
        _tokenStaker.unstakeErc1155(ACCOUNT_B, _erc1155Token, 1, 10);
    }

    function test_UnstakeErc1155RevertWhen_InvalidOwner() public {
        vm.startPrank(_owners[0]);
        _erc1155Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc1155(ACCOUNT_A, _erc1155Token, 1, 10);

        vm.startPrank(_owners[1]);
        vm.expectRevert();
        _tokenStaker.unstakeErc1155(ACCOUNT_A, _erc1155Token, 1, 10);
    }

    function test_UnstakeErc1155When_ValidOwnerAccountAmount() public {
        vm.startPrank(_owners[0]);
        _erc1155Token.setApprovalForAll(address(_tokenStaker), true);
        _tokenStaker.stakeErc1155(ACCOUNT_A, _erc1155Token, 1, 10);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256 oldOwnerTokenBalance = _erc1155Token.balanceOf(_owners[0], 1);
        uint256 oldContractTokenBalance = _erc1155Token.balanceOf(address(_tokenStaker), 1);

        _tokenStaker.unstakeErc1155(ACCOUNT_A, _erc1155Token, 1, 10);

        uint256 stake = _tokenStaker.erc1155StakeOf(_owners[0], _erc1155Token, tokenIds, ACCOUNT_A);
        assertEq(stake, 0);

        uint256 newOwnerTokenBalance = _erc1155Token.balanceOf(_owners[0], 1);
        assertEq(newOwnerTokenBalance - oldOwnerTokenBalance, 10);

        uint256 newContractTokenBalance = _erc1155Token.balanceOf(address(_tokenStaker), 1);
        assertEq(oldContractTokenBalance - newContractTokenBalance, 10);
    }
}
