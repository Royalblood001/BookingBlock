# BookingBlock

A decentralized talent agency smart contract platform built on Stacks blockchain for managing artist bookings, payments, and dispute resolution.

## Overview

BookingBlock is a smart contract system that facilitates secure and transparent bookings between artists, venues, and agents. It handles the entire booking lifecycle, from initial booking creation to payment distribution and dispute resolution.

## Features

- **Secure Booking Management**
  - Create and track bookings between artists, venues, and agents
  - Automated commission calculations
  - Configurable booking durations
  - Maximum of 100 bookings per user

- **Financial Operations**
  - Automated payment distribution
  - Commission handling
  - Secure fund management
  - Refund mechanism

- **Booking Protection**
  - Built-in dispute resolution system
  - Booking extension capabilities
  - Cancellation management
  - Performance verification

- **Review System**
  - Post-booking review mechanism
  - Score-based rating (0-5)
  - Review status validation

## Technical Details

### Constants

- Minimum booking duration: 1 day (144 blocks)
- Maximum booking duration: 100 days (14,400 blocks)
- Minimum performance fee: 1,000 microSTX
- Maximum performance fee: 100,000,000,000 microSTX
- Default commission rate: 10%

### Core Functions

```clarity
;; Create a new booking
(create-booking (artist principal) (venue principal) (agent principal) (fee uint))

;; Process payment to artist
(pay-artist (id uint))

;; Handle refunds to venue
(refund-venue (id uint))

;; Manage disputes
(raise-dispute (id uint))
(resolve-dispute (id uint) (pay-to-artist bool))
```

## Error Codes

- `ERR-OWNER-ONLY (u100)`: Operation restricted to contract owner
- `ERR-UNAUTHORIZED (u101)`: Unauthorized access attempt
- `ERR-ALREADY-BOOKED (u104)`: Booking slot already taken
- `ERR-NOT-BOOKED (u105)`: Booking doesn't exist
- `ERR-INVALID-FEE (u107)`: Invalid fee amount
- `ERR-COMMISSION-TOO-HIGH (u108)`: Commission rate exceeds maximum

## Getting Started

1. Deploy the smart contract to the Stacks blockchain
2. Initialize commission rates and booking durations
3. Create bookings through the provided functions
4. Manage bookings using the available operations

## Security

The contract implements various security measures:
- Principal validation
- Fee range validation
- Status checks
- Authorization verification
- Booking limit enforcement

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Disclaimer

This smart contract is provided as-is. Users should perform their own security audit before using it in production.
```