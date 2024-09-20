use core::serde::Serde;
use core::option::OptionTrait;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct EventDetailsParams {
    pub event_id: felt252,
    pub name: felt252,
    pub location: felt252,
    pub organizer: felt252
}
