//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

//ZkSync Era Imports
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "cyfrin/foundry-era-contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "cyfrin/foundry-era-contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "cyfrin/foundry-era-contracts/libraries/SystemContractsCaller.sol";
import {INonceHolder} from "cyfrin/foundry-era-contracts/interfaces/INonceHolder.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT, 
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "cyfrin/foundry-era-contracts/Constants.sol";
import {Utils} from "cyfrin/foundry-era-contracts/libraries/Utils.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Lifecycle of a type 113 (0x71) transaction
 * msg.sender is the bootloader system contract
 *
 * Phase 1 Validation
 * 1. The user sends the transaction to the "zkSync API client" (sort of a "light node")
 * 2. The zkSync API client checks to see the the nonce is unique by querying the NonceHolder system contract
 * 3. The zkSync API client calls validateTransaction, which MUST update the nonce
 * 4. The zkSync API client checks the nonce is updated
 * 5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
 * 6. The zkSync API client verifies that the bootloader gets paid
 *
 * Phase 2 Execution
 * 7. The zkSync API client passes the validated transaction to the main node / sequencer (as of today, they are the same)
 * 8. The main node calls executeTransaction
 * 9. If a paymaster was used, the postTransaction is called
 */

contract ZkMinimalAccount is IAccount, Ownable {
    ///////////////////////////////////////////////////
    //          Errors
    //////////////////////////////////////////////////
    error ZkMinimalAccount__InsufficientFundsForFees();
    error ZkMinimalAccount_UnauthorizedSender();
    error ZkMinimalAccount_ExecutionFailed();
    error ZkMinimalAccount_PaymentFailed();

    ///////////////////////////////////////////////////
    //          Types
    //////////////////////////////////////////////////
    using MemoryTransactionHelper for Transaction;

    ///////////////////////////////////////////////////
    //          Modifiers
    //////////////////////////////////////////////////
    modifier requireBootloader() {
        if(msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount_UnauthorizedSender();
        }
        _;
    }

    modifier requireBootloaderOrOwner() {
        if(msg.sender != BOOTLOADER_FORMAL_ADDRESS || msg.sender != owner()) {
            revert ZkMinimalAccount_UnauthorizedSender();
        }
        _;       
    }

    ///////////////////////////////////////////////////
    //          Functions
    //////////////////////////////////////////////////
    constructor() Ownable(msg.sender) {}
    ///////////////////////////////////////////////////
    //          External Functions
    //////////////////////////////////////////////////
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
        requireBootloader
        returns (bytes4 magic){
            //update the nonce 
            SystemContractsCaller.systemCallWithPropagatedRevert(
                uint32(gasleft()),
                address(NONCE_HOLDER_SYSTEM_CONTRACT),
                0,
                abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, _transaction.nonce)
            );

            //check for fee to pay
            uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
            if (address(this).balance < totalRequiredBalance) {
                revert ZkMinimalAccount__InsufficientFundsForFees();
            }

            //validate the transaction
            bytes32 txHash = _transaction.encodeHash();
            (address signer,,)  = ECDSA.tryRecover(txHash, _transaction.signature);
            if(signer != owner()) {
                magic = bytes4(0);
            }else{
                magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
            }
        }

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable requireBootloaderOrOwner {
            address to = address(uint160(_transaction.to));
            bytes memory data = _transaction.data;
            uint128 value = Utils.safeCastToU128(_transaction.value);

            /*we need to handle if `to` is a Systems Contract Address (Here we are only checking for deployer contract)
            because it's a common one */
            if(to == address(DEPLOYER_SYSTEM_CONTRACT)) {
                SystemContractsCaller.systemCallWithPropagatedRevert(
                    uint32(gasleft()),
                    to,
                    value,
                    data
                );
            }else{
                bool success;
                assembly {
                    success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
                }
                if (!success){
                    revert ZkMinimalAccount_ExecutionFailed();
                }
            }
        }

    /* This function is used to execute a transaction from outside, which is not an AA transaction, anyone can send this transaction */
    function executeTransactionFromOutside(Transaction calldata _transaction) external payable{}

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable 
        requireBootloader {
            bool success = _transaction.payToTheBootloader();
            if (!success) {
                revert ZkMinimalAccount_PaymentFailed();
            }
        }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable{}

    ///////////////////////////////////////////////////
    //          Internal Functions
    //////////////////////////////////////////////////
}