use core::starknet::ContractAddress;

/// @title Event Details Structure
/// @notice Contains comprehensive information about an event
/// @dev Used to store and manage event-specific data
#[derive(Drop, Serde, starknet::Store, Clone, PartialEq)]
pub struct EventDetails {
    pub event_id: u256,
    pub name: ByteArray,
    pub location: ByteArray,
    pub organizer: ContractAddress,
    pub total_register: u256,
    pub total_attendees: u256,
    pub event_type: EventType,
    pub is_closed: bool,
    pub paid_amount: u256,
}

/// @title Event Registration Structure
/// @notice Contains details about an attendee's registration for an event
/// @dev Used to track individual registrations and associated NFTs
#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct EventRegistration {
    pub attendee_address: ContractAddress,
    pub amount_paid: u256,
    pub has_rsvp: bool,
    pub nft_contract_address: ContractAddress,
    pub nft_token_id: u256,
    pub organizer: ContractAddress,
}


/// @title Event Type Enumeration
/// @notice Defines the possible types of events
/// @dev Used to distinguish between free and paid events
#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum EventType {
    Free,
    Paid,
}
