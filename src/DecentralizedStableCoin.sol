//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 *  @title: Decentralized Stable Coin
 *  @author Huy Pham
 *  Collateral: Exogenous (ETH & BTC)
 *  Minting: Algorithmic
 *  Relative Stability: Pegged to USD
 *
 *  This contract meat to be governed by DSCEngine. This contract is just the ERC20 
 implementation of stablecoin.
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    /**
     * erro
     */
    error DSC__BurnAmoutLessThanZero();
    error DSC__BurnAmountExceedsBalance();
    error DSC__NotZeroAddress();
    error DSC__MoreThanZero();

    constructor() ERC20("DecentralizedStableCoin", "DSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        if (_amount <= 0) {
            revert DSC__BurnAmoutLessThanZero();
        }

        if (_amount > balanceOf(msg.sender)) {
            revert DSC__BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DSC__NotZeroAddress();
        }

        if (_amount <= 0) {
            revert DSC__MoreThanZero();
        }

        _mint(_to, _amount);
        return true;
    }
}
