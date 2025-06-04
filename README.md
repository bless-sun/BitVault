# BitVault: Bitcoin-Backed Lending Protocol

A secure, decentralized lending protocol built on Stacks that enables Bitcoin holders to leverage their BTC as collateral for stablecoin loans. BitVault bridges traditional Bitcoin HODLing with DeFi capabilities through Layer 2 infrastructure.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Getting Started](#getting-started)
- [Core Functions](#core-functions)
- [Risk Management](#risk-management)
- [Liquidation Mechanism](#liquidation-mechanism)
- [Oracle System](#oracle-system)
- [Governance](#governance)
- [Security Considerations](#security-considerations)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Overview

BitVault is a decentralized autonomous organization (DAO) that provides Bitcoin-backed lending services. Users can deposit Bitcoin as collateral and borrow stablecoins against their holdings while maintaining exposure to Bitcoin's price appreciation.

### Key Statistics

- **Minimum Collateral Ratio**: 150%
- **Liquidation Threshold**: 125%
- **Default Interest Rate**: 5% annually
- **Protocol Fee**: 1% of interest earned
- **Liquidation Penalty**: 10%

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        BitVault Protocol                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Oracle    │    │    Vault    │    │ Liquidation │     │
│  │   System    │    │  Management │    │   Engine    │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         │                   │                   │          │
│         └───────────────────┼───────────────────┘          │
│                             │                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Collateral  │    │  Interest   │    │ Governance  │     │
│  │ Management  │    │ Calculation │    │   System    │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
├─────────────────────────────────────────────────────────────┤
│                      Stacks Layer 2                        │
├─────────────────────────────────────────────────────────────┤
│                     Bitcoin Network                         │
└─────────────────────────────────────────────────────────────┘
```

### Core Components

1. **Vault System**: Individual user vaults that track collateral and debt
2. **Oracle Network**: Price feeds for accurate BTC/USD valuation
3. **Interest Engine**: Dynamic interest calculation and accumulation
4. **Liquidation System**: Automated liquidation for undercollateralized positions
5. **Governance Module**: Protocol parameter management and upgrades

## Key Features

### 🔒 Secure Collateral Management

- Multi-signature vault security
- Real-time collateralization monitoring
- Automated risk assessment

### 📈 Dynamic Interest Rates

- Market-responsive interest rates
- Compound interest calculation
- Protocol fee distribution

### ⚡ Instant Liquidation

- Automated liquidation triggers
- Liquidator incentive mechanisms
- Protocol solvency protection

### 🏛️ Decentralized Governance

- Community-driven parameter updates
- Transparent decision-making process
- Emergency pause capabilities

## Getting Started

### Prerequisites

- Stacks wallet (Leather, Xverse, etc.)
- Bitcoin for collateral
- Understanding of DeFi risks

### Basic Workflow

1. **Deposit Collateral**: Transfer Bitcoin to your vault
2. **Borrow Stablecoins**: Issue loans against your collateral
3. **Manage Position**: Monitor health and adjust as needed
4. **Repay Debt**: Return borrowed funds plus interest
5. **Withdraw Collateral**: Reclaim your Bitcoin

## Core Functions

### User Operations

#### Deposit Collateral

```clarity
(deposit-collateral (btc-amount uint))
```

Deposits Bitcoin as collateral into your vault.

#### Borrow Stablecoins

```clarity
(borrow (amount-to-borrow uint))
```

Issues a stablecoin loan against deposited collateral.

#### Repay Loan

```clarity
(repay (amount-to-repay uint))
```

Repays outstanding debt with interest.

#### Withdraw Collateral

```clarity
(withdraw-collateral (amount-to-withdraw uint))
```

Withdraws Bitcoin collateral (maintaining minimum ratios).

### Administrative Functions

#### Oracle Price Updates

```clarity
(update-btc-price (new-price uint))
```

Updates BTC/USD price feed (authorized oracles only).

#### Risk Parameter Management

```clarity
(set-minimum-collateral-ratio (new-ratio uint))
(set-liquidation-threshold (new-threshold uint))
(set-liquidation-penalty (new-penalty uint))
```

### Read-Only Functions

#### Vault Information

```clarity
(get-vault-info (owner principal))
(get-vault-health (owner principal))
```

#### Protocol Statistics

```clarity
(get-protocol-stats)
```

## Risk Management

### Collateralization Requirements

- **Minimum Ratio**: 150% (adjustable via governance)
- **Liquidation Threshold**: 125% (when liquidation occurs)
- **Safety Buffer**: 25% margin above liquidation threshold

### Interest Rate Model

Interest accrues continuously based on:

- Base interest rate (5% annually)
- Utilization rate adjustments
- Market conditions

### Risk Mitigation

- Real-time price feeds with staleness checks
- Gradual liquidation to minimize market impact
- Emergency pause functionality
- Multi-level authorization for critical functions

## Liquidation Mechanism

### Liquidation Triggers

Liquidation occurs when:

```text
Collateral Value / Total Debt < Liquidation Threshold (125%)
```

### Liquidation Process

1. **Detection**: Anyone can call the liquidation function
2. **Validation**: System verifies undercollateralization
3. **Execution**: Collateral is seized and sold
4. **Distribution**: Proceeds cover debt + penalty
5. **Incentive**: Liquidator receives bonus for maintaining protocol health

### Liquidation Penalties

- **Standard Penalty**: 10% of liquidated amount
- **Liquidator Bonus**: Portion of penalty as incentive
- **Protocol Reserve**: Remaining penalty supports protocol

## Oracle System

### Price Feed Requirements

- **Staleness Check**: Prices expire after 1 hour
- **Sanity Bounds**: Prices must be within reasonable ranges
- **Authorization**: Only approved oracles can update prices
- **Redundancy**: Multiple oracle sources for reliability

### Oracle Security

- Whitelist of authorized price providers
- Upper and lower bounds on price updates
- Gradual price change limits to prevent manipulation

## Governance

### Governance Parameters

The following parameters can be adjusted through governance:

- Minimum collateral ratio
- Liquidation threshold
- Liquidation penalty
- Interest rates
- Protocol fees
- Oracle validity periods

### Emergency Controls

- **Protocol Pause**: Halt all operations during emergencies
- **Owner Transfer**: Secure ownership transition process
- **Parameter Limits**: Built-in bounds on governance changes

## Security Considerations

### Smart Contract Security

- **Input Validation**: All user inputs are validated
- **Overflow Protection**: Safe math operations throughout
- **Access Control**: Role-based permissions
- **Reentrancy Protection**: State updates before external calls

### Economic Security

- **Collateral Requirements**: Over-collateralization protects lenders
- **Liquidation Incentives**: Market-driven liquidation system
- **Interest Rate Bounds**: Prevents excessive rates
- **Oracle Redundancy**: Multiple price sources

### Operational Security

- **Emergency Pause**: Protocol can be halted if needed
- **Gradual Updates**: Parameter changes are bounded
- **Multi-signature**: Critical operations require multiple approvals

## Development

### Local Development

1. **Install Clarinet**:

   ```bash
   npm install -g @hirosystems/clarinet-cli
   ```

2. **Initialize Project**:

   ```bash
   clarinet new bitvault
   cd bitvault
   ```

3. **Add Contract**:

   ```bash
   clarinet contract new bitvault
   ```

4. **Test Contract**:

   ```bash
   clarinet test
   ```

### Testing

The protocol includes comprehensive tests for:

- Collateral management operations
- Interest calculation accuracy
- Liquidation trigger conditions
- Oracle price update validation
- Access control mechanisms
- Edge cases and error conditions

### Deployment

1. **Testnet Deployment**:

   ```bash
   clarinet deploy --testnet
   ```

2. **Mainnet Deployment**:

   ```bash
   clarinet deploy --mainnet
   ```

## API Reference

### Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1000 | ERR_UNAUTHORIZED | Caller lacks required permissions |
| 1001 | ERR_INSUFFICIENT_COLLATERAL | Not enough collateral for operation |
| 1002 | ERR_BORROW_LIMIT_EXCEEDED | Loan exceeds maximum allowed |
| 1003 | ERR_INSUFFICIENT_LIQUIDITY | Protocol lacks liquidity |
| 1004 | ERR_VAULT_ALREADY_EXISTS | Vault creation conflict |
| 1005 | ERR_VAULT_NOT_FOUND | Vault does not exist |
| 1006 | ERR_INSUFFICIENT_DEPOSIT | Deposit amount too small |
| 1007 | ERR_INSUFFICIENT_REPAYMENT | Repayment amount invalid |
| 1008 | ERR_INVALID_AMOUNT | Amount parameter invalid |
| 1009 | ERR_MINIMUM_COLLATERAL_RATIO | Below minimum ratio |
| 1010 | ERR_VAULT_NOT_UNDERCOLLATERALIZED | Liquidation not allowed |
| 1011 | ERR_ORACLE_ERROR | Price feed unavailable |
| 1012 | ERR_PROTOCOL_PAUSED | Protocol temporarily disabled |

## Contributing

We welcome contributions to BitVault! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:

- Code style and standards
- Testing requirements
- Pull request process
- Security considerations

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add comprehensive tests
5. Update documentation
6. Submit a pull request
