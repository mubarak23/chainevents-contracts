# Project Description

Chain Event is a ticket management platform built on the Starknet blockchain, empowering users to effortlessly create, manage, and attend events as well as sell tickets.

The platform provides event organizers with tools to oversee events and mint Proof of Attendance NFTs for each attendee at the conclusion of the event.

## Development Setup

You will need to have Scarb and Starknet Foundry installed on your system. Refer to the documentations below:

- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/index.html)
- [Scarb](https://docs.swmansion.com/scarb/download.html)

To use this repository, first clone it:

```
git clone mubarak23/chainevents-contracts
cd chainevents-contracts
```

### Building contracts

To build the contracts, run the command:

```
scarb build
```

### Running Tests

To run the tests contained within the `tests` folder, run the command:

```
snforge test
```

# Contract Implementation

Create Event
Fetch my event (Backend Service)
Register for an event
RSVP for an event
Mint POA for an Event RSVP
Fetch all Register Attendee of an event

## Deep Implementation Details

Each event will have a uniqueId
Map create event function call with event
Map <eventOwnerAddress, EventDetailsStruct>

User can register for multiple event
Map Event UniqueId to Register user address – EventRegisterUser

Map Event UniqueId to Register user address – EventRSVPUsers

User the EventRSVPUsers Map to MINT POA NFT
