// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";

contract MockTokenStaker {
    address[] internal _addresses;
    uint256[] internal _amounts;

    constructor(address[] memory addresses, uint256[] memory amounts) {
        _addresses = addresses;
        _amounts = amounts;
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
        return _getAmount(owner);
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
        return _getAmount(owner);
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
        return _getAmount(owner);
    }

    function _getAmount(address a) internal view returns (uint256 amount) {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (_addresses[i] == a) {
                return _amounts[i];
            }
        }
        return 0;
    }
}
