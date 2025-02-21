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
        ticket_event: Map::<u256, TicketEvent>,
        // Contract owner
        owner: ContractAddress,
        // Counter for ticket IDs
        next_ticket_id: u256,
        // Counter for event IDs
        next_event_id: u256,
        ticket_event_counts: u256,
        ticket_event_nft_contract_address: ContractAddress,
        ticket_event_nft_class_hash: ClassHash,
    }

    /// @notice Events emitted by the contract
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TicketMinted: TicketMinted,
        TicketUsed: TicketUsed,
        TicketTransferred: TicketTransferred,
        TicketEventCreated: TicketEventCreated
    }

    #[derive(Drop, starknet::Event)]
    struct TicketMinted {
        ticket_id: u256,
        event_id: u256,
        owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct TicketUsed {
        ticket_id: u256,
        event_id: u256,
        user: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct TicketTransferred {
        ticket_id: u256,
        from: ContractAddress,
        to: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct TicketEventCreated {
        event_id: u256,
        timestamp: u64,
        venue: felt252,
        amont: u256,
    }

    /// @notice Initializes the Events contract
    /// @dev Sets the initial event count to 0
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        ticket_event_nft_class_hash: ClassHash,
        ticket_event_nft_contract_address: ContractAddress,
    ) {
        self.ticket_event_counts.write(0);
        self.ownable.initializer(owner);
        // add nft class hash
    // add nft contract address
    }


    #[abi(embed_v0)]
    impl TicketVerificationmpl of ITicketVerification<ContractState> {
        fn create_ticket_event(
            ref self: ContractState,
            timestamp: u64,
            venue: felt252,
            transferable: bool,
            amount: u256,
            ticket_num: u256,
        ) -> u256 {
            // return event_id
            1
        }
        fn mint_ticket(ref self: ContractState, event_id: u256, to: ContractAddress) -> u256 {
            // return ticket_id
            2
        }
        fn verify_ticket(ref self: ContractState, ticket_id: u256) -> bool {
            false
        }

        fn verify_ticket_event(ref self: ContractState, ticket_id: u256) -> bool {
            let ticket = self.ticket_events.read(ticket_id);
            let ticket_used = self.ticket_used.read(ticket_id);
            let ticket_owner = self.ticket_owners.read(ticket_id);
            assert_eq!(ticket_owner == get_caller_address(), "Callet not owner of the ticket");
            assert!(ticket != 0, "No ticket fouind");
            assert!(!ticket_used, "Ticket already used");
            self.ticket_used.write(ticket_id, true);
            self
                .emit(
                    Event::TicketUsed(
                        TicketUsed {
                            ticket_id: ticket_id,
                            event_id: ticket.event_id,
                            user: get_caller_address()
                        }
                    )
                );
            true
        }

        fn transfer_ticket(ref self: ContractState, ticket_id: u256, to: ContractAddress) {
            let ticket = self.ticket_events.read(ticket_id);
            let ticket_owner = self.ticket_owners.read(ticket_id);
            let ticket_event = self.ticket_event.read(ticket.event_id);
            assert_eq!(ticket_owner == get_caller_address(), "Callet not owner of the ticket");
            assert!(ticket != 0, "No ticket fouind");
            assert!(!ticket_event.transferable, "Ticket not transferable");
            self.ticket_owners.write(ticket_id, to);
            self
                .emit(
                    Event::TicketTransferred(
                        TicketTransferred { ticket_id: ticket_id, from: ticket_owner, to: to }
                    )
                );
        }

        fn transfer_ticket(ref self: ContractState, ticket_id: u256, to: ContractAddress) {}

        /// Read Functions
        fn get_ticket_owner(self: @ContractState, ticket_id: u256) -> ContractAddress {}
        fn is_ticket_used(self: @ContractState, ticket_id: u256) -> bool {
            true
        }
        fn get_event_details(self: @ContractState, event_id: u256) -> TicketEvent {}
    }
}
