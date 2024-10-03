// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";

import { TokenStaker } from "src/TokenValidator/TokenStaker.sol";
import { MintableERC20 } from "test/utils/MintableERC20.sol";

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

    address _account;
    IERC20 _erc20Token;
    IERC721 _erc721Token;
    IERC1155 _erc1155Token;
    address[] _owners;
    uint256[] _ownerPks;

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

    // TODO ERC721 and ERC1155 tests
}
