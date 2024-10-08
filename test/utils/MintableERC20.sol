// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC20 } from "solady/tokens/ERC20.sol";

contract MintableERC20 is ERC20 {
    string internal _name;
    string internal _symbol;
    address public owner;

    constructor(string memory name, string memory symbol) {
        _name = name;
        _symbol = symbol;
        owner = msg.sender;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
