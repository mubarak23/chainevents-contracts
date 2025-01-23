use core::starknet::{ClassHash};
/// @title Event Management Interface
/// @notice Interface for managing events, registrations, and attendance
/// @dev Includes functions for creating, managing events and handling registrations
#[starknet::interface]
pub trait IFeeCollector<TContractState> {
    fn collect_fee_for_event(ref self: TContractState, event_id: u256);
    fn total_fees_collector(self: @TContractState) -> u256;

    fn upgrade_contract(ref self: TContractState, new_class_hash: ClassHash);
}
