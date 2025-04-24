

#[starknet::contract]
mod GroupSaving {

    use core::num::traits::Zero;
    use core::traits::Into;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::Map;
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use chainevents_contracts::base::types::{Group};
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

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
    member_contribution: Map<(ContractAddress, felt252), u128>, // Maps (member_address, group_id) to contribution amount
    member_last_contributed_round: Map<(ContractAddress, felt252), u32>, // Maps (member_address, group_id) to last contributed round
    member_payout_status: Map<(ContractAddress, felt252), bool>, // Maps (member_address, group_id) to payout status (whether they have collected)
    
    // Contribution Cycle State
    group_current_round: Map<felt252, u32>, // Maps group_id to current contribution round
    group_is_full: Map<felt252, bool>, // Maps group_id to a flag if the group is full
    group_is_active: Map<felt252, bool>, // Maps group_id to a flag if the group is active (contribution cycle running)
    group_is_completed: Map<felt252, bool>, // Maps group_id to a flag if the group has completed all rounds
    group_next_payout_index: Map<felt252, u32>, // Maps group_id to the next index in payout order

    // Group Membership
    group_members: Map<felt252, Array<ContractAddress>>, // Maps group_id to an array of member addresses
    group_payout_order: Map<felt252, Array<ContractAddress>>, // Maps group_id to an array of member addresses (payout order)
}



}