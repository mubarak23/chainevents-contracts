mod GroupContract {
    use core::assert;
    // **Added the import for IGroupContract**
    use src::interfaces::IGroupContract;
    use starknet::ContractAddress;

    #[storage]
    struct ContractState {
        // Tracks the existence of groups
        group_ids: Map<felt252, bool>,
        // Tracks the number of members in each group
        group_member_counts: Map<felt252, u32>,
        // Tracks the maximum number of members allowed in a group
        group_max_members: Map<felt252, u32>,
        // Tracks the list of members for each group
        group_members_list: Map<(felt252, u32), ContractAddress>,
        // Tracks whether a group is full
        group_is_full: Map<felt252, bool>,
    }

    #[event]
    struct MemberJoined {
        group_id: felt252,
        member: ContractAddress,
    }

    // Implementing the IGroupContract trait for ContractState
    impl ContractState of IGroupContract<ContractState> {
        /// Allows a user to join a group
        ///
        /// # Arguments
        /// - `group_id`: The unique identifier of the group
        /// - `member`: The address of the user joining the group
        fn join_group(ref self: ContractState, group_id: felt252, member: ContractAddress) {
            // Ensure the group exists
            assert(self.group_ids.read(group_id), "Group does not exist.");

            // Verify the group is not full
            assert(!self.group_is_full.read(group_id), "Group is full.");

            // Ensure the user is not already a member of the group
            let member_count = self.group_member_counts.read(group_id);
            for i in 0..member_count {
                let existing_member = self.group_members_list.read((group_id, i));
                assert(existing_member != member, "User is already a member of the group.");
            }

            // Add the member to the group
            self.group_members_list.write((group_id, member_count), member);

            // Update the member count
            self.group_member_counts.write(group_id, member_count + 1);

            // Check if the group is now full
            if member_count + 1 == self.group_max_members.read(group_id) {
                self.group_is_full.write(group_id, true);
            }

            // Emit an event for the member joining
            emit
            MemberJoined { group_id, member };
        }
    }
}
