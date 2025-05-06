use chainevents_contracts::base::types::Group;
use chainevents_contracts::group::groupsavings::GroupSaving;
use chainevents_contracts::group::groupsavings::GroupSaving::CycleStarted;
use chainevents_contracts::interfaces::IGroupSaving::{
    IGroupSavingDispatcher, IGroupSavingDispatcherTrait,
};
use core::array::ArrayTrait;
use core::felt252;
use core::traits::Into;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, EventSpyTrait, declare,
    spy_events, start_cheat_caller_address, stop_cheat_caller_address, store,
};
use starknet::{
    ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
};
fn contract() -> IGroupSavingDispatcher {
    let contract_class = declare("GroupSaving").unwrap().contract_class();

    let (contract_address, _) = contract_class.deploy(@array![].into()).unwrap();
    (IGroupSavingDispatcher { contract_address })
}


const creator: ContractAddress = 0x0.try_into().unwrap();
const member1: ContractAddress = 0x1.try_into().unwrap();
const member2: ContractAddress = 0x2.try_into().unwrap();
const member3: ContractAddress = 0x3.try_into().unwrap();
const member4: ContractAddress = 0x4.try_into().unwrap();
const member5: ContractAddress = 0x5.try_into().unwrap();

#[test]
fn test_create_group_success() {
    // Setup
    let mut contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let contribution_amount = 100;
    let duration_in_days = 30;
    let payout_order = array![member1, member2, member3];

    // Test
    contract
        .create_group(
            group_id, creator, max_members, contribution_amount, duration_in_days, payout_order,
        );

    // Verify
    let group = contract.view_group(group_id);
    assert(group.creator == creator, 'Creator should match');
    assert(group.max_members == max_members, 'Max members should match');
    assert(group.contribution_amount == contribution_amount, 'Contribution amount mismatch');
    assert(group.duration_in_days == duration_in_days, 'Duration should match');
}

#[test]
#[should_panic(expected: ('Group ID Already In Use',))]
fn test_create_group_with_existing_id() {
    // Setup
    let contract = contract();
    let group_id = 'group123';
    contract.create_group(group_id, creator, 3, 100, 30, array![member1, member2, member3]);
    // Test - should panic
    contract.create_group(group_id, creator, 2, 100, 30, array![member1, member2]);
}

#[test]
#[should_panic(expected: ('Maximum Member Must Be > 0',))]
fn test_create_group_with_zero_max_members() {
    let contract = contract();
    // Invalid max_members: 0
    contract.create_group('group123', creator, 0, 100, 30, array![member1]);
}

#[test]
#[should_panic(expected: ('Contribution Amount Must Be > 0',))]
fn test_create_group_with_zero_contribution() {
    let contract = contract();
    // Invalid contribution : 0
    contract.create_group('group123', creator, 3, 0, 30, array![member1, member5, member4]);
}

#[test]
#[should_panic(expected: ('Duration Must Be > 0',))]
fn test_create_group_with_zero_duration() {
    let contract = contract();
    // Invalid duration: 0
    contract.create_group('group123', creator, 3, 100, 0, array![member3, member5, member1]);
}

#[test]
#[should_panic(expected: ('Payout Order Mismatch',))]
fn test_create_group_with_payout_order_length_mismatch() {
    let contract = contract();
    // Max members: 3
    // Only 2 addresses for 3 max_members
    contract.create_group('group123', creator, 3, 100, 30, array![member5, member2]);
}

#[test]
#[should_panic]
fn test_create_group_with_duplicate_payout_addresses() {
    let contract = contract();
    // Duplicate address in order
    contract.create_group('group123', creator, 3, 100, 30, array![member1, member1, member2]);
}

#[test]
fn test_create_group_increments_group_count() {
    let contract = contract();
    let initial_count = contract.total_groups();

    contract.create_group('group1', creator, 3, 100, 30, array![member3, member4, member5]);

    assert(contract.total_groups() == initial_count + 1, 'Group count increment by 1');

    contract.create_group('group2', creator, 2, 100, 30, array![member1, member2]);

    assert(contract.total_groups() == initial_count + 2, 'Group count increment by 2');
}

#[test]
fn test_successful_create_group() {
    let contract = contract();
    let members = array![member1, member2, member3, member4, member5];
    contract.create_group('1', creator, 5, 10000, 30, members);
}

#[test]
#[should_panic]
fn test_failed_create_group_with_duplicate_id() {
    let contract = contract();
    let members = array![member1, member2, member3, member4, member5];
    let members1 = array![member1, member2];
    contract.create_group('1', creator, 5, 10000, 30, members);
    contract.create_group('1', creator, 2, 5000, 5, members1);
}


// Tests for getter functions
#[test]
fn test_get_current_round_active_group() {
    let contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let payout_order = array![member1, member2, member3];

    // Create group
    contract.create_group(group_id, creator, max_members, 100, 30, payout_order);

    // Add all members to make the group full
    contract.join_group(group_id, member1);
    contract.join_group(group_id, member2);
    contract.join_group(group_id, member3);

    // Start the cycle
    start_cheat_caller_address(contract.contract_address, creator);
    contract.start_cycle(group_id);

    // Test
    let round = contract.get_current_round(group_id);
    assert(round == 1, 'Current round should be 1');
}

#[test]
fn test_get_current_round_not_started() {
    let contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let payout_order = array![member1, member2, member3];

    // Create group (round defaults to 0)
    contract.create_group(group_id, creator, max_members, 100, 30, payout_order);

    // Test
    let round = contract.get_current_round(group_id);
    assert(round == 0, 'Current round should be 0');
}

#[test]
#[should_panic(expected: ('Group Not Found',))]
fn test_get_current_round_non_existent_group() {
    let contract = contract();
    let group_id = 'non_existent';

    // Test - should panic
    contract.get_current_round(group_id);
}

#[test]
fn test_is_group_full_not_full() {
    let contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let payout_order = array![member1, member2, member3];

    // Create group
    contract.create_group(group_id, creator, max_members, 100, 30, payout_order);

    // Add 2 members (not full)
    contract.join_group(group_id, member1);
    contract.join_group(group_id, member2);

    // Test
    let is_full = contract.is_group_full(group_id);
    assert(!is_full, 'Group should not be full');
}

#[test]
fn test_is_group_full_full() {
    let contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let payout_order = array![member1, member2, member3];

    // Create group
    contract.create_group(group_id, creator, max_members, 100, 30, payout_order);

    // Add 3 members (full)
    contract.join_group(group_id, member1);
    contract.join_group(group_id, member2);
    contract.join_group(group_id, member3);

    // Test
    let is_full = contract.is_group_full(group_id);
    assert(is_full, 'Group should be full');
}

#[test]
#[should_panic(expected: ('Group Not Found',))]
fn test_is_group_full_non_existent_group() {
    let contract = contract();
    let group_id = 'non_existent';

    // Test - should panic
    contract.is_group_full(group_id);
}

#[test]
fn test_get_group_members_with_members() {
    let contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let payout_order = array![member1, member2, member3];

    // Create group
    contract.create_group(group_id, creator, max_members, 100, 30, payout_order);

    // Add members
    contract.join_group(group_id, member1);
    contract.join_group(group_id, member2);

    // Test
    let returned_members = contract.get_group_members(group_id);
    assert(returned_members.len() == 2, 'Should return 2 members');
    assert(*returned_members.at(0) == member1, 'Member 1 mismatch');
    assert(*returned_members.at(1) == member2, 'Member 2 mismatch');
}

#[test]
fn test_get_group_members_empty_group() {
    let contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let payout_order = array![member1, member2, member3];

    // Create group (no members yet)
    contract.create_group(group_id, creator, max_members, 100, 30, payout_order);

    // Test
    let members = contract.get_group_members(group_id);
    assert(members.len() == 0, 'Should return empty array');
}

#[test]
#[should_panic(expected: ('Group Not Found',))]
fn test_get_group_members_non_existent_group() {
    let contract = contract();
    let group_id = 'non_existent';

    // Test - should panic
    contract.get_group_members(group_id);
}

#[test]
#[should_panic(expected: ('Member Already In Group',))]
fn test_get_group_members_duplicate_member() {
    let contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let payout_order = array![member1, member2, member3];

    // Create group
    contract.create_group(group_id, creator, max_members, 100, 30, payout_order);

    // Add member1
    contract.join_group(group_id, member1);

    // Try to add member1 again (should panic)
    contract.join_group(group_id, member1);
}

#[test]
fn test_start_cycle_success() {
    let contract = contract();
    let group_id = 'test_group';
    let max_members = 3;
    let payout_order = array![member1, member2, member3];

    // Create group
    contract.create_group(group_id, creator, max_members, 100, 30, payout_order);

    // Add all members to make the group full
    contract.join_group(group_id, member1);
    contract.join_group(group_id, member2);
    contract.join_group(group_id, member3);

    // Spy on events before action
    let mut spy = spy_events();

    // Test - start cycle
    start_cheat_caller_address(contract.contract_address, creator);
    contract.start_cycle(group_id);

    // Verify event
    let expected_event = GroupSaving::Event::CycleStarted(CycleStarted { group_id });

    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);

    // Verify
    assert(contract.is_group_active(group_id), 'Group should be active');
    assert(contract.get_current_round(group_id) == 1, 'Current round should be 1');
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Group Not Found',))]
fn test_start_cycle_non_existent_group() {
    let contract = contract();
    contract.start_cycle('non_existent');
}

// #[test]
// #[should_panic(expected: ('Group RoundS Already Completed',))]
// fn test_start_cycle_already_completed_group() {
//     let contract = contract();
//     let group_id = 'completed_group';
//     let payout_order = array![member1, member2];

//     // Setup - create group and join members
//     contract.create_group(group_id, creator, 2, 100, 30, payout_order);
//     contract.join_group(group_id, member1);
//     contract.join_group(group_id, member2);

//     // Manually mark group as completed (would normally happen after all rounds)
//     // This is a workaround for the test since we don't have a real cycle completion logic
//     start_cheat_caller_address(contract.contract_address, creator);
//     contract.mark_group_completed_for_testing(group_id);

//     // Attempt to start cycle
//     contract.start_cycle(group_id);
//     stop_cheat_caller_address(creator);
// }

#[test]
#[should_panic(expected: ('Group Is Not Yet Full',))]
fn test_start_cycle_not_full() {
    let contract = contract();
    let group_id = 'test_group';
    let payout_order = array![member1, member2, member3];

    contract.create_group(group_id, creator, 3, 100, 30, payout_order);

    // Don't join all members
    contract.join_group(group_id, member1);
    contract.join_group(group_id, member2);

    start_cheat_caller_address(contract.contract_address, creator);
    contract.start_cycle(group_id);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Group Is Already Active',))]
fn test_start_cycle_already_active() {
    let contract = contract();
    let group_id = 'test_group';

    contract.create_group(group_id, creator, 2, 100, 30, array![member1, member2]);
    contract.join_group(group_id, member1);
    contract.join_group(group_id, member2);

    start_cheat_caller_address(contract.contract_address, creator);
    contract.start_cycle(group_id);
    // Try to start again
    contract.start_cycle(group_id);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Caller Is Not Group Creator',))]
fn test_start_cycle_non_creator() {
    let contract = contract();
    let group_id = 'test_group';
    contract.create_group(group_id, creator, 2, 100, 30, array![member1, member2]);
    contract.join_group(group_id, member1);
    contract.join_group(group_id, member2);

    contract.start_cycle(group_id);
}
