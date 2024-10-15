// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { FlatBytesLib } from "flatbytes/BytesLib.sol";

enum TokenType {
    ERC20,
    ERC721,
    ERC1155
}

struct InstallData {
    TokenType tokenType;
    address tokenAddress;
    uint256 minAmount; // minimum amount of tokens to be valid
    uint256 signerThreshold; // minimum number of signer to be valid
    uint256[] validTokenIds; // valid token IDs; empty array means all IDs are valid
}

// TGA Configuration
struct TGAConfig {
    TokenType tokenType;
    address tokenAddress;
    uint256 minAmount; // minimum amount of tokens to be valid
    uint256 signerThreshold; // minimum number of signer to be valid
    FlatBytesLib.Bytes validTokenIds; // valid token IDs; empty array means all IDs are valid
}
