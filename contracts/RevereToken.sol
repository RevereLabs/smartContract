//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RevereToken is ERC20 {

    constructor () ERC20("Revere Token", "RTN") {}

    function mintToken(uint256 value ) public {
        _mint(msg.sender, value * (10 ** uint256(decimals())));
    }
}

