#[starknet::contract]
mod GroupSaving {
    use chainevents_contracts::base::errors::Errors::{
        DUPLICATE_ADDRESS, GROUP_FULL, GROUP_ID_EXISTS, GROUP_NOT_ACCEPTING_MEMBERS,
        GROUP_NOT_FOUND, INVALID_CONTRIBUTION, INVALID_DURATION, INVALID_MAX_MEMBERS,
        MEMBER_ALREADY_IN_GROUP, PAYOUT_ORDER_MISMATCH,
    };
    use chainevents_contracts::base::types::Group;
    use chainevents_contracts::interfaces::IGroupSaving::IGroupSaving;
    use core::num::traits::Zero;
    use core::starknet::storage::{
        Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use core::starknet::syscalls::deploy_syscall;
    use core::starknet::{
        ClassHash, ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address,
    };
    use core::traits::Into;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Group Management
        group_counts: u256,
        groups: Map<felt252, Group>,
        // Member Contributions
        member_contribution: Map<(ContractAddress, felt252), u128>,
        member_last_contributed_round: Map<(ContractAddress, felt252), u32>,
        member_payout_status: Map<(ContractAddress, felt252), bool>,
        // Contribution Cycle State
        group_current_round: Map<felt252, u32>,
        group_is_full: Map<felt252, bool>,
        group_is_active: Map<felt252, bool>,
        group_is_completed: Map<felt252, bool>,
        group_next_payout_index: Map<felt252, u32>,
        // Group Membership
        group_members_list: Map<(felt252, u32), ContractAddress>, // Replaced group_members
        // Track existing group IDs
        group_ids: Map<felt252, bool>,
        group_payout_orders: Map<(felt252, u32), ContractAddress>,
        group_member_counts: Map<felt252, u32>,
        user_groups: Map<ContractAddress, felt252>,
    }

    /// @notice Events emitted by the contract
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        GroupCreated: GroupCreated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct GroupCreated {
        group_id: felt252,
        creator: ContractAddress,
        max_members: u32,
        contribution_amount: u128,
    }
    /// @notice Initializes the GroupSaving contract
    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl GroupSavingsImpl of IGroupSaving<ContractState> {
        // create a new group
        fn create_group(
            ref self: ContractState,
            group_id: felt252,
            creator: ContractAddress,
            max_members: u32,
            contribution_amount: u128,
            duration_in_days: u32,
            payout_order: Array<ContractAddress>,
        ) {
            // Validate group ID is unique
            assert(!self.group_ids.read(group_id), GROUP_ID_EXISTS);
            // Validate basic parameters
            assert(max_members > 0, INVALID_MAX_MEMBERS);
            assert(contribution_amount > 0, INVALID_CONTRIBUTION);
            assert(duration_in_days > 0, INVALID_DURATION);

            // Validate payout order matches max_members and has unique addresses
            assert(payout_order.len() == max_members.try_into().unwrap(), PAYOUT_ORDER_MISMATCH);
            self._validate_unique_addresses(payout_order.span());

            // let creator = get_caller_address();

            // Create new group
            let group = Group { creator, max_members, contribution_amount, duration_in_days };

            // Store group
            self.groups.write(group_id, group);

            // Mark group as existing
            self.group_ids.write(group_id, true);

            // set current round to 0
            self.group_current_round.write(group_id, 0);

            // set group to not active
            self.group_is_active.write(group_id, false);

            // set group to not full
            self.group_is_full.write(group_id, false);

            // set group to not completed
            self.group_is_completed.write(group_id, false);

            // update group counts by 1
            let current_group_count = self.group_counts.read();
            self.group_counts.write(current_group_count + 1);

            // Store payout order as individual entries
            for i in 0..payout_order.len() {
                let index: u32 = i.try_into().unwrap();
                self.group_payout_orders.write((group_id, index), *payout_order.at(i));
            }

            // Initialize empty members list
            self.group_member_counts.write(group_id, 0);

            // Update creator's group
            self.user_groups.write(creator, group_id);

            // Emit event
            self
                .emit(
                    Event::GroupCreated(
                        GroupCreated { group_id, creator, max_members, contribution_amount },
                    ),
                );
        }

        fn view_group(self: @ContractState, group_id: felt252) -> Group {
            let group = self.groups.read(group_id);
            group
        }

        fn total_groups(self: @ContractState) -> u256 {
            let total = self.group_counts.read();
            total
        }

        fn collect_payout(ref self: ContractState, group_id: felt252, member: ContractAddress) {}

        fn contribute(
            ref self: ContractState, group_id: felt252, member: ContractAddress, amount: u128,
        ) {}

        fn start_cycle(ref self: ContractState, group_id: felt252) {}

        fn join_group(ref self: ContractState, group_id: felt252, member: ContractAddress) {}

        fn total_fees_collected(self: @ContractState) -> u256 {
            0
        }

        fn upgrade_contract(ref self: ContractState, new_class_hash: ClassHash) {}

        fn get_current_round(self: @ContractState, group_id: felt252) -> u32 {
            // Validate group exists
            assert(self.group_ids.read(group_id), GROUP_NOT_FOUND);
            // Return current round (0 if not started)
            self.group_current_round.read(group_id)
        }

        fn is_group_full(self: @ContractState, group_id: felt252) -> bool {
            // Validate group exists
            assert(self.group_ids.read(group_id), GROUP_NOT_FOUND);
            // Return whether the group is full
            self.group_is_full.read(group_id)
        }

        fn get_group_members(self: @ContractState, group_id: felt252) -> Array<ContractAddress> {
            // Validate group exists
            assert(self.group_ids.read(group_id), GROUP_NOT_FOUND);

            // Get member count
            let count = self.group_member_counts.read(group_id);

            // Reconstruct array
            let mut members_array = array![];
            let mut i = 0;
            while i != count {
                let member = self.group_members_list.read((group_id, i));
                members_array.append(member);
                i += 1;
            }

            members_array
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // validate to confirm no duplicate address
        fn _validate_unique_addresses(ref self: ContractState, addresses: Span<ContractAddress>) {
            for i in 0..addresses.len() {
                let addr1 = *addresses.at(i);
                for j in i + 1..addresses.len() {
                    let addr2 = *addresses.at(j);
                    assert(addr1 != addr2, DUPLICATE_ADDRESS);
                }
            }
        }
    }
}
