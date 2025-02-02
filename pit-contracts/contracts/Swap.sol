// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ERC20Token.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title TokenSwap Contract
/// @notice This contract allows users to swap ERC20 tokens for ETH and vice versa, and also create new ERC20 tokens
contract TokenSwap {
    using SafeMath for uint256;

    uint256 public constant MAX_ETH_BALANCE = 30 ether;

    ERC20Token public token;
    bool public swapEnabled;
    uint256 SwapRate = 33333333;
    uint256 tokenBalance = 0;
    

    event TokenCreated(address indexed tokenAddress, uint256 totalTokens);
    event EthToTokenSwapped(address indexed user, uint256 ethAmount, uint256 tokenAmount);
    event TokenToEthSwapped(address indexed user, uint256 tokenAmount, uint256 ethAmount);
    event UpgradeTriggered();

    modifier whenSwapEnabled() {
        require(swapEnabled, "Swapping is disabled");
        _;
    }

    constructor(string memory name, string memory symbol, uint256 totalTokens, address _creator, address delegationRegistry) payable {
        token = new ERC20Token(name, symbol, totalTokens, address(this), _creator, delegationRegistry);
        swapEnabled = true;
        emit TokenCreated(address(token), totalTokens);
        // make first buy (dev buy order)
        if (msg.value > 0) {
            uint256 ethAmount = msg.value;
            uint256 devTokens = ethAmount.mul(SwapRate);
            token.transfer(_creator, devTokens);
            tokenBalance += devTokens;
        }
        delegationRegistry.call(abi.encodeWithSignature("setDelegationForSelf(address)", _creator));
        delegationRegistry.call(abi.encodeWithSignature("disableSelfManagingDelegations()"));
        delegationRegistry.call(abi.encodeWithSignature("disableDelegationManagement()"));
    }

    /// @notice Swaps ETH for tokens
    function swapEthToToken() external payable whenSwapEnabled {
        require(msg.value > 0, "Must send ETH to swap for tokens");
        uint256 tokensToReceive = getTokenAmountForEth(msg.value);
        require(token.balanceOf(address(this)) >= tokensToReceive, "Not enough tokens in the contract");
        token.transfer(msg.sender, tokensToReceive);
        tokenBalance += tokensToReceive;
        emit EthToTokenSwapped(msg.sender, msg.value, tokensToReceive);
        if (address(this).balance >= MAX_ETH_BALANCE) {
            swapEnabled = false;
            triggerUpgrade();
        }
    }

    /// @notice Swaps tokens for ETH
    /// @param tokenAmount The amount of tokens to swap for ETH
    function swapTokenToEth(uint256 tokenAmount) external whenSwapEnabled {
        require(tokenAmount > 0, "Must specify token amount to swap for ETH");
        uint256 ethToReceive = getEthAmountForToken(tokenAmount);
        require(address(this).balance >= ethToReceive, "Not enough ETH in the contract");
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        payable(msg.sender).transfer(ethToReceive);
        tokenBalance -= tokenAmount;
        emit TokenToEthSwapped(msg.sender, tokenAmount, ethToReceive);

        if (address(this).balance >= MAX_ETH_BALANCE) {
            swapEnabled = false;
            triggerUpgrade();
        }
    }

    /// @notice Triggers an upgrade when the contract reaches the maximum ETH balance
    function triggerUpgrade() internal {
        emit UpgradeTriggered();
        // Here we implement the migration to frax swap dex and move
        // all the liquidity to the dex and burn the claiming tokens.
        // uint256 tokenReserve = tokenBalance;
        // uint256 ethReserve = address(this).balance;
    }

    /// @notice Calculates the amount of tokens for a given amount of ETH based on current reserve ratios
    /// @param ethAmount The amount of ETH
    /// @return The amount of tokens
    /// @notice this price calculation is only used for testing purposes, this function will be updated later
    /// to uniswap v3 tick and liquidity.
    function getTokenAmountForEth(uint256 ethAmount) public view returns (uint256) {
        uint256 tokenReserve = tokenBalance;
        uint256 ethReserve = address(this).balance.add(ethAmount); // add ethAmount as it will be added to the reserve
        return ethAmount.mul(tokenReserve).div(ethReserve);
    }

    /// @notice Calculates the amount of ETH for a given amount of tokens based on current reserve ratios
    /// @param tokenAmount The amount of tokens
    /// @return The amount of ETH
    function getEthAmountForToken(uint256 tokenAmount) public view returns (uint256) {
        uint256 tokenReserve = tokenBalance.add(tokenAmount); // add tokenAmount as it will be added to the reserve
        uint256 ethReserve = address(this).balance;
        return tokenAmount.mul(ethReserve).div(tokenReserve);
    }

    function getTokenAddress() public view  returns (address) {
        return address(token);
    }

    function getLiquidity() public view  returns (uint256, uint256) {
        uint256 tokenLiq = tokenBalance;
        uint256 ethLiq = address(this).balance;

        return (tokenLiq, ethLiq);
    }

}


