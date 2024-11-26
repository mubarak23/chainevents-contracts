use core::serde::Serde;
use core::option::OptionTrait;
use core::starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Clone)]
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

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct EventRegistration {
    pub attendee_address: ContractAddress,
    pub amount_paid: u256,
    pub has_rsvp: bool,
    pub nft_contract_address: ContractAddress,
    pub nft_token_id: u256,
    pub organizer: ContractAddress
}


#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum EventType {
    Free,
    Paid
}
