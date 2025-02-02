#[starknet::contract]
/// @title Fee Collector Contract
/// @notice A contract for fee base on paid events and number of user that purchase the ticket.
/// @dev Implements Ownable and Upgradeable components from OpenZeppelin
pub mod FeeCollector {
    use chainevents_contracts::base::types::{EventDetails, EventRegistration, EventType};
    use chainevents_contracts::base::errors::Errors::{
        ZERO_ADDRESS_CALLER, NOT_OWNER, CLOSED_EVENT, ALREADY_REGISTERED, NOT_REGISTERED,
        ALREADY_RSVP, INVALID_EVENT, EVENT_CLOSED,
    };
    use chainevents_contracts::interfaces::IFeeCollector::IFeeCollector;
    use core::starknet::{
        ContractAddress, get_caller_address, syscalls::deploy_syscall, ClassHash,
        get_block_timestamp,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry},
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    /// @notice Contract storage structure
    /// @dev Contains mappings for event management and tracking
    #[storage]
    struct Storage {
        event_ticket_fees: Map<
            ContractAddress, (u256, u256),
        >, // map<user_address, (event_id, fee_amount)>
        event_ticket_total_fee: Map<u256, u256>, // Map<event_id, total_fee_collected>
        total_fee_collected: u256,
        fee_percentage: u256,
    }

    /// @notice Events emitted by the contract
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FeesCollected: FeesCollected,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    /// @notice Event emitted when registration for an event is closed
    #[derive(Drop, starknet::Event)]
    pub struct FeesCollected {
        pub event_id: u256,
        pub fee_amount: u256,
        pub user_address: ContractAddress,
    }

    /// @notice Initializes the Events contract
    /// @dev Sets the initial event count to 0
    #[constructor]
    fn constructor(ref self: ContractState, fee_percentage: u256) {
        self.ownable.initializer(get_caller_address());
        self.total_fee_collected.write(0);
        self.fee_percentage.write(fee_percentage);
    }

    #[abi(embed_v0)]
    impl FeeCollectorImpl of IFeeCollector<ContractState> {
        fn collect_fee_for_event(ref self: TContractState, event_id: u256) {}
        fn total_fees_collector(self: @TContractState) -> u256 {
            self.total_fee_collected.read()
        }

        /// @notice Upgrades the contract implementation
        /// @param new_class_hash The new class hash to upgrade to
        /// @dev Only callable by owner
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}

#[cfg(test)]
mod tests {
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    use chainevents_contracts::interfaces::IFeeCollector::{
        IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait,
    };

    #[test]
    fn test_total_fees_collector() {
        // First declare and deploy a contract
        let contract = declare("FeeCollector").unwrap().contract_class();
        let mut fee_collector_constructor_data: Array<felt252> = array![];

        let fee_percentage: u256 = 10;

        fee_percentage.serialize(ref fee_collector_constructor_data);
        // Alternatively we could use `deploy_syscall` here
        let (contract_address, _) = contract.deploy(@fee_collector_constructor_data).unwrap();

        // Create a Dispatcher object that will allow interacting with the deployed contract
        let dispatcher = IFeeCollectorDispatcher { contract_address };

        // Call a view function of the contract
        let balance = dispatcher.total_fees_collector();
        assert(balance == 0, 'balance == 0');
    }
}
