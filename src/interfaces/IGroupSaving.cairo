use chainevents_contracts::base::types::Group;
use core::starknet::{ClassHash, ContractAddress};
/// @title GroupSaving Management Interface
/// @notice Interface for managing group savings
/// @dev Includes functions for creating, managing group savings and handling members
#[starknet::interface]
pub trait IGroupSaving<TContractState> {
    fn create_group(
        ref self: TContractState,
        group_id: felt252,
        creator: ContractAddress,
        max_members: u32,
        contribution_amount: u128,
        duration_in_days: u32,
        payout_order: Array<ContractAddress>,
    );
    fn view_group(self: @TContractState, group_id: felt252) -> Group;
    fn total_groups(self: @TContractState) -> u256;
    fn collect_payout(ref self: TContractState, group_id: felt252, member: ContractAddress);
    fn contribute(
        ref self: TContractState, group_id: felt252, member: ContractAddress, amount: u128,
    );

    fn start_cycle(ref self: TContractState, group_id: felt252);
    /// Join an existing group
    fn join_group(ref self: TContractState, group_id: felt252, member: ContractAddress);

    fn total_fees_collected(self: @TContractState) -> u256;

    fn upgrade_contract(ref self: TContractState, new_class_hash: ClassHash);

    // Getterfunctions
    fn get_current_round(self: @TContractState, group_id: felt252) -> u32;
    fn is_group_full(self: @TContractState, group_id: felt252) -> bool;
    fn get_group_members(self: @TContractState, group_id: felt252) -> Array<ContractAddress>;
    fn is_group_active(self: @TContractState, group_id: felt252) -> bool;
}
