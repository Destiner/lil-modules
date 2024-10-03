// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

enum TokenType {
    ERC20,
    ERC721
}

// TGA Configuration
struct TGAConfig {
    TokenType tokenType;
    address tokenAddress;
    uint256 minAmount; // minimum amount of tokens to be valid
    uint256[] validTokenIds; // valid token IDs; empty array means all IDs are valid
    uint256 signerThreshold; // minimum number of signer to be valid
}
