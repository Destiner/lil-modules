// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { CheckSignatures } from "checknsignatures/CheckNSignatures.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { LibSort } from "solady/utils/LibSort.sol";

import { TokenType, TGAConfig } from "./DataTypes.sol";
import { ITokenStaker } from "./ITokenStaker.sol";

contract TokenValidator is ERC7579ValidatorBase {
    using LibSort for *;

    /*//////////////////////////////////////////////////////////////////////////
                                CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    ITokenStaker public immutable TOKEN_STAKER;
    // account => TGAConfig
    mapping(address account => TGAConfig config) public accountConfig;

    /*//////////////////////////////////////////////////////////////////////////
                                       ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidTokenAddress();
    error InvalidMinAmount();
    error InvalidSignerThreshold();
    error InvalidTokenIds();

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(ITokenStaker _tokenStaker) {
        TOKEN_STAKER = _tokenStaker;
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
        // cache the account
        address account = msg.sender;
        // check if the module is already initialized and revert if it is
        if (isInitialized(account)) revert AlreadyInitialized(account);

        TGAConfig memory config = abi.decode(data, (TGAConfig));
        if (config.tokenAddress == address(0)) revert InvalidTokenAddress();
        if (config.minAmount == 0) revert InvalidMinAmount();
        if (config.signerThreshold == 0) revert InvalidSignerThreshold();
        if (config.tokenType == TokenType.ERC20 && config.validTokenIds.length > 0) {
            revert InvalidTokenIds();
        }

        accountConfig[account] = config;
    }

    /**
     * De-initialize the module with the given data
     */
    function onUninstall(bytes calldata) external override {
        // clean up the account config
        delete accountConfig[msg.sender];
    }

    function setMinAmount(uint256 minAmount) external {
        if (minAmount == 0) revert InvalidMinAmount();

        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        TGAConfig storage $config = accountConfig[account];
        $config.minAmount = minAmount;
    }

    function setSignerThreshold(uint256 signerThreshold) external {
        if (signerThreshold == 0) revert InvalidSignerThreshold();

        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        TGAConfig storage $config = accountConfig[account];
        $config.signerThreshold = signerThreshold;
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) public view returns (bool) {
        // get storage reference to account config
        TGAConfig storage $config = accountConfig[smartAccount];
        // check if the token address is not 0
        return $config.tokenAddress != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Validates PackedUserOperation
     *
     * @param userOp UserOperation to be validated
     * @param userOpHash Hash of the UserOperation to be validated
     *
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - 0 if the signature is valid
     *  - 1 if the signature is invalid
     *  - <20-byte> aggregatorOrSigFail, <6-byte> validUntil and <6-byte> validAfter (see ERC-4337
     * for more details)
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        // validate the signature with the config
        bool isValid = _validateSignatureWithConfig(userOp.sender, userOpHash, userOp.signature);

        // return the result
        if (isValid) {
            return VALIDATION_SUCCESS;
        }
        return VALIDATION_FAILED;
    }

    /**
     * Validates an ERC-1271 signature
     *
     * @param sender The sender of the ERC-1271 call to the account
     * @param hash The hash of the message
     * @param signature The signature of the message
     *
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - EIP1271_SUCCESS if the signature is valid
     *  - EIP1271_FAILED if the signature is invalid
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        virtual
        override
        returns (bytes4 sigValidationResult)
    {
        // validate the signature with the config
        bool isValid = _validateSignatureWithConfig(sender, hash, signature);

        // return the result
        if (isValid) {
            return EIP1271_SUCCESS;
        }
        return EIP1271_FAILED;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _validateSignatureWithConfig(
        address account,
        bytes32 hash,
        bytes calldata data
    )
        internal
        view
        returns (bool)
    {
        if (isInitialized(account) == false) {
            return false;
        }

        // get the account config
        TGAConfig storage config = accountConfig[account];
        uint256 _threshold = config.signerThreshold;

        // recover the signers from the signatures
        address[] memory signers =
            CheckSignatures.recoverNSignatures(ECDSA.toEthSignedMessageHash(hash), data, _threshold);

        // sort and uniquify the signers to make sure a signer is not reused
        signers.sort();
        signers.uniquifySorted();

        // check if the signers are owners
        uint256 validSigners;
        uint256 signersLength = signers.length;
        for (uint256 i = 0; i < signersLength; i++) {
            if (_isValidBalance(account, signers[i])) {
                validSigners++;
            }
        }

        // check if the threshold is met and return the result
        return validSigners >= _threshold;
    }

    function _isValidBalance(address account, address signer) internal view returns (bool) {
        // get the account config
        TGAConfig storage config = accountConfig[account];
        if (config.tokenType == TokenType.ERC20) {
            uint256 balance =
                TOKEN_STAKER.erc20StakeOf(signer, IERC20(config.tokenAddress), account);
            return balance >= config.minAmount;
        }
        if (config.tokenType == TokenType.ERC721) {
            uint256 balance = TOKEN_STAKER.erc721StakeOf(
                signer, IERC721(config.tokenAddress), config.validTokenIds, account
            );
            return balance >= config.minAmount;
        }
        if (config.tokenType == TokenType.ERC1155) {
            uint256 balance = TOKEN_STAKER.erc1155StakeOf(
                signer, IERC1155(config.tokenAddress), config.validTokenIds, account
            );
            return balance >= config.minAmount;
        }
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
        return "TokenValidator";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /**
     * Check if the module is of a certain type
     *
     * @param typeID The type ID to check
     *
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
