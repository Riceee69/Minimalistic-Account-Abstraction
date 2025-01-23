//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MinimalAccount} from "src/Ethereum/MinimalAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract SendPackedUserOp is Script {
    address  entryPoint;
    address  deployer;
    address  usdc;

    //Use run to send txn to mainnet
    function run() public {
        //Will approve 1 ether to my StudyPurpose2 account from StudyPurpose account
        uint256 APPROVE_AMOUNT = 1e18;
        address userToApprove = 0x79c51C2e1845900c4845baf9EFee91c62723cB7d; //StudyPurpose2 account
        HelperConfig helperConfig = new HelperConfig();
        (
            entryPoint,
            deployer,
            usdc
        ) = helperConfig.networkConfig();
        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment("MinimalAccount", block.chainid);
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, userToApprove, APPROVE_AMOUNT);
        bytes memory executeCalldata = abi.encodeWithSelector(MinimalAccount.execute.selector, usdc, functionData);
        PackedUserOperation memory userOp = generateSignedUserOp(minimalAccountAddress, executeCalldata, entryPoint);
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.startBroadcast(deployer);
        IEntryPoint(entryPoint).handleOps(userOps, payable(deployer));
        vm.stopBroadcast();
    }

    function generateSignedUserOp(address sender, bytes memory functionData, address entryPoint) public view returns (PackedUserOperation memory){
        uint256 nonce = vm.getNonce(sender) - 1;
        //generate unsinged user op
        PackedUserOperation memory userOp = _generateUnsignedUserOp(sender, nonce, functionData);

        //generate the hash of the user op
        bytes32 userOpHash = _getUserOpHash(userOp, entryPoint);
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        //sign the user op hash
        uint8 v;
        bytes32 r; 
        bytes32 s;
        if (block.chainid == 31337){
            string memory mnemonic = "test test test test test test test test test test test junk";
            uint256 privateKey = vm.deriveKey(mnemonic, 0);//derives the first private key from anvil.
            //console.log("privateKey", privateKey);
            (v, r, s) = vm.sign(privateKey, digest);
        }else{
            (v, r, s) = vm.sign(sender, digest);
        }
       userOp.signature = abi.encodePacked(r, s, v);
       return userOp;
    }

    function _generateUnsignedUserOp(address sender, uint256 nonce, bytes memory functionData) internal pure returns (PackedUserOperation memory){
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: functionData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }

    function _getUserOpHash(PackedUserOperation memory userOp, address entryPoint) public view returns (bytes32) {
        //getUserOpHash doesn't consider the signature variable
        return IEntryPoint(entryPoint).getUserOpHash(userOp);
    }
}