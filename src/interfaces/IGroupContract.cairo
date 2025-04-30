// Interface for the Group Contract
pub trait IGroupContract<TContractState> {
    /// Allows a user to join a group
    ///
    /// # Arguments
    /// - `group_id`: The unique identifier of the group
    /// - `member`: The address of the user joining the group
    fn join_group(ref self: TContractState, group_id: felt252, member: ContractAddress);
}
