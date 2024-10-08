pragma solidity ^0.8.23;

import { ERC1155 } from "solady/tokens/ERC1155.sol";

contract MintableERC1155 is ERC1155 {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external {
        _mint(to, id, amount, data);
    }
}
