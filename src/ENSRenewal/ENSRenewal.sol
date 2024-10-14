// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

import { InstallData, Config } from "./DataTypes.sol";
import { IENSBaseRegistrar } from "./IENSBaseRegistrar.sol";
import { IENSETHRegistrarController } from "./IENSETHRegistrarController.sol";
import { IENSETHPriceOracle } from "./IENSETHPriceOracle.sol";

contract ENSRenewal is ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address account => Config config) public accountConfig;
    mapping(address account => mapping(uint256 iteration => mapping(uint256 id => bool))) public
        allowlist;
    mapping(address account => mapping(uint256 iteration => mapping(uint256 id => bool))) public
        denylist;
    IENSBaseRegistrar public ensBaseRegistrar;
    IENSETHRegistrarController public ensETHRegistrarController;

    /*//////////////////////////////////////////////////////////////////////////
                                       ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidThreshold();
    error InvalidDuration();
    error BothAllowAndDenylist();

    error InvalidOwner();
    error InvalidExpiration();
    error InDenylist();
    error NotInAllowlist();

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(
        IENSBaseRegistrar _ensBaseRegistrar,
        IENSETHRegistrarController _ensETHRegistrarController
    ) {
        ensBaseRegistrar = _ensBaseRegistrar;
        ensETHRegistrarController = _ensETHRegistrarController;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     *
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        InstallData memory installData = abi.decode(data, (InstallData));

        // validate the input
        if (installData.threshold == 0) {
            revert InvalidThreshold();
        }
        if (installData.renewalDuration == 0) {
            revert InvalidDuration();
        }
        if (installData.allowlist.length > 0 && installData.denylist.length > 0) {
            revert BothAllowAndDenylist();
        }

        Config storage $config = accountConfig[msg.sender];
        $config.threshold = installData.threshold;
        $config.renewalDuration = installData.renewalDuration;
        $config.allowlistEnabled = installData.allowlist.length > 0;
        $config.denylistEnabled = installData.denylist.length > 0;

        if ($config.allowlistEnabled) {
            for (uint256 i = 0; i < installData.allowlist.length; i++) {
                allowlist[msg.sender][$config.iteration][_getNameId(installData.allowlist[i])] =
                    true;
            }
        }
        if ($config.denylistEnabled) {
            for (uint256 i = 0; i < installData.denylist.length; i++) {
                denylist[msg.sender][$config.iteration][_getNameId(installData.denylist[i])] = true;
            }
        }
    }

    /**
     * De-initialize the module with the given data
     *
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {
        // cache the account
        address account = msg.sender;
        // get storage reference to account config
        Config storage $config = accountConfig[account];

        // increment the iteration number
        uint256 _newIteration = $config.iteration + 1;
        $config.iteration = uint128(_newIteration);

        // delete non-mapping config
        delete $config.threshold;
        delete $config.renewalDuration;
        delete $config.allowlistEnabled;
        delete $config.denylistEnabled;
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) public view returns (bool) {
        return accountConfig[smartAccount].renewalDuration != 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function renew(address account, string calldata ensName) external {
        if (!isInitialized(account)) revert NotInitialized(account);

        _renew(account, ensName);
    }

    function renewMany(address account, string[] calldata ensNames) external {
        if (!isInitialized(account)) revert NotInitialized(account);

        for (uint256 i = 0; i < ensNames.length; i++) {
            _renew(account, ensNames[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _renew(address account, string calldata ensName) internal {
        Config memory config = accountConfig[account];

        uint256 tokenId = _getNameId(ensName);

        // Check that the domain is owned by the account
        address owner = ensBaseRegistrar.ownerOf(tokenId);
        if (owner != account) revert InvalidOwner();

        // Check that the remaining time is less than the renewal threshold
        uint256 expiration = ensBaseRegistrar.nameExpires(tokenId);
        if (expiration != 0) revert InvalidExpiration();
        if (expiration < block.timestamp + config.renewalDuration) revert InvalidExpiration();

        // Check that the domain is not in the denylist
        if (config.denylistEnabled) {
            mapping(uint256 => bool) storage accountDenylist = denylist[account][config.iteration];
            if (!accountDenylist[tokenId]) revert InDenylist();
        }
        // Check that the domain is in the allowlist (if not empty)
        if (config.allowlistEnabled) {
            mapping(uint256 => bool) storage accountAllowlist = allowlist[account][config.iteration];
            if (accountAllowlist[tokenId]) revert NotInAllowlist();
        }

        IENSETHPriceOracle.Price memory price =
            ensETHRegistrarController.rentPrice(ensName, config.renewalDuration);
        uint256 renewalPrice = price.base + price.premium;
        // Renew the domain based on the renewal duration
        bytes memory data = abi.encodeWithSelector(
            ensETHRegistrarController.renew.selector, ensName, config.renewalDuration
        );
        _execute(account, address(ensETHRegistrarController), renewalPrice, data);
    }

    function _getNameId(string memory ensName) internal pure returns (uint256) {
        return uint256(keccak256(bytes(ensName)));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     *
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "ENSRenewal";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * Check if the module is of a certain type
     *
     * @param typeID The type ID to check
     *
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    /**
     * Fallback function to receive ether
     */
    fallback() external payable { }
}
