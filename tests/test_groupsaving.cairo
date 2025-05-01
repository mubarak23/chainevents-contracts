use core::starknet::{ContractAddress};
use crate::group::groupsaving::{GroupSaving, Storage, Group, STATUS_ACTIVE, STATUS_COMPLETED, STATUS_INACTIVE};
use core::option::OptionTrait;
use core::result::ResultTrait;

fn setup_group() -> (Storage, felt252) {
    let mut storage = Storage::default();
    let group_id = 1;
    let group = Group {
        group_id,
        status: STATUS_ACTIVE,
        current_round: 1,
        total_rounds: 3,
        payout_order_len: 3,
    };
    storage.groups.write(group_id, group);
    storage.contributions_expected.write((group_id, 1), 100);
    storage.contributions_received.write((group_id, 1), 100);
    storage.payout_order.write((group_id, 0), ContractAddress::default());
    storage.payout_collected.write((group_id, 1), 0);
    (storage, group_id)
}

#[test]
fn test_collect_payout_success() {
    let (mut storage, group_id) = setup_group();
    let member = ContractAddress::default();

    let mut contract = GroupSaving { storage };

    // Simulate collect_payout call
    contract.collect_payout(group_id, member);

    // Assert payout collected flag is set
    let collected = contract.storage.payout_collected.read((group_id, 1));
    assert(collected == 1, "Payout should be collected");

    // Assert group current round incremented
    let group = contract.storage.groups.read(group_id);
    assert(group.current_round == 2, "Current round should increment");
}

#[test]
fn test_collect_payout_fail_not_all_contributions_received() {
    let (mut storage, group_id) = setup_group();
    storage.contributions_received.write((group_id, 1), 50);
    let member = ContractAddress::default();

    let mut contract = GroupSaving { storage };

    let result = core::panic::catch_unwind(|| {
        contract.collect_payout(group_id, member);
    });
    assert(result.is_err(), "Should fail due to incomplete contributions");
}

#[test]
fn test_collect_payout_fail_not_designated_recipient() {
    let (mut storage, group_id) = setup_group();
    let member = ContractAddress::default();
    // Set payout_order to a different address
    storage.payout_order.write((group_id, 0), ContractAddress::from_felt252(1));

    let mut contract = GroupSaving { storage };

    let result = core::panic::catch_unwind(|| {
        contract.collect_payout(group_id, member);
    });
    assert(result.is_err(), "Should fail due to wrong recipient");
}

#[test]
fn test_collect_payout_fail_duplicate_collection() {
    let (mut storage, group_id) = setup_group();
    storage.payout_collected.write((group_id, 1), 1);
    let member = ContractAddress::default();

    let mut contract = GroupSaving { storage };

    let result = core::panic::catch_unwind(|| {
        contract.collect_payout(group_id, member);
    });
    assert(result.is_err(), "Should fail due to duplicate collection");
}

#[test]
fn test_collect_payout_fail_inactive_or_completed_group() {
    let (mut storage, group_id) = setup_group();
    let member = ContractAddress::default();

    // Test inactive group
    let mut contract = GroupSaving { storage: storage.clone() };
    let mut group = contract.storage.groups.read(group_id);
    group.status = STATUS_INACTIVE;
    contract.storage.groups.write(group_id, group);

    let result = core::panic::catch_unwind(|| {
        contract.collect_payout(group_id, member);
    });
    assert(result.is_err(), "Should fail due to inactive group");

    // Test completed group
    let mut contract = GroupSaving { storage };
    let mut group = contract.storage.groups.read(group_id);
    group.status = STATUS_COMPLETED;
    contract.storage.groups.write(group_id, group);

    let result = core::panic::catch_unwind(|| {
        contract.collect_payout(group_id, member);
    });
    assert(result.is_err(), "Should fail due to completed group");
}
