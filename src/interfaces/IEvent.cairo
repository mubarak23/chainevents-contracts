use chainevents_contracts::base::types::{EventDetails, EventRegistration};
use core::starknet::{ContractAddress, ClassHash};
#[starknet::interface]
pub trait IEvent<TContractState> {
    // EXTERNAL FUNCTION
    fn add_event(ref self: TContractState, name: ByteArray, location: ByteArray) -> u256;
    fn register_for_event(ref self: TContractState, event_id: u256);
    fn end_event_registration(
        ref self: TContractState, event_id: u256
    ); // only owner can closed an event
    fn rsvp_for_event(ref self: TContractState, event_id: u256);
    fn upgrade_event(ref self: TContractState, event_id: u256, paid_amount: u256);

    // GETTER FUNCTION
    fn event_details(self: @TContractState, event_id: u256) -> EventDetails;
    fn event_owner(self: @TContractState, event_id: u256) -> ContractAddress;
    fn attendee_event_details(self: @TContractState, event_id: u256) -> EventRegistration;
    fn attendees_registered(self: @TContractState, event_id: u256) -> u256;

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
