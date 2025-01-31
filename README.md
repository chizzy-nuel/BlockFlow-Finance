# BlockFlow Finance

## Overview
BlockFlow Finance is a decentralized peer-to-peer lending protocol built on the Stacks blockchain. It enables users to create overcollateralized lending positions using STX as collateral, facilitating trustless lending and borrowing operations with automated liquidation processes.

## Features
- **Decentralized P2P Lending**: Direct peer-to-peer lending without intermediaries
- **Overcollateralized Positions**: Minimum 150% collateralization ratio for safety
- **Flexible Terms**: Customizable loan amounts, durations, and interest rates
- **Automated Payments**: Structured repayment tracking with scheduled installments
- **Smart Liquidations**: Automatic liquidation triggers when positions become unsafe
- **Late Payment Handling**: Built-in fee system for missed payments
- **Admin Controls**: Adjustable safety parameters and protocol management

## Technical Specifications

### Core Constants
- Blocks Per Day: 144 (approximate)
- Default Fee Rate: 10% for late payments
- Margin Call Ratio: 130% (liquidation threshold)
- Initial Safety Margin: 150% (minimum collateralization)

### Position States
- `OPEN`: Position created, awaiting funding
- `FUNDED`: Active position with a creditor
- `COMPLETED`: Successfully repaid position
- `SEIZED`: Liquidated due to insufficient collateral
- `FAILED`: Defaulted position

## Smart Contract Functions

### User Functions

#### Opening a Position
```clarity
(define-public (open-credit-line (amount uint) (security uint) (rate uint) (term uint) (frequency uint)))
```
Creates a new lending position with specified parameters:
- `amount`: Desired credit amount in STX
- `security`: Collateral amount in STX
- `rate`: Interest rate (in basis points)
- `term`: Duration in blocks
- `frequency`: Payment interval in blocks

#### Funding a Position
```clarity
(define-public (fund-position (position-id uint)))
```
Allows lenders to fund open positions, initiating the credit line.

#### Making Payments
```clarity
(define-public (process-payment (position-id uint)))
```
Processes repayments for active positions, including any late fees if applicable.

#### Liquidation
```clarity
(define-public (liquidate-position (position-id uint)))
```
Executes liquidation for positions below the safety threshold.

### Read-Only Functions

#### Position Information
```clarity
(define-read-only (get-position (position-id uint)))
```
Retrieves complete position details.

#### Payment Schedule
```clarity
(define-read-only (get-payment-info (position-id uint)))
```
Retrieves payment schedule and history.

#### Position Health
```clarity
(define-read-only (get-position-health (position-id uint)))
```
Calculates current collateralization ratio.

## Error Handling

The protocol includes comprehensive error handling for various scenarios:
- `ERR-UNAUTHORIZED`: Unauthorized access attempt
- `ERR-LOW-BALANCE`: Insufficient funds
- `ERR-NO-CREDIT-LINE`: Invalid position ID
- `ERR-LOW-COLLATERAL`: Insufficient collateral
- `ERR-NOT-MATURED`: Premature liquidation attempt
- `ERR-INVALID-AMOUNT`: Invalid credit amount
- `ERR-HEALTHY-POSITION`: Unnecessary liquidation attempt

## Security Considerations

### Collateral Management
- All collateral is held by the contract itself
- Automated liquidation process protects lenders
- Overcollateralization requirement provides safety margin

### Access Control
- Function-level authorization checks
- Admin-only functions for protocol parameters
- Creditor/debtor-specific operation restrictions

## Development Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks blockchain development environment
- Node.js and NPM (for testing tools)

### Local Testing
1. Clone the repository
2. Install dependencies
```bash
clarinet requirements
```
3. Run tests
```bash
clarinet test
```

## Usage Examples

### Creating a New Position
```clarity
(contract-call? .blockflow-finance open-credit-line u1000000 u1500000 u5 u144 u12)
```
Creates a position requesting 1M STX with 1.5M STX collateral, 5% interest, 1-day term, payments every 12 blocks.

### Making a Payment
```clarity
(contract-call? .blockflow-finance process-payment u1)
```
Processes payment for position ID 1.

## Contributing

We welcome contributions! Please follow these steps:
1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions and support:
- Create an issue in the repository
- Join our Discord community
- Follow us on Twitter @BlockFlowFinance

## Acknowledgments

Special thanks to:
- Stacks Foundation
- Clarity language developers
- Our community contributors