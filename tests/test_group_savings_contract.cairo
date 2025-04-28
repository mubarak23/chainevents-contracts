use chainevents_contracts::base::types::Group;
use chainevents_contracts::interfaces::IGroupSaving::{
    IGroupSavingDispatcher, IGroupSavingDispatcherTrait,
};
use core::array::ArrayTrait;
use core::felt252;
use core::traits::Into;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
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
