// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IENSBaseRegistrar {
    function ownerOf(uint256 tokenId) external view returns (address);
    function nameExpires(uint256 id) external view returns (uint256);
}
