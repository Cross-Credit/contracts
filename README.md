# CrossCredit Protocol - Cross-Chain Lending & Borrowing Platform 🌉

CrossCredit is a revolutionary decentralized finance (DeFi) protocol that enables seamless lending and borrowing
operations across multiple blockchain networks. Built on Chainlink's Cross-Chain Interoperability Protocol (CCIP), the
platform allows users to deposit collateral on one blockchain and borrow assets on another, creating a unified
cross-chain DeFi experience.

**[CrossCredit on Ethereum Sepolia](https://eth-sepolia.blockscout.com/address/0x883B1acd783a66b543b1d4Ee965372B8EaA2d430?tab=read_write_contract)**

**[CrossCredit on Avalanche Fuji](https://testnet.snowtrace.io/address/0xEA084C9e33B3aC71bCC4788A549B2905f26BfFb2/contract/43113/writeContract?chainid=43113)**

## Project Architecture & Technology Stack 🏗️

### Core Technology Stack

- **Smart Contract Language**: Solidity ^0.8.13
- **Development Framework**: Foundry (Forge)
- **Cross-Chain Infrastructure**: Chainlink CCIP (Cross-Chain Interoperability Protocol)
- **Price Oracles**: Chainlink Data Feeds
- **Security Framework**: OpenZeppelin Contracts
- **Testing Environment**: Forge Standard Library

### Architecture Components

**Smart Contract Layer**:

- **CrossCredit.sol**: Main protocol contract handling all lending/borrowing operations
- **CrossCreditLibrary.sol**: Utility library for data structures and helper functions
- **ICrossCredit.sol**: Interface defining protocol operations and events
- **Error.sol**: Centralized error handling and custom error definitions
- **AggregatorV3Interface.sol**: Chainlink price feed interface integration

**Cross-Chain Infrastructure**:

- **Chainlink CCIP Router**: Handles secure cross-chain message transmission
- **CCIP Receiver**: Processes incoming cross-chain position updates
- **Message Encoding/Decoding**: Structured data transmission between chains

**Oracle Integration**:

- **Chainlink Price Feeds**: Real-time asset price data with staleness protection
- **Multi-chain Price Synchronization**: Consistent pricing across all supported networks

## File Structure & Chainlink Integration 📁

### Core Contract Files

**[CrossCredit.sol](src/CrossCredit.sol)** - Main Protocol Contract

- **Chainlink CCIP Integration**:
    - Inherits from `CCIPReceiver` for cross-chain message handling
    - Uses `IRouterClient` for sending cross-chain messages
    - Implements `Client.Any2EVMMessage` for message processing
- **Chainlink Price Feeds**:
    - Integrates `AggregatorV3Interface` for real-time price data
    - Implements price staleness checks and validation
    - Supports multiple price feed configurations per asset

**[CrossCreditLibrary.sol](src/libraries/CrossCreditLibrary.sol)** - Data Structures

- Defines `PositionOnConnected` struct for cross-chain position data
- Contains `LendPosition` and `BorrowPosition` structures

**[ICrossCredit.sol](src/interfaces/ICrossCredit.sol)** - Protocol Interface

- Defines all protocol events including CCIP message events
- Specifies function signatures for external integrations
- Contains event definitions for cross-chain operations

**[AggregatorV3Interface.sol](src/interfaces/AggregatorV3Interface.sol)** - Chainlink Oracle Interface

- Standard Chainlink price feed interface
- Enables `latestRoundData()` calls for price retrieval
- Supports decimal precision and data validation

**[Error.sol](src/utils/Error.sol)** - Error Handling

- Centralized custom error definitions
- Oracle-specific errors (StaleOraclePrice, InvalidOraclePrice, OracleCallFailed)
- CCIP-related errors (ReceiverAddressNotSet, ConnectedChainNotSet)

## Major Protocol Functions 🔍

### 1. **lend() - Cross-Chain Collateral Deposit**

**Purpose**: Deposit assets as collateral that can be utilized for borrowing across multiple blockchain networks

**Chainlink Integration**:

- **CCIP Message Transmission**: Encodes lending position data and transmits to connected chains
- **Cross-Chain Synchronization**: Ensures lending positions are updated on all connected networks
- **Message Structure**: Uses `PositionOnConnected` struct with source chain ID, caller address, asset mapping, and
  amount

**Technical Implementation**:

- **Asset Validation**: Verifies asset is whitelisted and has cross-chain mapping configured
- **Position Management**: Updates local lending position and increments total deposited amount
- **Cross-Chain Broadcasting**: Sends CCIP message with `LEND_POSITION` type to synchronize across chains
- **Multi-Token Support**: Handles both native tokens (ETH, LINK) and ERC20 tokens seamlessly

**Security Features**:

- Reentrancy protection through OpenZeppelin's ReentrancyGuard
- Input validation for zero amounts and invalid addresses
- Asset whitelisting verification before processing

### 2. **borrow() - Cross-Chain Asset Borrowing**

**Purpose**: Borrow assets against cross-chain collateral with comprehensive risk management

**Chainlink Price Feed Integration**:

- **Real-Time Valuation**: Uses Chainlink oracles to calculate current USD value of collateral and debt
- **Multi-Asset Pricing**: Supports diverse asset portfolios with individual price feed configurations
- **Staleness Protection**: Validates price data freshness (1-hour maximum age) before calculations

**Risk Management System**:

- **Cross-Chain LTV Calculation**: Aggregates collateral value from all connected chains
- **75% LTV Enforcement**: Prevents borrowing that exceeds safe collateralization ratios
- **Dynamic Risk Assessment**: Real-time evaluation considering all user positions across chains

**Technical Flow**:

- **Collateral Verification**: Calculates total USD value of user's cross-chain collateral
- **Debt Impact Analysis**: Evaluates new borrowing against existing debt positions
- **Position Updates**: Updates local borrow position and broadcasts via CCIP
- **Asset Distribution**: Transfers borrowed assets directly to user's wallet

### 3. **repay() - Debt Reduction and Position Management**

**Purpose**: Repay borrowed assets to reduce debt burden and improve position health across chains

**Cross-Chain Coordination**:

- **Position Synchronization**: Updates debt positions on all connected chains simultaneously
- **CCIP Message Broadcasting**: Sends updated borrow position data to maintain consistency
- **Multi-Chain Debt Tracking**: Ensures accurate debt accounting across all networks

**Technical Features**:

- **Flexible Repayment Options**: Supports partial and full debt repayment
- **Automatic Capping**: Prevents overpayment by limiting repayment to outstanding debt
- **Multi-Token Processing**: Handles both native tokens and ERC20 repayments
- **Immediate Position Updates**: Real-time debt reduction across all connected chains

**User Benefits**:

- Instant improvement in position health and LTV ratio
- Reduced liquidation risk through debt reduction
- Gas-efficient partial repayment options

### 4. **unlend() - Collateral Withdrawal with Safety Validation**

**Purpose**: Withdraw deposited collateral while maintaining healthy borrowing positions

**Chainlink Price Integration**:

- **Withdrawal Impact Calculation**: Uses real-time price feeds to assess USD impact of collateral withdrawal
- **Cross-Chain Risk Assessment**: Evaluates remaining collateral against total debt across all chains
- **LTV Compliance Verification**: Ensures post-withdrawal LTV remains below 75% threshold

**Safety Mechanisms**:

- **Multi-Layer Validation**: Comprehensive checks prevent creation of liquidatable positions
- **Cross-Chain Collateral Tracking**: Considers collateral on all connected chains
- **Dynamic Risk Calculation**: Real-time assessment of position health impact

**Technical Implementation**:

- **Collateral Sufficiency Checks**: Validates remaining collateral can support existing debt
- **Position Updates**: Reduces lending position and synchronizes globally via CCIP
- **Asset Transfer**: Secure transfer of withdrawn collateral to user's wallet

### 5. **liquidate() - Automated Cross-Chain Liquidation System**

**Purpose**: Liquidate undercollateralized positions to maintain protocol solvency across all chains

**Liquidation Threshold**: 80% - Positions become liquidatable when debt exceeds 80% of collateral value

**Chainlink Oracle Integration**:

- **Real-Time Risk Assessment**: Uses current price feeds to determine liquidation eligibility
- **Multi-Asset Valuation**: Calculates comprehensive position health across all assets and chains
- **Price Feed Validation**: Ensures oracle data integrity before liquidation execution

**Cross-Chain Liquidation Process**:

**Eligibility Validation**:

- Aggregates borrower's total collateral and debt values across all connected chains
- Verifies position health exceeds 80% liquidation threshold using real-time price data
- Validates liquidator's repayment amount covers complete debt obligation

**Comprehensive Debt Validation**:

- **Multi-Chain Debt Aggregation**: Combines borrower's debt from source and connected chains
- **Decimal Precision Handling**: Manages different token decimals between chains for accurate calculations
- **Complete Coverage Verification**: Ensures liquidation payment covers total debt across all chains

**Collateral Processing & Distribution**:

- **Source Chain Collateral Transfer**: Immediately transfers available collateral to liquidator
- **Cross-Chain Liquidation Messages**: Sends CCIP messages to process collateral on connected chains
- **Position Reset**: Zeros out all borrower positions across all connected chains
- **Multi-Token Support**: Handles both native tokens and ERC20 collateral transfers

**Automatic Refund System**:

- **Overpayment Detection**: Calculates excess payment if liquidator pays more than required
- **Automatic Refunds**: Returns surplus amount to liquidator in same token
- **Gas-Efficient Processing**: Optimized refund calculations and transfers

## Supporting Infrastructure Functions 🛠️

### **getTotalUSDValueOfUserByType() - Cross-Chain Position Valuation**

**Chainlink Price Feed Integration**:

- **Multi-Asset Price Retrieval**: Queries Chainlink oracles for all whitelisted assets
- **Real-Time Valuation**: Uses current price data for accurate USD calculations
- **Price Data Validation**: Implements comprehensive checks for price feed integrity

**Cross-Chain Aggregation**:

- **Dual-Chain Position Tracking**: Combines positions from both source and connected chains
- **Decimal Normalization**: Sophisticated handling of different token decimals between chains
- **Comprehensive Risk Assessment**: Provides holistic view of user's financial position

### **Cross-Chain Communication Infrastructure**

**_ccipSend() - Outbound Message Transmission**:

- **Message Encoding**: Structures position data for cross-chain transmission
- **Fee Calculation**: Automatically calculates and pays CCIP transmission fees
- **Gas Optimization**: Implements efficient gas limits (200,000) and execution parameters
- **Message Tracking**: Provides comprehensive event logging for message monitoring

**_ccipReceive() - Inbound Message Processing**:

- **Message Validation**: Verifies CCIP message integrity and source authentication
- **Data Decoding**: Extracts position updates and operation types from cross-chain messages
- **Position Synchronization**: Updates connected chain position mappings
- **Liquidation Coordination**: Handles cross-chain liquidation message processing

### **Oracle Price Integration System**

**_getAssetPriceData() - Chainlink Price Feed Interface**:

- **Multi-Feed Support**: Interfaces with multiple Chainlink AggregatorV3Interface instances
- **Staleness Protection**: Implements 1-hour maximum age validation for price data
- **Data Integrity Checks**: Validates positive prices and successful oracle responses
- **Error Handling**: Provides graceful degradation when oracle data unavailable

## Protocol Configuration & Parameters 📋

### Risk Management Constants

- **LTV (Loan-to-Value)**: 75% - Maximum safe borrowing ratio against collateral
- **LIQ (Liquidation Threshold)**: 80% - Automatic liquidation trigger point
- **Price Staleness Limit**: 3600 seconds - Maximum acceptable age for oracle price data
- **CCIP Gas Limit**: 200,000 - Allocated gas for cross-chain message execution

### Cross-Chain Operation Types

- **LEND_POSITION (1)**: Collateral deposit and withdrawal operations
- **BORROW_POSITION (2)**: Debt position management and updates
- **LIQUIDATE_POSITION (3)**: Cross-chain liquidation coordination messages

## Chainlink Integration Architecture 🔗

### CCIP (Cross-Chain Interoperability Protocol) Integration

**Message Structure**:

- **PositionOnConnected**: Standardized data structure for cross-chain position updates
- **Operation Types**: Encoded message types for different protocol operations
- **Chain Identification**: Source chain ID tracking for message routing

**Security Features**:

- **Message Authentication**: CCIP provides cryptographic message verification
- **Replay Protection**: Built-in protection against message replay attacks
- **Atomic Execution**: Ensures cross-chain operations complete successfully or revert

### Price Feed Integration

**Multi-Asset Support**:

- **Configurable Price Feeds**: Individual Chainlink oracle configuration per asset
- **Decimal Handling**: Automatic handling of different price feed decimal precisions
- **Fallback Mechanisms**: Graceful error handling when price feeds unavailable

**Data Validation**:

- **Freshness Checks**: Automatic validation of price data recency
- **Range Validation**: Ensures price values are within reasonable bounds
- **Source Verification**: Validates price data comes from authorized Chainlink oracles

## Security Architecture 🛡️

### Multi-Layer Security Framework

**Access Control**:

- **Owner-Restricted Functions**: Asset whitelisting, oracle configuration, protocol parameters
- **Modifier-Based Validation**: Comprehensive input sanitization and state verification
- **Reentrancy Protection**: OpenZeppelin ReentrancyGuard on all state-changing functions

**Cross-Chain Security**:

- **Message Integrity**: CCIP provides cryptographic verification of cross-chain messages
- **Position Synchronization**: Atomic updates ensure consistent state across all chains
- **Oracle Security**: Multiple validation layers for price feed data integrity

**Economic Security**:

- **Overcollateralization**: 75% LTV ensures sufficient collateral backing
- **Liquidation Incentives**: Economic rewards for maintaining protocol health
- **Risk Isolation**: Individual position management prevents systemic risks

## Error Handling & Validation System 🚨

### Comprehensive Error Categories

**Asset & Validation Errors**:

- `NotWhitelistedAsset()`: Asset not approved for protocol use
- `NotConnectedAsset()`: Asset lacks cross-chain mapping configuration
- `InvalidAddress()`: Zero address or invalid address parameter
- `NoZeroAmount()`: Prevention of zero-value operations

**Risk Management Errors**:

- `AmountSurpassesLTV()`: Borrowing would exceed 75% loan-to-value ratio
- `UserNotLiquidateable()`: Position doesn't meet 80% liquidation threshold
- `InsufficientCollateralRemaining()`: Withdrawal would create unsafe position
- `CollateralExhausted()`: Insufficient collateral for requested operation

**Oracle & Price Feed Errors**:

- `StaleOraclePrice()`: Price data exceeds 1-hour staleness limit
- `InvalidOraclePrice()`: Price value is zero or negative
- `OracleCallFailed()`: Chainlink oracle call unsuccessful
- `PriceFeedNotSet()`: No price feed configured for asset

**Cross-Chain Operation Errors**:

- `ReceiverAddressNotSet()`: No receiver contract configured on destination chain
- `ConnectedChainNotSet()`: Destination chain not properly configured
- `NotEnoughBalance()`: Insufficient funds for CCIP message fees

## Gas Optimization & Efficiency 🔥

### Storage Optimization

- **EnumerableSet Usage**: O(1) lookups for whitelisted asset validation
- **Packed Data Structures**: Minimized storage slots through efficient struct design
- **Mapping Optimization**: Strategic use of nested mappings for position tracking

### Cross-Chain Efficiency

- **Optimized Message Size**: Minimal data encoding for CCIP transmission
- **Batch Operations**: Reduced per-transaction overhead through efficient batching
- **Native Fee Payments**: Uses chain-native tokens instead of LINK for cost efficiency

## Deployment & Integration Guide 🚀

### Prerequisites

- Foundry development environment
- Access to Chainlink CCIP testnet/mainnet
- Configured price feed addresses for supported assets
- Multi-chain deployment infrastructure

### Deployment Configuration

**Constructor Parameters**:

- `_adminAddress`: Protocol administrator with configuration privileges
- `_nativeAsset`: Native token address for the deployment chain (ETH, AVAX, etc.)
- `router`: Chainlink CCIP router address for the target network

**Post-Deployment Setup**:

1. **Asset Configuration**: Whitelist supported assets with `listAsset()`
2. **Price Feed Setup**: Configure Chainlink oracles using `setPriceFeed()`
3. **Cross-Chain Mapping**: Establish asset relationships with `setAssetToAssetOnConnectedChain()`
4. **Connected Chain Setup**: Configure destination chain with `setConnectedChainID()` and
   `setReceiverOnConnectedChain()`

### Integration Requirements

**Chainlink Infrastructure**:

- CCIP Router contracts deployed on both source and destination chains
- Active Chainlink price feeds for all supported assets
- Sufficient native tokens for CCIP message fees

**Multi-Chain Coordination**:

- Synchronized deployment across all target chains
- Consistent asset mappings and configurations
- Cross-chain receiver contract addresses properly configured

## Advanced Protocol Features 🎯

### Unified Cross-Chain Position Management

- **Real-Time Synchronization**: Instant position updates across all connected blockchain networks
- **Comprehensive Risk Assessment**: Holistic evaluation of user positions for accurate risk calculation
- **Cross-Chain Collateral Optimization**: Efficient utilization of assets across multiple networks without bridging

### Sophisticated Liquidation Ecosystem

- **Community-Driven Liquidations**: Permissionless liquidation system with economic incentives for participants
- **Partial Liquidation Support**: Flexible liquidation amounts based on precise debt coverage requirements
- **Automatic Refund Mechanisms**: Built-in overpayment protection and surplus return for liquidators
- **Cross-Chain Coordination**: Seamless liquidation processing across all connected networks

### Extensible Protocol Architecture

- **Modular Design**: Clean separation of concerns enabling easy maintenance and future upgrades
- **Plugin-Compatible Asset Support**: Standardized interfaces for seamless integration of new assets
- **Configurable Risk Parameters**: Administrative control over key protocol parameters (LTV, liquidation thresholds)
- **Scalable Chain Integration**: Framework for adding new blockchain networks with minimal code changes

## Monitoring & Analytics 📊

### Event Tracking System

- **MessageSent**: CCIP outbound message tracking with fees and destinations
- **MessageReceived**: Inbound cross-chain message processing confirmation
- **Position Updates**: Real-time tracking of lending and borrowing position changes
- **Liquidation Events**: Comprehensive liquidation tracking across all chains

### Protocol Health Metrics

- **Total Value Locked (TVL)**: Aggregate value across all connected chains
- **Utilization Rates**: Asset-specific borrowing utilization tracking
- **Liquidation Statistics**: Health metrics and liquidation frequency analysis
- **Cross-Chain Activity**: Message volume and cross-chain operation statistics

## Testing & Quality Assurance 🧪

### Comprehensive Test Suite

- **Unit Tests**: Individual function testing with edge case coverage
- **Integration Tests**: Cross-chain message flow and position synchronization testing
- **Liquidation Scenarios**: Comprehensive liquidation testing across various market conditions
- **Oracle Integration Tests**: Price feed integration and staleness protection validation

### Security Considerations

- **Reentrancy Protection**: All state-changing functions secured against reentrancy attacks
- **Oracle Manipulation Resistance**: Multiple validation layers for price feed integrity
- **Cross-Chain Message Security**: CCIP provides cryptographic message verification
- **Economic Security Model**: Overcollateralization and liquidation incentives maintain protocol stability

## Future Development Roadmap 🛣️

### Planned Enhancements

- **Multi-Asset Liquidation**: Support for liquidating multiple collateral types simultaneously
- **Dynamic Risk Parameters**: Algorithmic adjustment of LTV and liquidation thresholds
- **Governance Integration**: Community-driven protocol parameter management
- **Additional Chain Support**: Expansion to more blockchain networks

### Scalability Improvements

- **Gas Optimization**: Continued optimization of cross-chain message costs
- **Batch Operations**: Enhanced support for multiple operations in single transactions
- **Cross-Chain Yield Strategies**: Integration with yield farming protocols across chains

---

## Quick Start Guide 🏁

### For Developers

1. **Clone Repository**: Access the CrossCredit contracts repository
2. **Install Dependencies**: Set up Foundry and required dependencies
3. **Configure Networks**: Set up RPC endpoints for target chains
4. **Deploy Contracts**: Use provided deployment scripts
5. **Configure Protocol**: Set up assets, price feeds, and cross-chain mappings

### For Users

1. **Connect Wallet**: Use MetaMask or compatible wallet
2. **Select Networks**: Choose source and destination chains
3. **Deposit Collateral**: Use `lend()` function to deposit assets
4. **Borrow Assets**: Access liquidity on any connected chain
5. **Manage Positions**: Monitor and adjust positions as needed

### For Integrators

1. **Interface Integration**: Implement ICrossCredit interface
2. **Event Monitoring**: Set up event listeners for position tracking
3. **Price Feed Integration**: Connect to protocol price data
4. **Cross-Chain Coordination**: Handle multi-chain user experiences

---

CrossCredit represents the next evolution of DeFi infrastructure, providing seamless cross-chain lending and borrowing
capabilities through sophisticated integration with Chainlink's proven oracle and cross-chain technologies. The
protocol's modular architecture, comprehensive security framework, and extensible design make it an ideal foundation for
the multi-chain DeFi ecosystem.

**Key Differentiators**:

- **True Cross-Chain Operations**: No asset bridging required
- **Chainlink-Powered Security**: Proven oracle and messaging infrastructure
- **Comprehensive Risk Management**: Multi-chain position tracking and validation
- **Developer-Friendly Architecture**: Clean interfaces and extensive documentation
- **Community-Driven Liquidations**: Decentralized protocol health maintenance

## ⚠️ ████████ WARNING ████████ ⚠️

**The CrossCredit smart contracts are experimental and have _NOT_ been audited.**

They may contain bugs, vulnerabilities, or unintended behavior.

> 🚫 Use at your own risk.  
> 🚧 Do **NOT** deploy in production environments without a professional security audit.

---

CrossCredit authors assume **no responsibility** for any loss or damage.
