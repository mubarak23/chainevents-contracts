use chainevents_contracts::base::types::{EventDetails, EventRegistration};
use starknet::{ClassHash, ContractAddress};
/// @title Event Management Interface
/// @notice Interface for managing events, registrations, and attendance
/// @dev Includes functions for creating, managing events and handling registrations
#[starknet::interface]
pub trait IEvent<TContractState> {
    // EXTERNAL FUNCTION
    fn add_event(ref self: TContractState, name: ByteArray, location: ByteArray) -> u256;
    fn update_event_max_capacity(
        ref self: TContractState, event_id: u256, max_capacity: u256,
    ); // only owner can update max capacity
    fn register_for_event(ref self: TContractState, event_id: u256);
    fn open_event_registration(
        ref self: TContractState, event_id: u256,
    ); // only owner can open an event
    fn end_event_registration(
        ref self: TContractState, event_id: u256,
    ); // only owner can closed an event
    fn rsvp_for_event(ref self: TContractState, event_id: u256);
    fn upgrade_event(ref self: TContractState, event_id: u256, paid_amount: u256);
    fn unregister_from_event(ref self: TContractState, event_id: u256);
    fn pay_for_event(ref self: TContractState, event_id: u256);
    fn withdraw_paid_event_amount(ref self: TContractState, event_id: u256);
    fn join_event_waitlist(ref self: TContractState, event_id: u256);

    // GETTER FUNCTION
    fn event_details(self: @TContractState, event_id: u256) -> EventDetails;
    fn event_owner(self: @TContractState, event_id: u256) -> ContractAddress;
    fn attendee_event_details(self: @TContractState, event_id: u256) -> EventRegistration;
    fn attendees_registered(self: @TContractState, event_id: u256) -> u256;
    fn event_registration_count(self: @TContractState, event_id: u256) -> u256;
    fn fetch_user_paid_event(self: @TContractState, user: ContractAddress) -> (u256, u256);
    fn paid_event_ticket_counts(self: @TContractState, event_id: u256) -> u256;
    fn event_total_amount_paid(self: @TContractState, event_id: u256) -> u256;
    fn get_events(self: @TContractState) -> Array<EventDetails>;
    fn events_by_organizer(
        self: @TContractState, organizer: ContractAddress,
    ) -> Array<EventDetails>;
    fn fetch_all_attendees_on_event(
        self: @TContractState, event_id: u256,
    ) -> Array<EventRegistration>;
    fn get_open_events(self: @TContractState) -> Array<EventDetails>;
    fn get_closed_events(self: @TContractState) -> Array<EventDetails>;
    fn fetch_all_paid_events(self: @TContractState) -> Array<EventDetails>;
    fn fetch_all_unpaid_events(self: @TContractState) -> Array<EventDetails>;
    fn get_waitlist(self: @TContractState, event_id: u256) -> Array<ContractAddress>;

    fn mark_attendance(ref self: TContractState, event_id: u256, attendee: ContractAddress);

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
