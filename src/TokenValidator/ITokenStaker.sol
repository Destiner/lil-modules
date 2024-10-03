// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";

interface ITokenStaker {
    function stakeErc20(address account, IERC20 tokenAddress, uint256 amount) external;
    function unstakeErc20(address account, IERC20 tokenAddress, uint256 amount) external;
    function stakeErc721(address account, IERC721 tokenAddress, uint256 id) external;
    function unstakeErc721(address account, IERC721 tokenAddress, uint256 id) external;
    function stakeErc1155(
        address account,
        IERC1155 tokenAddress,
        uint256 id,
        uint256 amount
    )
        external;

    function unstakeErc1155(
        address account,
        IERC1155 tokenAddress,
        uint256 id,
        uint256 amount
    )
        external;

    function erc20StakeOf(
        address owner,
        IERC20 tokenAddress,
        address account
    )
        external
        view
        returns (uint256);
    function erc721StakeOf(
        address owner,
        IERC721 tokenAddress,
        uint256[] calldata validTokenIds,
        address account
    )
        external
        view
        returns (uint256);
    function erc1155StakeOf(
        address owner,
        IERC1155 tokenAddress,
        uint256[] calldata validTokenIds,
        address account
    )
        external
        view
        returns (uint256);

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        external
        pure
        returns (bytes4);
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        external
        pure
        returns (bytes4);
}
