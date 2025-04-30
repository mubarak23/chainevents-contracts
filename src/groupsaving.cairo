#[starknet::contract]
pub mod GroupSaving {
    use core::starknet::{ContractAddress, get_caller_address, storage::Map,};
    use core::num::traits::zero::Zero;
    use core::option::OptionTrait;
    use core::result::ResultTrait;
    use core::panic::Panic;

    const STATUS_INACTIVE: felt252 = 0;
    const STATUS_ACTIVE: felt252 = 1;
    const STATUS_COMPLETED: felt252 = 2;

    #[storage]
    struct Storage {
        groups: Map<felt252, Group>,
        contributions_received: Map<(felt252, felt252), felt252>,
        payout_collected: Map<(felt252, felt252), felt252>,
        payout_order: Map<(felt252, felt252), ContractAddress>,
        contributions_expected: Map<(felt252, felt252), felt252>,
    }

    struct Group {
        group_id: felt252,
        status: felt252,
        current_round: felt252,
        total_rounds: felt252,
        payout_order_len: felt252,
    }

    #[event]
    pub struct PayoutCollected {
        pub group_id: felt252,
        pub round: felt252,
        pub recipient: ContractAddress,
    }

    #[event]
    pub struct GroupCompleted {
        pub group_id: felt252,
    }

    #[external]
    fn collect_payout(ref self: ContractState, group_id: felt252, member: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == member, "Caller must be the member");

        let group = self.groups.read(group_id);
        assert(group.group_id != 0, "Group does not exist");
        assert(group.status == STATUS_ACTIVE, "Group is not active");

        let current_round = group.current_round;
        let received = self.contributions_received.read((group_id, current_round));
        let expected = self.contributions_expected.read((group_id, current_round));
        assert(received == expected, "Not all contributions received");

        let recipient = self.payout_order.read((group_id, current_round - 1));
        assert(recipient == member, "Member is not the designated recipient");

        let collected = self.payout_collected.read((group_id, current_round));
        assert(collected == 0, "Payout already collected for this round");

        self.payout_collected.write((group_id, current_round), 1);

        self.emit(PayoutCollected { group_id, round: current_round, recipient: member, });

        if current_round == group.total_rounds {
            self
                .groups
                .write(
                    group_id,
                    Group {
                        group_id,
                        status: STATUS_COMPLETED,
                        current_round,
                        total_rounds: group.total_rounds,
                        payout_order_len: group.payout_order_len,
                    }
                );

            self.emit(GroupCompleted { group_id });
        } else {
            self
                .groups
                .write(
                    group_id,
                    Group {
                        group_id,
                        status: STATUS_ACTIVE,
                        current_round: current_round + 1,
                        total_rounds: group.total_rounds,
                        payout_order_len: group.payout_order_len,
                    }
                );
        }
    }
}
