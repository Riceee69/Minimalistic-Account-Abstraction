////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////           Account Abstraction              //////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";


contract MinimalAccount is Ownable, IAccount {
    ////////////////////////////////////
    // Errors              
    ////////////////////////////////////
    error MinimalAccount__AccessDenied();
    error MinimalAccount__CallFailed(bytes);

    ////////////////////////////////////
    // State Variables              
    ////////////////////////////////////
    IEntryPoint immutable public i_entryPoint;

    ////////////////////////////////////
    // Functions              
    ////////////////////////////////////
    constructor(address entryPoint) Ownable(msg.sender){
        i_entryPoint = IEntryPoint(entryPoint);
    }

    ////////////////////////////////////
    // Execution Phase               
    ////////////////////////////////////
    function execute(address target, bytes calldata functiondata) public {
        //allows the owner to directly send too since they are the signer
        if(msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__AccessDenied();
        }

        //Call target with userOp calldata
        (bool success, bytes memory data) = target.call(functiondata);
        if (!success){
            revert MinimalAccount__CallFailed(data);
        }
    }

    ////////////////////////////////////
    // Verification Phase               
    ////////////////////////////////////
    //This function validates the signautre logic used in the account abstraction, the logic used here is the signer should be the owner of this contract
    function validateUserOp
    (PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external returns (uint256 validationData) {
    if(msg.sender != address(i_entryPoint)) {
        revert MinimalAccount__AccessDenied();
    }
    validationData =  _validateUserOp(userOp, userOpHash);
    _payForGasPrefund(missingAccountFunds);
    }

    ////////////////////////////////////
    // Internal Functions              
    ////////////////////////////////////     
    function _validateUserOp (PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256) {
        //validate the userOp
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (address signer,,) = ECDSA.tryRecover(ethSignedMessageHash, userOp.signature);
        if(signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payForGasPrefund(uint256 gasFunds) internal {
        if(gasFunds != 0){
            (bool success,) = payable(msg.sender).call{value: gasFunds, gas: type(uint256).max}("");
            require(success, "MinimalAccount: Failed to pay for gas");
        }
    }
}