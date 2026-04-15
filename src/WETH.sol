// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title WETH (Wrapped Ether)
 * @dev A standard implementation of Wrapped Ether that allows 1:1 conversion between ETH and ERC20.
 */
contract WETH is ERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor() ERC20("Wrapped Ether", "WETH") {}

    /**
     * @dev Deposits ETH into the contract and mints an equivalent amount of WETH to the sender.
     */
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Burns WETH from the sender and sends an equivalent amount of ETH back.
     * @param wad The amount of WETH to withdraw.
     */
    function withdraw(uint256 wad) public {
        _burn(msg.sender, wad);
        (bool success, ) = payable(msg.sender).call{value: wad}("");
        require(success, "Withdrawal failed");
        emit Withdrawal(msg.sender, wad);
    }

    /**
     * @dev Fallback function to allow depositing ETH by simply sending it to the contract.
     */
    receive() external payable {
        deposit();
    }
}
