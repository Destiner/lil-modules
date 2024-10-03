// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { IERC7579Module } from "modulekit/external/ERC7579.sol";

import {
    TokenStaker,
    TokenValidator,
    TGAConfig,
    TokenType,
    ERC7579ValidatorBase
} from "src/TokenValidator/TokenValidator.sol";
import {
    PackedUserOperation,
    getEmptyUserOperation,
    parseValidationData,
    ValidationData
} from "test/utils/ERC4337.sol";
import { EIP1271_MAGIC_VALUE } from "test/utils/Constants.sol";
import { MockTokenStaker } from "test/mocks/MockTokenStaker.sol";
import { signHash } from "test/utils/Signature.sol";

contract TokenValidatorTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    MockTokenStaker internal _tokenStaker;
    TokenValidator internal validator;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address _token = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
    // address _validSigner1 = 0x0101010101010101010101010101010101010101;
    // address _validSigner2 = 0x0202020202020202020202020202020202020202;
    // address _invalidSigner1 = 0xf1f1f1F1f1f1F1F1f1F1f1F1F1F1F1f1F1f1f1F1;
    address[] _signers;
    uint256[] _signerPks;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public {
        _signers = new address[](2);
        _signerPks = new uint256[](2);

        (address _signer1, uint256 _signer1Pk) = makeAddrAndKey("validSigner1");
        _signers[0] = _signer1;
        _signerPks[0] = _signer1Pk;
        (address _signer2, uint256 _signer2Pk) = makeAddrAndKey("validSigner2");
        _signers[1] = _signer2;
        _signerPks[1] = _signer2Pk;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        _tokenStaker = new MockTokenStaker(_signers, amounts);
        validator = new TokenValidator(TokenStaker(address(_tokenStaker)));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getConfig() internal returns (TGAConfig memory config) {
        config = _getConfig(_token);
    }

    function _getConfig(address _tokenAddress) internal returns (TGAConfig memory config) {
        config = _getConfig(_tokenAddress, 1);
    }

    function _getConfig(
        address _tokenAddress,
        uint256 _minAmount
    )
        internal
        returns (TGAConfig memory config)
    {
        config = _getConfig(_tokenAddress, _minAmount, 1);
    }

    function _getConfig(
        address _tokenAddress,
        uint256 _minAmount,
        uint256 _signerThreshold
    )
        internal
        returns (TGAConfig memory config)
    {
        uint256[] memory validTokenIds = new uint256[](0);
        config = TGAConfig({
            tokenType: TokenType.ERC20,
            tokenAddress: _tokenAddress,
            minAmount: _minAmount,
            validTokenIds: validTokenIds,
            signerThreshold: _signerThreshold
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        TGAConfig memory config = _getConfig();
        bytes memory data = abi.encode(config);
        validator.onInstall(data);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_ModuleTokenAddressIsNull()
        public
        whenModuleIsNotInitialized
    {
        // it should revert
        TGAConfig memory config = _getConfig(address(0));
        bytes memory data = abi.encode(config);

        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidTokenAddress.selector));
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_MinAmountIsZero()
        public
        whenModuleIsNotInitialized
        whenTokenAddressIsNotNull
    {
        // it should revert
        TGAConfig memory config = _getConfig(_token, 0);
        bytes memory data = abi.encode(config);

        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidMinAmount.selector));
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_SignerThresholdIsZero()
        public
        whenModuleIsNotInitialized
        whenTokenAddressIsNotNull
        whenMinAmountIsNot0
    {
        // it should revert
        TGAConfig memory config = _getConfig(_token, 150, 0);
        bytes memory data = abi.encode(config);

        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidSignerThreshold.selector));
        validator.onInstall(data);
    }

    function test_OnInstallWhen_ValidConfig()
        public
        whenModuleIsNotInitialized
        whenTokenAddressIsNotNull
        whenMinAmountIsNot0
        whenSignerThresholdIsNot0
    {
        // it should revert
        TGAConfig memory config = _getConfig(_token, 150, 1);
        bytes memory data = abi.encode(config);

        validator.onInstall(data);
    }

    function test_ValidateUserOpWhenUninitialized() public {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenSignaturesAreNotValid() public whenModuleIsInitialized {
        test_OnInstallWhen_ValidConfig();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(uint256(1), userOpHash);
        bytes memory signature2 = signHash(uint256(2), userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenSignersNotStakedEnough()
        public
        whenModuleIsInitialized
        whenSignaturesAreValid
    {
        test_OnInstallWhen_ValidConfig();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_signerPks[0], userOpHash);
        userOp.signature = abi.encodePacked(signature1);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenSignersStakedEnough()
        public
        whenModuleIsInitialized
        whenSignaturesAreValid
        whenSignersStakedEnough
    {
        test_OnInstallWhen_ValidConfig();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_signerPks[1], userOpHash);
        userOp.signature = abi.encodePacked(signature1);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenModuleIsNotInitialized() {
        _;
    }

    modifier whenTokenAddressIsNotNull() {
        _;
    }

    modifier whenMinAmountIsNot0() {
        _;
    }

    modifier whenSignerThresholdIsNot0() {
        _;
    }

    modifier whenModuleIsInitialized() {
        _;
    }

    modifier whenSignaturesAreValid() {
        _;
    }

    modifier whenSignersStakedEnough() {
        _;
    }
}
