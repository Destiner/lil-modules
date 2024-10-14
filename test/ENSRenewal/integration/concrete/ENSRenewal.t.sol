// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";

import { InstallData } from "src/ENSRenewal/DataTypes.sol";
import { ENSRenewal } from "src/ENSRenewal/ENSRenewal.sol";
import { MockENSBaseRegistrar } from "test/ENSRenewal/mocks/MockENSBaseRegistrar.sol";
import { MockENSETHRegistrarController } from
    "test/ENSRenewal/mocks/MockENSETHRegistrarController.sol";

contract ENSRenewalTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    // account and modules
    AccountInstance internal instance;
    ENSRenewal internal executor;

    // mocks
    MockENSBaseRegistrar internal ensBaseRegistrar;
    MockENSETHRegistrarController internal ensETHRegistrarController;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public {
        init();

        // Create the install data
        InstallData memory installData;
        installData.threshold = 7 days;
        installData.renewalDuration = 365 days;
        installData.allowlist = new string[](0);
        installData.denylist = new string[](0);

        bytes memory data = abi.encode(installData);

        // Create the account
        instance = makeAccountInstance("Account");
        vm.deal(address(instance.account), 10 ether);

        // Create the mocks
        uint256 yearlyPrice = 1 ether;
        ensETHRegistrarController = new MockENSETHRegistrarController(yearlyPrice);
        string[] memory ensNames = new string[](3);
        ensNames[0] = "alice";
        ensNames[1] = "bob";
        ensNames[2] = "charlie";
        uint256[] memory ensIds = new uint256[](3);
        ensIds[0] = _getNameId(ensNames[0]);
        ensIds[1] = _getNameId(ensNames[1]);
        ensIds[2] = _getNameId(ensNames[2]);
        address[] memory ensOwners = new address[](3);
        ensOwners[0] = instance.account;
        ensOwners[1] = instance.account;
        ensOwners[2] = instance.account;
        uint256[] memory ensInitialExpirations = new uint256[](3);
        ensInitialExpirations[0] = block.timestamp + 1 days;
        ensInitialExpirations[1] = block.timestamp + 2 days;
        ensInitialExpirations[2] = block.timestamp + 3 days;
        ensBaseRegistrar = new MockENSBaseRegistrar(
            ensETHRegistrarController, ensIds, ensOwners, ensInitialExpirations
        );
        ensETHRegistrarController.setBaseRegistrar(ensBaseRegistrar);

        // Create the executor
        executor = new ENSRenewal(ensBaseRegistrar, ensETHRegistrarController);
        vm.label(address(executor), "ENSRenewal");

        // Install the executor
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: data
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_Renew() public {
        uint256 initialBalance = address(instance.account).balance;

        string[] memory ensNamesToRenew = new string[](2);
        ensNamesToRenew[0] = "alice";
        ensNamesToRenew[1] = "bob";
        executor.renewMany(instance.account, ensNamesToRenew);

        // Check the balance
        uint256 newBalance = address(instance.account).balance;
        // Can't tell the exact amount because of the gas fees
        assertLe(2 ether, initialBalance - newBalance);
        assertGe(3 ether, initialBalance - newBalance);

        // Check the expirations
        assertEq(
            block.timestamp + 1 days + 365 days, ensBaseRegistrar.nameExpires(_getNameId("alice"))
        );
        assertEq(
            block.timestamp + 2 days + 365 days, ensBaseRegistrar.nameExpires(_getNameId("bob"))
        );
        // Domain should not have been renewed
        assertEq(block.timestamp + 3 days, ensBaseRegistrar.nameExpires(_getNameId("charlie")));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getNameId(string memory name) internal pure returns (uint256) {
        return uint256(keccak256(bytes(name)));
    }
}
