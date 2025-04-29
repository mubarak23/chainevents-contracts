use core::num::traits::zero::Zero;
use core::starknet::{
    ContractAddress,
    storage::{Map, StorageMapReadAccess, StorageMapWriteAccess},
};

use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin_upgrades::UpgradeableComponent;

use crate::events::chainevents::{ChainEvents, WithdrawalMade};

#[storage]
struct RoscaGroup {
    group_id: u256,
    members: Array<ContractAddress>,
    payout_order: Array<ContractAddress>,
    contributions_received: Map<ContractAddress, bool>,
    current_round: u256,
    total_rounds: u256,
    status: u8, // 0 = Inactive, 1 = Active, 2 = Completed
    funds_withdrawn: Map<u256, bool>, // round -> withdrawn status
}

impl GroupsSavingImpl {
    fn collect_payout(ref self: ContractState, group_id: u256, member: ContractAddress) {
        // Validate group exists and is active
        let group = StorageMapReadAccess::read(self.rosca_groups, group_id);
        assert(group.status == 1, 'Group is not active');

        // Ensure all contributions for current round have been received
        let mut all_contributed = true;
        let mut i = 0;
        while i < StorageMapReadAccess::len(group.members) {
            let member_addr = StorageMapReadAccess::at(group.members, i);
            if !StorageMapReadAccess::read(group.contributions_received, member_addr) {
                all_contributed = false;
                break;
            }
            i += 1;
        }
        assert(all_contributed, 'Not all contributions received');

        // Confirm member is the designated recipient for this round
        let current_recipient = StorageMapReadAccess::at(group.payout_order, group.current_round - 1);
        assert(current_recipient == member, 'Not the current payout recipient');

        // Prevent duplicate collections
        assert(!StorageMapReadAccess::read(group.funds_withdrawn, group.current_round), 'Funds already withdrawn for this round');

        // Mark funds as withdrawn
        StorageMapWriteAccess::write(group.funds_withdrawn, group.current_round, true);

        // Transfer or mark funds withdrawn logic here (implementation depends on contract specifics)
        // For now, just emit an event
        self.emit(WithdrawalMade { event_id: group_id, event_organizer: member, amount: 0 });

        // Advance to next round or mark group as completed
        let mut updated_group = group;
        if group.current_round == group.total_rounds {
            updated_group.status = 2; // Completed
        } else {
            updated_group.current_round += 1;
            // Reset contributions_received for next round
            let mut j = 0;
            while j < StorageMapReadAccess::len(group.members) {
                let m = StorageMapReadAccess::at(group.members, j);
                StorageMapWriteAccess::write(updated_group.contributions_received, m, false);
                j += 1;
            }
        }

        // Write updated group state
        StorageMapWriteAccess::write(self.rosca_groups, group_id, updated_group);
    }
}
