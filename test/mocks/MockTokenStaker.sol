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

    function erc20Stakes(
        address owner,
        IERC20 token,
        address account
    )
        external
        view
        returns (uint256)
    {
        return _getAmount(owner);
    }

    function erc721Stakes(
        address owner,
        IERC721 token,
        uint256 id,
        address account
    )
        external
        view
        returns (uint256)
    {
        return _getAmount(owner);
    }

    function erc721CumulativeStakes(
        address owner,
        IERC721 token,
        address account
    )
        external
        view
        returns (uint256)
    {
        return _getAmount(owner);
    }

    function erc1155Stakes(
        address owner,
        IERC1155 token,
        uint256 id,
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
