#[starknet::contract]
/// @title Fee Collector Contract
/// @notice A contract for fee base on paid events and number of user that purchase the ticket.
/// @dev Implements Ownable and Upgradeable components from OpenZeppelin
pub mod FeeCollector {
    use chainevents_contracts::base::errors::Errors::{EVENT_CLOSED, EVENT_NOT_PAID};
    use chainevents_contracts::base::types::{EventDetails, EventType};
    use chainevents_contracts::interfaces::IEvent::{IEventDispatcher, IEventDispatcherTrait};
    use chainevents_contracts::interfaces::IFeeCollector::IFeeCollector;
    use core::starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use core::starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;

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
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        event_ticket_fees: Map<
            ContractAddress, (u256, u256),
        >, // map<user_address, (event_id, fee_amount)>
        event_ticket_total_fee: Map<u256, u256>, // Map<event_id, total_fee_collected>
        total_fee_collected: u256,
        fee_percentage: u256,
        fee_token: IERC20Dispatcher,
        events_contract: IEventDispatcher,
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
    fn constructor(
        ref self: ContractState,
        fee_percentage: u256,
        fee_token_address: ContractAddress,
        events_contract_address: ContractAddress,
    ) {
        self.ownable.initializer(get_caller_address());
        self.total_fee_collected.write(0);
        self.fee_percentage.write(fee_percentage);
        self.fee_token.write(IERC20Dispatcher { contract_address: fee_token_address });
        self.events_contract.write(IEventDispatcher { contract_address: events_contract_address });
    }

    #[abi(embed_v0)]
    impl FeeCollectorImpl of IFeeCollector<ContractState> {
        fn collect_fee_for_event(ref self: ContractState, event_id: u256) {
            let caller: ContractAddress = get_caller_address();
            // Verify event
            let events_contract = self.events_contract.read();
            let event: EventDetails = events_contract.event_details(event_id);
            assert(event.event_type == EventType::Paid, EVENT_NOT_PAID);
            assert(!event.is_closed, EVENT_CLOSED);

            // Calculate fee
            let fee_percentage = self.fee_percentage.read();
            let fee_amount = (event.paid_amount * fee_percentage)
                / 10000; // Base points (10000 = 100%)

            let fee_token = self.fee_token.read();

            // Transfer
            fee_token.transfer_from(caller, get_contract_address(), fee_amount);

            //Update storage
            self.event_ticket_fees.write(caller, (event_id, fee_amount));
            let current_total = self.event_ticket_total_fee.read(event_id);
            self.event_ticket_total_fee.write(event_id, current_total + fee_amount);
            self.total_fee_collected.write(self.total_fee_collected.read() + fee_amount);

            self.emit(FeesCollected { event_id, fee_amount, user_address: caller });
        }

        fn total_fees_collected(self: @ContractState) -> u256 {
            self.total_fee_collected.read()
        }

        /// @notice Upgrades the contract implementation
        /// @param new_class_hash The new class hash to upgrade to
        /// @dev Only callable by owner
        fn upgrade_contract(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
