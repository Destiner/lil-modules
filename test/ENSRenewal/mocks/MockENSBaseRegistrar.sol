// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IENSBaseRegistrar } from "src/ENSRenewal/IENSBaseRegistrar.sol";
import { IENSETHRegistrarController } from "src/ENSRenewal/IENSETHRegistrarController.sol";

contract MockENSBaseRegistrar is IENSBaseRegistrar {
    error InvalidOwnerLength();
    error InvalidExpirationLength();
    error InvalidController();

    IENSETHRegistrarController internal controller;

    mapping(uint256 id => address owner) internal owners;
    mapping(uint256 id => uint256 expiration) internal expirations;

    constructor(
        IENSETHRegistrarController _controller,
        uint256[] memory _ids,
        address[] memory _owners,
        uint256[] memory _initialExpirations
    ) {
        require(_ids.length == _owners.length, InvalidOwnerLength());
        require(_ids.length == _initialExpirations.length, InvalidExpirationLength());

        controller = _controller;

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            owners[id] = _owners[i];
            expirations[id] = _initialExpirations[i];
        }
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return owners[tokenId];
    }

    function nameExpires(uint256 id) external view returns (uint256) {
        return expirations[id];
    }

    function extend(uint256 id, uint256 duration) external {
        require(msg.sender == address(controller), InvalidController());
        expirations[id] += duration;
    }
}
