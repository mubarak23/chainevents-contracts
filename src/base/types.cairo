use core::serde::Serde;
use core::option::OptionTrait;
use core::starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct EventDetailsParams {
    pub event_id: u256,
    pub name: felt252,
    pub location: felt252,
    pub organizer: ContractAddress
}
