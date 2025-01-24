#[starknet::contract]
/// @title Fee Collector Contract
/// @notice A contract for fee base on paid events and number of user that purchase the ticket.
/// @dev Implements Ownable and Upgradeable components from OpenZeppelin
pub mod FeeCollector {
    use chainevents_contracts::base::types::{EventDetails, EventRegistration, EventType};
    use chainevents_contracts::base::errors::Errors::{
        ZERO_ADDRESS_CALLER, NOT_OWNER, CLOSED_EVENT, ALREADY_REGISTERED, NOT_REGISTERED,
        ALREADY_RSVP, INVALID_EVENT, EVENT_CLOSED
    };
    use chainevents_contracts::interfaces::IFeeCollector::IFeeCollector;
    use core::starknet::{
        ContractAddress, get_caller_address, syscalls::deploy_syscall, ClassHash,
        get_block_timestamp,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry}
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

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
            ContractAddress, (u256, u256)
        >, // map<user_address, (event_id, fee_amount)>
        event_ticket_total_fee: Map<u256, u256>, // Map<event_id, total_fee_collected>
        total_fee_collected: u256,
        fee_percentage: u256,
        fee_token: IERC20Dispatcher,
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
        pub user_address: ContractAddress
    }

    /// @notice Initializes the Events contract
    /// @dev Sets the initial event count to 0
    #[constructor]
    fn constructor(
        ref self: ContractState, 
        fee_percentage: u256,
        fee_token_address: ContractAddress
    ) {
        self.ownable.initializer(get_caller_address());
        self.total_fee_collected.write(0);
        self.fee_percentage.write(fee_percentage);
        self.fee_token.write(IERC20Dispatcher { contract_address: fee_token_address });
    }

    #[abi(embed_v0)]
    impl FeeCollectorImpl of IFeeCollector<ContractState> {
        fn collect_fee_for_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();
            
            // Verify event
            let event = self.event_details.read(event_id);
            assert(event.event_type == EventType::Paid, 'Event is not paid');
            assert(!event.is_closed, 'Event is closed');
            
            // Calculate fee
            let fee_percentage = self.fee_percentage.read();
            let fee_amount = (event.paid_amount * fee_percentage) / 10000; // Base points (10000 = 100%)
            
            let fee_token = self.fee_token.read();
            
            // Transfer
            fee_token.transfer_from(caller, get_contract_address(), fee_amount);
            
            //Update storage
            self.event_ticket_fees.write(caller, (event_id, fee_amount));
            let current_total = self.event_ticket_total_fee.read(event_id);
            self.event_ticket_total_fee.write(event_id, current_total + fee_amount);
            self.total_fee_collected.write(self.total_fee_collected.read() + fee_amount);
            
            // Emitir evento
            self.emit(FeesCollected { 
                event_id,
                fee_amount,
                user_address: caller 
            });
        }

        fn total_fees_collector(self: @ContractState) -> u256 {
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
