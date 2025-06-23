// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13; // Changed to ^0.8.20 to match your provided ERC20.sol

import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "openzeppelin/contracts/access/Ownable.sol";

contract CustomERC20 is ERC20, Ownable {
    // New private state variable to store the custom decimals value
    uint8 private _decimals;

    /**
     * @dev Constructor for a custom ERC20 token.
     * @param name_ The name of the token (e.g., "MyToken").
     * @param symbol_ The symbol of the token (e.g., "MTK").
     * @param decimals_ The number of decimal places for the token (e.g., 18 for standard, 6 for USDC).
     * @param initialSupply_ The initial amount of tokens to mint to the deployer.
     * This amount should be provided in the smallest unit (e.g., 100 * 10**decimals_).
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_, // Custom decimals parameter
        uint256 initialSupply_
    )
    ERC20(name_, symbol_) // Initialize the ERC20 parent contract with name and symbol
    Ownable(msg.sender) // Make the deployer the owner
    {
        // Store the custom decimals value in our new state variable
        _decimals = decimals_;

        // Mint the initial supply to the contract deployer (msg.sender)
        _mint(msg.sender, initialSupply_);
    }

    /**
     * @dev Overrides the default `decimals()` function from ERC20 to return our custom value.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    // Optional: Add a mint function for the owner if you want to allow more tokens to be created later
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}