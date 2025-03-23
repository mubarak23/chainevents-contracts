use starknet::{ContractAddress, ClassHash};
use chainevents_contracts::base::types::TicketEventAccount;
// *************************************************************************
//                              INTERFACE of TICKET EVENT ACCOUNT (TBA)
// *************************************************************************

#[starknet::interface]
pub trait ITicketEventAccount<TState> {
    fn create_ticket_event_account_address(
        ref self: TState,
        registry_hash: felt252,
        implementation_hash: felt252,
        salt: felt252,
        recipient: ContractAddress,
        ticket_event_id: u256,
    ) -> ContractAddress;

    fn upgrade(ref self: TState, new_class_hash: ClassHash);
    // fn lock_ticket_event_account(ref self: TState, ticket_event_account_address: ContractAddress, lock_until: u64);
    fn update_ticket_event_nft(
        ref self: TState,
        ticket_event_nft_class_hash: ClassHash,
        ticket_event_nft_contract_address: ContractAddress
    );

    // Getters
    // fn get_ticket_even_account(self: @TState, ticket_event_account_address: ContractAddress) -> Campaign;
    // fn get_ticket_even_account_balance(self: @TState, ticket_event_account_address: ContractAddress) -> u256;
    // fn is_ticket_event_account_locked(self: @TState, ticket_event_account_address: ContractAddress) -> (bool, u64);
}
