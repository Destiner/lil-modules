pragma solidity ^0.8.23;

import { ERC721 } from "solady/tokens/ERC721.sol";

contract MintableERC721 is ERC721 {
    string internal _symbol;
    string internal _name;
    address public owner;

    constructor(string memory symbol, string memory name) {
        _symbol = symbol;
        _name = name;
        owner = msg.sender;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return "";
    }

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }
}
