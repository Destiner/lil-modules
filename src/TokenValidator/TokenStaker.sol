// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";

import { ITokenStaker } from "./ITokenStaker.sol";

contract TokenStaker is ITokenStaker {
    /*//////////////////////////////////////////////////////////////////////////
                                CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address owner => mapping(IERC20 token => mapping(address account => uint256 balance)))
        internal erc20Stakes;
    mapping(
        address owner
            => mapping(
                IERC721 token => mapping(uint256 id => mapping(address account => uint256 balance))
            )
    ) internal erc721Stakes;
    mapping(address owner => mapping(IERC721 token => mapping(address account => uint256 balance)))
        internal erc721CumulativeStakes;
    mapping(
        address owner
            => mapping(
                IERC1155 token => mapping(uint256 id => mapping(address account => uint256 balance))
            )
    ) internal erc1155Stakes;
    mapping(address owner => mapping(IERC1155 token => mapping(address account => uint256 balance)))
        internal erc1155CumulativeStakes;

    /*//////////////////////////////////////////////////////////////////////////
                                       ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidAccount();

    /*//////////////////////////////////////////////////////////////////////////
                                     EXTERNALS
    //////////////////////////////////////////////////////////////////////////*/

    function stakeErc20(address account, IERC20 tokenAddress, uint256 amount) external {
        if (account == address(0)) {
            revert InvalidAccount();
        }

        tokenAddress.transferFrom(msg.sender, address(this), amount);
        erc20Stakes[msg.sender][tokenAddress][account] += amount;
    }

    function unstakeErc20(address account, IERC20 tokenAddress, uint256 amount) external {
        erc20Stakes[msg.sender][tokenAddress][account] -= amount;
        tokenAddress.transfer(msg.sender, amount);
    }

    function stakeErc721(address account, IERC721 tokenAddress, uint256 id) external {
        if (account == address(0)) {
            revert InvalidAccount();
        }

        tokenAddress.transferFrom(msg.sender, address(this), id);
        erc721Stakes[msg.sender][tokenAddress][id][account] += 1;
        erc721CumulativeStakes[msg.sender][tokenAddress][account] += 1;
    }

    function unstakeErc721(address account, IERC721 tokenAddress, uint256 id) external {
        erc721Stakes[msg.sender][tokenAddress][id][account] -= 1;
        erc721CumulativeStakes[msg.sender][tokenAddress][account] -= 1;
        tokenAddress.transferFrom(address(this), msg.sender, id);
    }

    function stakeErc1155(
        address account,
        IERC1155 tokenAddress,
        uint256 id,
        uint256 amount
    )
        external
    {
        if (account == address(0)) {
            revert InvalidAccount();
        }

        tokenAddress.safeTransferFrom(msg.sender, address(this), id, amount, "");
        erc1155Stakes[msg.sender][tokenAddress][id][account] += amount;
        erc1155CumulativeStakes[msg.sender][tokenAddress][account] += amount;
    }

    function unstakeErc1155(
        address account,
        IERC1155 tokenAddress,
        uint256 id,
        uint256 amount
    )
        external
    {
        erc1155Stakes[msg.sender][tokenAddress][id][account] -= amount;
        erc1155CumulativeStakes[msg.sender][tokenAddress][account] -= amount;
        tokenAddress.safeTransferFrom(address(this), msg.sender, id, amount, "");
    }

    function erc20StakeOf(
        address owner,
        IERC20 tokenAddress,
        address account
    )
        external
        view
        returns (uint256)
    {
        return erc20Stakes[owner][tokenAddress][account];
    }

    function erc721StakeOf(
        address owner,
        IERC721 tokenAddress,
        uint256[] calldata validTokenIds,
        address account
    )
        external
        view
        returns (uint256)
    {
        uint256 balance;
        if (validTokenIds.length == 0) {
            return erc721CumulativeStakes[owner][tokenAddress][account];
        }
        for (uint256 i = 0; i < validTokenIds.length; i++) {
            balance += erc721Stakes[owner][tokenAddress][validTokenIds[i]][account];
        }
        return balance;
    }

    function erc1155StakeOf(
        address owner,
        IERC1155 tokenAddress,
        uint256[] calldata validTokenIds,
        address account
    )
        external
        view
        returns (uint256)
    {
        uint256 balance;
        if (validTokenIds.length == 0) {
            return erc1155CumulativeStakes[owner][tokenAddress][account];
        }
        for (uint256 i = 0; i < validTokenIds.length; i++) {
            balance += erc1155Stakes[owner][tokenAddress][validTokenIds[i]][account];
        }
        return balance;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        external
        pure
        returns (bytes4)
    {
        return
            bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        external
        pure
        returns (bytes4)
    {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }
}
