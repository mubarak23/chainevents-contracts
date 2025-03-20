#[starknet::contract]
/// @title Events Ticket Contract
/// @notice A contract for creating and managing events with registration and attendance tracking
/// @dev Implements Ownable and Upgradeable components from OpenZeppelin
pub mod TicketVerification {
    use core::num::traits::zero::Zero;
    use chainevents_contracts::base::types::{EventDetails, EventRegistration, TicketEvent};
    use chainevents_contracts::base::errors::Errors::{
        ZERO_ADDRESS_CALLER, NOT_OWNER, CLOSED_EVENT, ALREADY_REGISTERED, NOT_REGISTERED,
        ALREADY_RSVP, INVALID_EVENT, EVENT_NOT_CLOSED, EVENT_CLOSED, TRANSFER_FAILED,
        NOT_A_PAID_EVENT, PAYMENT_TOKEN_NOT_SET,
    };

    use chainevents_contracts::interfaces::ITicketVerification::ITicketVerification;
    use core::starknet::{
        ContractAddress, get_caller_address, syscalls::deploy_syscall, ClassHash,
        get_block_timestamp, get_contract_address, contract_address_const,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry},
    };

    use openzeppelin::access::ownable::OwnableComponent;
    use chainevents_contracts::interfaces::IEventNFT::{
        IEventNFTDispatcher, IEventNFTDispatcherTrait
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_upgrades::UpgradeableComponent;
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
        // Mapping from ticket ID to owner address
        ticket_owners: Map::<u256, ContractAddress>,
        // Mapping from ticket ID to used status
        ticket_used: Map::<u256, bool>,
        // Mapping from ticket ID to event ID
        ticket_events: Map::<u256, u256>,
        // Mapping from event ID to event details (timestamp, venue)
        ticket_events_details: Map::<u256, TicketEvent>,
        // Contract owner
        owner: ContractAddress,
        // Counter for ticket IDs
        next_ticket_id: u256,
        // Counter for event IDs
        next_event_id: u256,
        payment_token_contract_address: ContractAddress,
        ticket_event_counts: u256,
        ticket_event_nft_contract_address: ContractAddress,
        ticket_event_nft_class_hash: ClassHash,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    /// @notice Events emitted by the contract
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TicketMinted: TicketMinted,
        TicketUsed: TicketUsed,
        TicketTransferred: TicketTransferred,
        TicketEventCreated: TicketEventCreated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TicketMinted {
        pub ticket_id: u256,
        pub event_id: u256,
        pub owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct TicketUsed {
        pub ticket_id: u256,
        pub event_id: u256,
        pub user: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct TicketTransferred {
        pub ticket_id: u256,
        pub from: ContractAddress,
        pub to: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct TicketEventCreated {
        pub event_id: u256,
        pub timestamp: u64,
        pub venue: felt252,
        pub amount: u256,
    }

    /// @notice Initializes the Events contract
    /// @dev Sets the initial event count to 0
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        ticket_event_nft_class_hash: ClassHash,
        ticket_event_nft_contract_address: ContractAddress,
        payment_token_contract_address: ContractAddress,
    ) {
        self.ticket_event_counts.write(0);
        self.next_ticket_id.write(0);
        self.next_event_id.write(0);
        self.ownable.initializer(owner);
        self.ticket_event_nft_class_hash.write(ticket_event_nft_class_hash);
        self.ticket_event_nft_contract_address.write(ticket_event_nft_contract_address);
        self.payment_token_contract_address.write(payment_token_contract_address);
    }


    #[abi(embed_v0)]
    impl TicketVerificationImpl of ITicketVerification<ContractState> {
        /// @notice Creates a new ticket event
        /// @param timestamp The scheduled time of the event
        /// @param venue The location where the event will be held
        /// @param transferable Whether tickets can be transferred between addresses
        /// @param amount The cost per ticket in payment token
        /// @param ticket_num The total number of tickets available
        /// @return event_id The ID of the newly created ticket event
        fn create_ticket_event(
            ref self: ContractState,
            timestamp: u64,
            venue: felt252,
            transferable: bool,
            amount: u256,
            ticket_num: u256,
        ) -> u256 {
            // Only owner can create events
            self.ownable.assert_only_owner();

            // Get and increment next event ID
            let event_id = self.next_event_id.read();
            self.next_event_id.write(event_id + 1);

            // Create new event
            let event = TicketEvent {
                timestamp: timestamp,
                venue: venue,
                transferable: transferable,
                active: true,
                amount: amount,
                ticket_num: ticket_num,
            };

            // Store event
            self.ticket_events_details.write(event_id, event);

            // Emit event
            self
                .emit(
                    TicketEventCreated {
                        event_id: event_id, timestamp: timestamp, venue: venue, amount: amount,
                    }
                );

            event_id
        }

        /// @notice Mints a new ticket for a specific event
        /// @param event_id The ID of the event for which to mint the ticket
        /// @param to The address that will receive the ticket
        /// @return ticket_id The ID of the newly minted ticket
        fn mint_ticket(ref self: ContractState, event_id: u256, to: ContractAddress) -> u256 {
            // Get event details
            let event = self.ticket_events_details.read(event_id);
            assert(event.active, 'Event is not active');

            // Get and increment next ticket ID
            let ticket_id = self.next_ticket_id.read();
            self.next_ticket_id.write(ticket_id + 1);

            // Get payment token from event
            let token = IERC20Dispatcher {
                contract_address: self.payment_token_contract_address.read()
            };

            // Check allowance
            let allowance = token.allowance(to, get_contract_address());
            assert(allowance >= event.amount, 'Insufficient allowance');

            // Check and process payment
            let success = token.transfer_from(to, get_contract_address(), event.amount);
            assert(success, 'Payment failed');

            // Mint the ticket NFT
            let nft = IEventNFTDispatcher {
                contract_address: self.ticket_event_nft_contract_address.read(),
            };
            nft.mint_nft(to);

            // Store ticket data
            self.ticket_owners.write(ticket_id, to);
            self.ticket_events.write(ticket_id, event_id);
            self.ticket_used.write(ticket_id, false);

            // Emit event
            self.emit(TicketMinted { ticket_id: ticket_id, event_id: event_id, owner: to });

            ticket_id
        }

        fn verify_ticket(ref self: ContractState, ticket_id: u256) -> bool {
            // IMPORTANT NOTE
            // This function was modified to being able to test the function "is_ticket_used".
            // Feel free to override with the real implementation when it's ready.
            self.ticket_used.entry(ticket_id).write(true);
            false
        }

        fn verify_ticket_event(ref self: ContractState, ticket_id: u256) -> bool {
            let ticket_used = self.ticket_used.read(ticket_id);
            let ticket_owner = self.ticket_owners.read(ticket_id);
            assert!(ticket_owner == get_caller_address(), "Callet not owner of the ticket");
            assert!(!ticket_used, "Ticket already used");

            let ticket = self.ticket_events.read(ticket_id);
            self.ticket_used.write(ticket_id, true);
            self
                .emit(
                    Event::TicketUsed(
                        TicketUsed {
                            ticket_id: ticket_id, event_id: ticket, user: get_caller_address()
                        }
                    )
                );
            true
        }

        fn transfer_ticket(ref self: ContractState, ticket_id: u256, to: ContractAddress) {
            let ticket = self.ticket_events.read(ticket_id);
            let ticket_owner = self.ticket_owners.read(ticket_id);
            let ticket_event = self.ticket_events_details.read(ticket);
            assert!(ticket_owner == get_caller_address(), "Callet not owner of the ticket");
            assert!(ticket_event.transferable, "Ticket not transferable");

            self.ticket_owners.write(ticket_id, to);
            self
                .emit(
                    Event::TicketTransferred(
                        TicketTransferred { ticket_id: ticket_id, from: ticket_owner, to: to }
                    )
                );
        }

        /// Read Functions
        fn get_ticket_owner(self: @ContractState, ticket_id: u256) -> ContractAddress {
            let ticket_owner = self.ticket_owners.read(ticket_id);
            assert(ticket_owner != contract_address_const::<0x0>(), 'Ticket not exists');
            ticket_owner
        }

        fn is_ticket_used(self: @ContractState, ticket_id: u256) -> bool {
            let ticket_owner = self.ticket_owners.read(ticket_id);
            assert(ticket_owner != contract_address_const::<0x0>(), 'Ticket not exists');
            let is_used = self.ticket_used.read(ticket_id);
            is_used
        }
        fn get_event_details(self: @ContractState, event_id: u256) -> TicketEvent {
            assert(event_id <= self.ticket_event_counts.read(), 'INVALID_EVENT_ID');
            self.ticket_events_details.read(event_id)
        }
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self._upgrade(new_class_hash)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// @notice Upgrades the contract implementation
        /// @param new_class_hash The new class hash to upgrade to
        /// @dev Only callable by owner
        fn _upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
