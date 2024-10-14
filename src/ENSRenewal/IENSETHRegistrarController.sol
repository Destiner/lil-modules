// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IENSETHPriceOracle } from "./IENSETHPriceOracle.sol";

interface IENSETHRegistrarController {
    function renew(string calldata name, uint256 duration) external payable;
    function rentPrice(
        string memory name,
        uint256 duration
    )
        external
        view
        returns (IENSETHPriceOracle.Price memory price);
}
