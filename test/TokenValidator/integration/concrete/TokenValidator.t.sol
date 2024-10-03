// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

import { TokenValidator } from "src/TokenValidator/TokenValidator.sol";
import { TokenStaker } from "src/TokenValidator/TokenStaker.sol";
import { TokenType, TGAConfig } from "src/TokenValidator/DataTypes.sol";
import { signHash } from "test/utils/Signature.sol";
import { MintableERC20 } from "test/utils/MintableERC20.sol";

contract TokenValidatorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    // account and modules
    AccountInstance internal instance;
    TokenValidator internal validator;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    MintableERC20 internal usdc;
    address[] _signers;
    uint256[] _signerPks;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public {
        init();

        // Create the token staker
        TokenStaker tokenStaker = new TokenStaker();

        // Create the signers
        _signers = new address[](1);
        _signerPks = new uint256[](1);
        (address _signer1, uint256 _signer1Pk) = makeAddrAndKey("signer1");
        _signers[0] = _signer1;
        _signerPks[0] = _signer1Pk;

        // Create the token
        usdc = new MintableERC20("USDC", "USD Coin");
        vm.label(address(usdc), "USDC");
        usdc.mint(_signers[0], 1_000_000);

        // Create the config
        TGAConfig memory config;
        config.tokenType = TokenType.ERC20;
        config.tokenAddress = address(usdc);
        config.minAmount = 1;
        config.validTokenIds = new uint256[](0);
        config.signerThreshold = 1;

        bytes memory data = abi.encode(config);

        // Create the validator
        validator = new TokenValidator(tokenStaker);
        vm.label(address(validator), "TokenValidator");

        // Create the account and install the validator
        instance = makeAccountInstance("TokenValidator");
        vm.deal(address(instance.account), 10 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: data
        });

        // Stake the token
        vm.startPrank(_signers[0]);
        usdc.approve(address(tokenStaker), 100_000);
        tokenStaker.stakeErc20(instance.account, IERC20(address(usdc)), 100_000);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_ValidateUserOp() public {
        // it should validate the user op
        address target = makeAddr("target");

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: 1,
            callData: "",
            txValidator: address(validator)
        });
        bytes memory signature1 = signHash(_signerPks[0], userOpData.userOpHash);
        userOpData.userOp.signature = abi.encodePacked(signature1);
        userOpData.execUserOps();

        assertEq(target.balance, 1);
    }
}
