use core::starknet::{ContractAddress};
// use starknet::testing::{declare, deploy, start_cheat_caller_address, stop_cheat_caller_address};

#[test]
fn test_collect_payout_success() {
    // Setup: deploy contract, create group, set contributions received and expected, set payout order
    // Simulate member calling collect_payout successfully
    // Assert payout_collected flag is set and group round advanced or completed
}

#[test]
fn test_collect_payout_fail_not_all_contributions_received() {
    // Setup group with contributions expected but not all received
    // Attempt collect_payout should fail with assertion
}

#[test]
fn test_collect_payout_fail_not_designated_recipient() {
    // Setup group with correct contributions received
    // Attempt collect_payout by non-recipient member should fail
}

#[test]
fn test_collect_payout_fail_duplicate_collection() {
    // Setup group and simulate successful collect_payout
    // Attempt collect_payout again in same round should fail
}

#[test]
fn test_collect_payout_fail_inactive_or_completed_group() {
    // Setup group with status inactive or completed
    // Attempt collect_payout should fail
}
