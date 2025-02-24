use chainevents_contracts::base::types::{EventDetails, TicketEvent, EventRegistration};
use core::starknet::{ContractAddress, ClassHash};
/// @title Event Ticket Verification Interface
#[starknet::interface]
pub trait ITicketVerification<TContractState> {
    /// Exernal Functions
    fn create_ticket_event(
        ref self: TContractState,
        timestamp: u64,
        venue: felt252,
        transferable: bool,
        amount: u256,
        ticket_num: u256,
    ) -> u256;
    fn mint_ticket(ref self: TContractState, event_id: u256, to: ContractAddress) -> u256;
    fn verify_ticket(ref self: TContractState, ticket_id: u256) -> bool;
    /// Read Functions
    fn get_ticket_owner(self: @TContractState, ticket_id: u256) -> ContractAddress;
    fn is_ticket_used(self: @TContractState, ticket_id: u256) -> bool;
    fn get_event_details(self: @TContractState, event_id: u256) -> TicketEvent;
    fn verify_ticket_event(ref self: TContractState, ticket_id: u256) -> bool;
    fn transfer_ticket(ref self: TContractState, ticket_id: u256, to: ContractAddress);
    fn get_event_details(self: @TContractState, event_id: u256) -> TicketEvent;
}
