// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IENSETHPriceOracle {
    struct Price {
        uint256 base;
        uint256 premium;
    }
}
