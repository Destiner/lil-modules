import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract TokenStaker {
    mapping(address owner => mapping(IERC20 token => mapping(address account => uint256 balance)))
        public erc20Stakes;
    mapping(
        address owner
            => mapping(
                IERC721 token => mapping(uint256 id => mapping(address account => uint256 balance))
            )
    ) public erc721Stakes;
    mapping(
        address owner
            => mapping(
                IERC1155 token => mapping(uint256 id => mapping(address account => uint256 balance))
            )
    ) public erc1155Stakes;

    error InvalidAccount();

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

    function stakeErc721(
        address account,
        IERC721 tokenAddress,
        uint256 id,
        uint256 amount
    )
        external
    {
        if (account == address(0)) {
            revert InvalidAccount();
        }

        tokenAddress.transferFrom(msg.sender, address(this), id);
        erc721Stakes[msg.sender][tokenAddress][id][account] += amount;
    }

    function unstakeErc721(
        address account,
        IERC721 tokenAddress,
        uint256 id,
        uint256 amount
    )
        external
    {
        erc721Stakes[msg.sender][tokenAddress][id][account] -= amount;
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
        tokenAddress.safeTransferFrom(address(this), msg.sender, id, amount, "");
    }
}
