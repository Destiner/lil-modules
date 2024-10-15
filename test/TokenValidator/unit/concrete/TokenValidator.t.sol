// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { IERC7579Module } from "modulekit/external/ERC7579.sol";
import { FlatBytesLib } from "flatbytes/BytesLib.sol";

import {
    InstallData,
    TokenValidator,
    TokenType,
    ERC7579ValidatorBase
} from "src/TokenValidator/TokenValidator.sol";
import { PackedUserOperation, getEmptyUserOperation } from "test/utils/ERC4337.sol";
import { MockTokenStaker } from "test/TokenValidator/mocks/MockTokenStaker.sol";
import { signHash } from "test/utils/Signature.sol";

contract TokenValidatorTest is Test {
    using FlatBytesLib for FlatBytesLib.Bytes;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    MockTokenStaker internal _tokenStaker;
    TokenValidator internal validator;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address _token = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
    address[] _signers;
    uint256[] _signerPks;
    FlatBytesLib.Bytes validTokenIds;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public {
        _signers = new address[](2);
        _signerPks = new uint256[](2);

        (address _signer1, uint256 _signer1Pk) = makeAddrAndKey("signer1");
        _signers[0] = _signer1;
        _signerPks[0] = _signer1Pk;
        (address _signer2, uint256 _signer2Pk) = makeAddrAndKey("signer2");
        _signers[1] = _signer2;
        _signerPks[1] = _signer2Pk;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        _tokenStaker = new MockTokenStaker(_signers, amounts);
        validator = new TokenValidator(_tokenStaker);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getInstallData() internal returns (InstallData memory data) {
        data = _getInstallData(_token);
    }

    function _getInstallData(address _tokenAddress) internal returns (InstallData memory data) {
        data = _getInstallData(_tokenAddress, 100);
    }

    function _getInstallData(
        address _tokenAddress,
        uint256 _minAmount
    )
        internal
        returns (InstallData memory data)
    {
        data = _getInstallData(_tokenAddress, _minAmount, 2);
    }

    function _getInstallData(
        address _tokenAddress,
        uint256 _minAmount,
        uint256 _signerThreshold
    )
        internal
        returns (InstallData memory data)
    {
        uint256[] memory validTokenIds = new uint256[](0);
        data = _getInstallData(_tokenAddress, _minAmount, _signerThreshold, validTokenIds);
    }

    function _getInstallData(
        address _tokenAddress,
        uint256 _minAmount,
        uint256 _signerThreshold,
        uint256[] memory _validTokenIds
    )
        internal
        returns (InstallData memory data)
    {
        // bytes memory data = abi.encode(_validTokenIds);
        // validTokenIds.store(data);
        data = InstallData({
            tokenType: TokenType.ERC20,
            tokenAddress: _tokenAddress,
            minAmount: _minAmount,
            signerThreshold: _signerThreshold,
            validTokenIds: _validTokenIds
        });
    }

    function _installWithData(InstallData memory data) internal {
        bytes memory dataBytes = abi.encode(data);
        validator.onInstall(dataBytes);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        InstallData memory data = _getInstallData();
        bytes memory dataBytes = abi.encode(data);
        validator.onInstall(dataBytes);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        validator.onInstall(dataBytes);
    }

    function test_OnInstallRevertWhen_ModuleTokenAddressIsNull()
        public
        whenModuleIsNotInitialized
    {
        // it should revert
        InstallData memory data = _getInstallData(address(0));
        bytes memory dataBytes = abi.encode(data);

        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidTokenAddress.selector));
        validator.onInstall(dataBytes);
    }

    function test_OnInstallRevertWhen_MinAmountIsZero()
        public
        whenModuleIsNotInitialized
        whenTokenAddressIsNotNull
    {
        // it should revert
        InstallData memory data = _getInstallData(_token, 0);
        bytes memory dataBytes = abi.encode(data);

        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidMinAmount.selector));
        validator.onInstall(dataBytes);
    }

    function test_OnInstallRevertWhen_SignerThresholdIsZero()
        public
        whenModuleIsNotInitialized
        whenTokenAddressIsNotNull
        whenMinAmountIsNot0
    {
        // it should revert
        InstallData memory data = _getInstallData(_token, 100, 0);
        bytes memory dataBytes = abi.encode(data);

        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidSignerThreshold.selector));
        validator.onInstall(dataBytes);
    }

    function test_OnInstallRevertWhen_TokenIdsSetForErc20()
        public
        whenModuleIsNotInitialized
        whenTokenAddressIsNotNull
        whenMinAmountIsNot0
        whenSignerThresholdIsNot0
    {
        // it should revert
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        InstallData memory data = _getInstallData(_token, 100, 2, tokenIds);
        bytes memory dataBytes = abi.encode(data);

        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidTokenIds.selector));
        validator.onInstall(dataBytes);
    }

    function test_OnInstallWhen_ValidConfig()
        public
        whenModuleIsNotInitialized
        whenTokenAddressIsNotNull
        whenMinAmountIsNot0
        whenSignerThresholdIsNot0
        whenTokenIdsSetProperly
    {
        // it should revert
        InstallData memory data = _getInstallData(_token, 100, 2);
        _installWithData(data);
    }

    function test_SetMinAmountRevertWhen_NotInitialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        validator.setMinAmount(100);
    }

    function test_SetMinAmountRevertWhen_MinAmountIsZero() public whenModuleIsInitialized {
        test_OnInstallWhen_ValidConfig();

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidMinAmount.selector));
        validator.setMinAmount(0);
    }

    function test_SetMinAmountWhen_ValidAmount() public whenModuleIsInitialized {
        test_OnInstallWhen_ValidConfig();

        validator.setMinAmount(200);
    }

    function test_SetSignerThresholdRevertWhen_NotInitialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        validator.setMinAmount(100);
    }

    function test_SetSignerThresholdRevertWhen_SignerThresholdIsZero()
        public
        whenModuleIsInitialized
    {
        test_OnInstallWhen_ValidConfig();

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(TokenValidator.InvalidSignerThreshold.selector));
        validator.setSignerThreshold(0);
    }

    function test_SetSignerThresholdWhen_ValidAmount() public whenModuleIsInitialized {
        test_OnInstallWhen_ValidConfig();

        validator.setSignerThreshold(1);
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

    function test_ValidateUserOpWhenSignersDoNotPassThreshold()
        public
        whenModuleIsInitialized
        whenSignaturesAreValid
    {
        test_OnInstallWhen_ValidConfig();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_signerPks[0], userOpHash);
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
        whenAboveSignerThreshold
    {
        InstallData memory data = _getInstallData();
        data.minAmount = 150;
        _installWithData(data);

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_signerPks[0], userOpHash);
        bytes memory signature2 = signHash(_signerPks[1], userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenSignersStakedEnough()
        public
        whenModuleIsInitialized
        whenSignaturesAreValid
        whenAboveSignerThreshold
        whenSignersStakedEnough
    {
        test_OnInstallWhen_ValidConfig();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_signerPks[0], userOpHash);
        bytes memory signature2 = signHash(_signerPks[1], userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

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

    modifier whenTokenIdsSetProperly() {
        _;
    }

    modifier whenModuleIsInitialized() {
        _;
    }

    modifier whenSignaturesAreValid() {
        _;
    }

    modifier whenAboveSignerThreshold() {
        _;
    }

    modifier whenSignersStakedEnough() {
        _;
    }
}
