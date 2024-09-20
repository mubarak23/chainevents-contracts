use chainevents_contracts::base::types::{EventDetailsParams};
use core::starknet::ContractAddress;
#[starknet::interface]
pub trait IEvent<TContractState> {
    fn create_an_event(
        ref self: TContractState, name: felt252, location: felt252
    ); // map eventId to Event details - registerEVENTS
    fn register_for_event(
        ref self: TContractState, event_id: u256
    ); // map eventid to user regster address - regsiter
    fn mark_event_attendance(
        ref self: TContractState, event_id: u256
    ); // map event Id to user address - attendance
    fn attendees_event(self: @TContractState, event_id: u256) -> ContractAddress;
    fn process_poa(ref self: TContractState, event_id: u256) -> bool;
}

