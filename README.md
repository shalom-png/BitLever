# BitLever Protocol Documentation

**BitLever** is a Bitcoin-native leveraged trading protocol built on Stacks L2, enabling non-custodial derivatives trading with Bitcoin-finalized settlements. This document provides comprehensive technical documentation for the protocol's smart contract implementation.

## Protocol Overview

A decentralized trading system allowing:

- 20x leveraged long/short positions
- STX-denominated collateral
- Bitcoin-secured settlement layer
- Automated liquidation engine
- Transparent position tracking

## Key Features

1. **High Leverage Trading**

   - Maximum 20x leverage ratio
   - Long/short position types
   - Real-time PnL calculation

2. **Collateral Management**

   - 150% minimum collateral ratio
   - STX-based collateral system
   - Dynamic margin requirements

3. **Liquidation System**

   - 5% liquidator incentive
   - Price oracle integration
   - Automated position termination

4. **Security Framework**
   - Clarity smart contracts
   - Bitcoin-finalized transactions
   - Non-custodial architecture

## Technical Specifications

### Core Constants

| Constant               | Value | Description                     |
| ---------------------- | ----- | ------------------------------- |
| `MIN-COLLATERAL-RATIO` | 150%  | Minimum collateralization ratio |
| `MAX-LEVERAGE`         | 20x   | Maximum allowed leverage        |
| `LIQUIDATION-BONUS`    | 5%    | Liquidator incentive percentage |
| `TYPE-LONG`            | 1     | Long position identifier        |
| `TYPE-SHORT`           | 2     | Short position identifier       |

### Position Parameters

```clarity
{
  owner: principal,
  position-type: uint,
  size: uint,
  entry-price: uint,
  leverage: uint,
  collateral: uint,
  liquidation-price: uint,
  is-liquidated: bool
}
```

## System Workflow

### Position Lifecycle

1. **Collateral Deposit**

   - Users deposit STX into smart contract
   - Minimum 150% collateral ratio maintained

2. **Position Opening**

   ```clarity
   (open-position uint uint uint)
   ```

   - Specify position type (long/short)
   - Set position size and leverage
   - Collateral locked based on:
     ```math
     Required Collateral = (Position Size × Entry Price) / Leverage
     ```

3. **Price Monitoring**

   - Oracle updates asset price
   - Liquidation price calculated:
     - **Long**: `Entry Price × (1 - 1/Leverage)`
     - **Short**: `Entry Price × (1 + 1/Leverage)`

4. **Position Closure**
   - Manual closure by owner
   - Automatic liquidation when:
     - Price ≤ Liquidation Price (Long)
     - Price ≥ Liquidation Price (Short)

## Smart Contract Functions

### Core Operations

| Function              | Parameters             | Description                                  |
| --------------------- | ---------------------- | -------------------------------------------- |
| `deposit-collateral`  | (amount: uint)         | Add STX to user balance                      |
| `withdraw-collateral` | (amount: uint)         | Remove STX from balance                      |
| `open-position`       | (type, size, leverage) | Create new leveraged position                |
| `close-position`      | (position-id)          | Manually settle position                     |
| `liquidate-position`  | (position-id)          | Force liquidate undercollateralized position |

### Price Oracle

| Function            | Description                  |
| ------------------- | ---------------------------- |
| `update-price`      | Admin price update (testnet) |
| `get-current-price` | Read current market price    |

### Position Management

```clarity
;; Calculate liquidation price
(calculate-liquidation-price uint uint uint)

;; Check liquidation status
(is-liquidatable uint)

;; Get position details
(get-position uint)
```

## Liquidation Mechanics

### Liquidation Process

1. Continuous price monitoring
2. Position health check:
   ```clarity
   (if (is-liquidatable position-id)
   ```
3. Liquidator incentive distribution:
   ```math
   Liquidation Fee = Collateral × 5%
   ```
4. Remaining collateral returned to position owner

### Liquidation Formula

**Long Positions**

```math
Liquidation Price = Entry Price × (1 - (1 / Leverage))
```

**Short Positions**

```math
Liquidation Price = Entry Price × (1 + (1 / Leverage))
```

## Security Model

### Key Protections

1. **Collateral Safeguards**

   - Minimum 150% collateral ratio
   - STX held in verifiable smart contract

2. **Contract Security**

   - Clarity's inherent safety features
   - Bitcoin-finalized transaction layer

3. **Administrative Controls**
   - Oracle override capability (testnet only)
   - Contract pause functionality

## Risk Considerations

1. **Market Risks**

   - High volatility exposure
   - Liquidation cascade potential

2. **System Risks**

   - Oracle price feed reliability
   - STX price volatility impact

3. **Technical Risks**
   - Smart contract vulnerabilities
   - Blockchain network latency

## Testnet Implementation

### Oracle Configuration

- Manual price updates via admin function
- Testnet-only admin controls:
  ```clarity
  (update-price uint)
  (set-contract-owner principal)
  ```

### Testing Parameters

| Parameter     | Test Value |
| ------------- | ---------- |
| Initial Price | 100 STX    |
| Position Size | 1000 units |
| Leverage      | 10x        |
