// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IENSETHRegistrarController } from "src/ENSRenewal/IENSETHRegistrarController.sol";
import { IENSETHPriceOracle } from "src/ENSRenewal/IENSETHPriceOracle.sol";
import { IENSBaseRegistrar } from "src/ENSRenewal/IENSBaseRegistrar.sol";

import { MockENSBaseRegistrar } from "./MockENSBaseRegistrar.sol";

contract MockENSETHRegistrarController is IENSETHRegistrarController {
    error NotEnoughFunds();
    error UnableToReimburse();
    error InvalidBaseRegistrar();

    uint256 internal yearlyPrice;
    MockENSBaseRegistrar internal baseRegistrar;

    constructor(uint256 _yearlyPrice) {
        yearlyPrice = _yearlyPrice;
    }

    function setBaseRegistrar(MockENSBaseRegistrar _baseRegistrar) external {
        baseRegistrar = _baseRegistrar;
    }

    function rentPrice(
        string memory name,
        uint256 duration
    )
        external
        view
        returns (IENSETHPriceOracle.Price memory price)
    {
        return _rentPrice(name, duration);
    }

    function renew(string calldata name, uint256 duration) external payable {
        IENSETHPriceOracle.Price memory price = _rentPrice(name, duration);
        uint256 priceValue = price.base + price.premium;

        require(msg.value >= priceValue, NotEnoughFunds());

        uint256 id = _getId(name);
        baseRegistrar.extend(id, duration);

        // Reimburse the excess funds
        (bool sent,) = payable(msg.sender).call{ value: msg.value - priceValue }("");
        require(sent, UnableToReimburse());
    }

    function _rentPrice(
        string memory name,
        uint256 duration
    )
        internal
        view
        returns (IENSETHPriceOracle.Price memory price)
    {
        uint256 base = yearlyPrice * duration / 365 days;
        uint256 premium = 0;
        price = IENSETHPriceOracle.Price(base, premium);
    }

    function _getId(string memory name) internal pure returns (uint256) {
        return uint256(keccak256(bytes(name)));
    }
}
