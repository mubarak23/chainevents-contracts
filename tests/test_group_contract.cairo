// Testing the Group Contract Implementation
#[test]
fn test_join_group() {
    let contract = contract();
    let group_id = 1;
    let max_members = 2;
    let member1 = ContractAddress::from(1);
    let member2 = ContractAddress::from(2);

    // Create a group
    contract.create_group(group_id, max_members);

    // Member 1 joins the group
    contract.join_group(group_id, member1);

    // Verify member 1 joined successfully
    let members = contract.get_group_members(group_id);
    assert(members.len() == 1, "Group should have 1 member.");
    assert(members.at(0) == member1, "Member 1 mismatch.");

    // Member 2 joins the group
    contract.join_group(group_id, member2);

    // Verify member 2 joined successfully
    let members = contract.get_group_members(group_id);
    assert(members.len() == 2, "Group should have 2 members.");
    assert(members.at(1) == member2, "Member 2 mismatch.");
}

#[test]
#[should_panic(expected = "Group is full.")]
fn test_join_full_group() {
    let contract = contract();
    let group_id = 1;
    let max_members = 1;
    let member1 = ContractAddress::from(1);
    let member2 = ContractAddress::from(2);

    // Create a group
    contract.create_group(group_id, max_members);

    // Member 1 joins the group
    contract.join_group(group_id, member1);

    // Member 2 attempts to join (should panic)
    contract.join_group(group_id, member2);
}
