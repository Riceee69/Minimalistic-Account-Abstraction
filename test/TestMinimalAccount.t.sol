//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployMinimalAccount} from "script/DeployMinimalAccount.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {MinimalAccount} from "src/Ethereum/MinimalAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract TestMinimalAccount is Test {
    DeployMinimalAccount deployMinimalAccount;
    MinimalAccount minimalAccount;
    address deployer;
    address entryPoint;
    IERC20 usdc;
    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");
    SendPackedUserOp sendPackedUserOp;

    function setUp() public {
        deployMinimalAccount = new DeployMinimalAccount();
        (minimalAccount, entryPoint, deployer, usdc) = deployMinimalAccount.run();
        sendPackedUserOp = new SendPackedUserOp();
    }

    /*//////////////////////////////////////////////////////////////
    We are gonna test the MinimalAccount by using it to interact with USDC ERC-20 Token Contract
    //////////////////////////////////////////////////////////////*/
    function testOwnerCanExecute() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        vm.prank(deployer);
        minimalAccount.execute(dest, functionData);
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecute() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        vm.expectRevert(MinimalAccount.MinimalAccount__AccessDenied.selector);
        vm.prank(randomUser);
        minimalAccount.execute(dest, functionData);
    }

    function testSignedUserOp() public view{
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);        
        address sender = deployer;
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, functionData);
        PackedUserOperation memory userOp = sendPackedUserOp.generateSignedUserOp(sender, executeCallData, entryPoint);
        bytes32 userOpHash = sendPackedUserOp._getUserOpHash(userOp, entryPoint);

        //Act
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (address signer,, ) = ECDSA.tryRecover(digest, userOp.signature);

        //Assert
        assertEq(signer, minimalAccount.owner());//since my validation method was signer should be minimalAccount owner. 
    }

    function testValidateUserOps() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);        
        address sender = address(minimalAccount);//NOTE THIS
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, functionData);
        PackedUserOperation memory userOp = sendPackedUserOp.generateSignedUserOp(sender, executeCallData, entryPoint);
        bytes32 userOpHash = sendPackedUserOp._getUserOpHash(userOp, entryPoint);

        //Act
        vm.deal(address(minimalAccount), 5e18);
        vm.prank(entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(userOp, userOpHash, 1e18);     

        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public{
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        uint256 initialRandomUserBalance = randomUser.balance;
        //console.log("initial balance:", initialRandomUserBalance);
        address dest = address(usdc);
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);        
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, functionData);
        PackedUserOperation memory userOp = sendPackedUserOp.generateSignedUserOp(address(minimalAccount), executeCallData, entryPoint);
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;     

        //Act
        vm.deal(address(minimalAccount), 5e18);
        vm.prank(randomUser);//acts as the alt mempool node
        IEntryPoint(entryPoint).handleOps(userOps, payable(randomUser));

        uint256 finalRandomUserBalance = randomUser.balance;

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
        assert(finalRandomUserBalance > initialRandomUserBalance);
    }
}