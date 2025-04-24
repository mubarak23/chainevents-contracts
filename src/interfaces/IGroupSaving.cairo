use core::starknet::{ClassHash};
/// @title Event Management Interface
/// @notice Interface for managing events, registrations, and attendance
/// @dev Includes functions for creating, managing events and handling registrations
#[starknet::interface]
pub trait IGroupSaving<TContractState> {
    fn create_group(
    ref self: TContractState,
    group_id: felt252,
    creator: ContractAddress,
    max_members: u32,
    contribution_amount: u128,
    duration_in_days: u32,
    payout_order: Array<ContractAddress>
);
    fn collect_payout(
    ref self: TContractState,
    group_id: felt252,
    member: ContractAddress
);
fn contribute(
    ref self: TContractState,
    group_id: felt252,
    member: ContractAddress,
    amount: u128
);

fn start_cycle(
    ref self: TContractState,
    group_id: felt252
);
   /// Join an existing group
    fn join_group(
        ref self: TContractState,
        group_id: felt252,
        member: ContractAddress
    );

    fn total_fees_collected(self: @TContractState) -> u256;

    fn upgrade_contract(ref self: TContractState, new_class_hash: ClassHash);
}
