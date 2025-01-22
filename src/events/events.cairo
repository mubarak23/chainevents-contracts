#[starknet::contract]
/// @title Events Management Contract
/// @notice A contract for creating and managing events with registration and attendance tracking
/// @dev Implements Ownable and Upgradeable components from OpenZeppelin
pub mod Events {
    use core::num::traits::zero::Zero;
    use chainevents_contracts::base::types::{EventDetails, EventRegistration, EventType};
    use chainevents_contracts::base::errors::Errors::{
        ZERO_ADDRESS_CALLER, NOT_OWNER, CLOSED_EVENT, ALREADY_REGISTERED, NOT_REGISTERED,
        ALREADY_RSVP, INVALID_EVENT, EVENT_CLOSED, TRANSFER_FAILED
    };
    use chainevents_contracts::interfaces::IEvent::IEvent;
    use core::starknet::{
        ContractAddress, get_caller_address, syscalls::deploy_syscall, ClassHash,
        get_block_timestamp, get_contract_address,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry}
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

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
        // new_events: Map<u256, EventDetails>, // map <eventId, EventDetailsParams>
        // event_counts: u256,
        // registered_events: Map<
        //     u256, Map<u256, ContractAddress>
        // >, // map <eventId, RegisteredUser Address>
        // event_attendances: Map<u256, ContractAddress>, //  map <eventId, RegisteredUser Address>

        // STORAGE MAPPING REFACTOR
        event_owners: Map<u256, ContractAddress>, // map(event_id, eventOwnerAddress)
        event_counts: u256,
        event_details: Map<u256, EventDetails>, // map(event_id, EventDetailsParams)
        event_registrations: Map<ContractAddress, u256>, // map<attendeeAddress, event_id>
        attendee_event_details: Map<
            (u256, ContractAddress), EventRegistration
        >, // map <(event_id, attendeeAddress), EventRegistration>
        paid_events: Map<
            (ContractAddress, u256), u256
        >, // map<(attendeeAddress, event_id), amount_paid>
        registered_attendees: Map<u256, u256>, // map<event_id, registered_attendees_count>
        attendee_event_registration_counts: Map<u256, u256>, // map<event_id, registration_count>
        event_payment_token: ContractAddress
    }

    /// @notice Events emitted by the contract
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NewEventAdded: NewEventAdded,
        RegisteredForEvent: RegisteredForEvent,
        EventAttendanceMark: EventAttendanceMark,
        UpgradedEvent: UpgradedEvent,
        EndEventRegistration: EndEventRegistration,
        RSVPForEvent: RSVPForEvent,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        UnregisteredEvent: UnregisteredEvent,
        EventPayment: EventPayment,
    }

    /// @notice Event emitted when a new event is created
    #[derive(Drop, starknet::Event)]
    pub struct NewEventAdded {
        pub name: ByteArray,
        pub event_id: u256,
        pub location: ByteArray,
        pub event_owner: ContractAddress
    }

    /// @notice Event emitted when a user registers for an event
    #[derive(Drop, starknet::Event)]
    pub struct RegisteredForEvent {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub user_address: ContractAddress
    }

    /// @notice Event emitted when registration for an event is closed
    #[derive(Drop, starknet::Event)]
    pub struct EndEventRegistration {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub event_owner: ContractAddress
    }

    /// @notice Event emitted when an attendee RSVPs for an event
    #[derive(Drop, starknet::Event)]
    pub struct RSVPForEvent {
        pub event_id: u256,
        pub attendee_address: ContractAddress
    }

    /// @notice Event emitted when an event is upgraded (e.g., from free to paid)
    #[derive(Drop, starknet::Event)]
    pub struct UpgradedEvent {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub paid_amount: u256,
        pub event_type: EventType
    }

    #[derive(Drop, starknet::Event)]
    pub struct UnregisteredEvent {
        pub event_id: u256,
        pub user_address: ContractAddress
    }


    #[derive(Drop, starknet::Event)]
    pub struct EventAttendanceMark {
        pub event_id: u256,
        pub user_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventPayment {
        pub event_id: u256,
        pub caller: ContractAddress,
        pub amount: u256
    }

    /// @notice Initializes the Events contract
    /// @dev Sets the initial event count to 0
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.event_counts.write(0)
    }

    #[abi(embed_v0)]
    impl EventsImpl of IEvent<ContractState> {
        /// @notice Creates a new event
        /// @param name Name of the event
        /// @param location Location of the event
        /// @return event_id The ID of the newly created event
        fn add_event(ref self: ContractState, name: ByteArray, location: ByteArray) -> u256 {
            let event_owner = get_caller_address();
            let event_id = self.event_counts.read() + 1;
            self.event_counts.write(event_id);
            let event_name = name.clone();
            let event_location = location.clone();

            let event_details = EventDetails {
                event_id: event_id,
                name: event_name,
                location: event_location,
                organizer: event_owner,
                total_register: 1,
                total_attendees: 2,
                event_type: EventType::Free,
                is_closed: false,
                paid_amount: 0,
            };

            // save the event details
            self.event_details.write(event_id, event_details);

            // save event owner
            self.event_owners.write(event_id, event_owner);

            // register oraganizer for event

            // emit event
            self
                .emit(
                    NewEventAdded {
                        event_id: event_id,
                        name: name,
                        location: location,
                        event_owner: event_owner,
                    }
                );
            event_id
        }

        /// @notice Registers a user for an event
        /// @param event_id The ID of the event to register for
        /// @dev Reverts if event is closed or user is already registered
        fn register_for_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();

            let _event = self.event_details.read(event_id);

            let _attendee_registration = self.attendee_event_details.read((event_id, caller));

            assert(caller.is_non_zero(), ZERO_ADDRESS_CALLER);

            assert(!_attendee_registration.has_rsvp, ALREADY_REGISTERED);

            assert(!_event.is_closed, CLOSED_EVENT);

            let _attendee_event_details = EventRegistration {
                attendee_address: caller,
                amount_paid: 0,
                has_rsvp: false,
                nft_contract_address: caller, // nft contract address needed
                nft_token_id: 0,
                organizer: _event.organizer
            };

            self.attendee_event_details.write((event_id, caller), _attendee_event_details);

            self.event_registrations.write(caller, event_id);

            // update event attendees count.
            self.registered_attendees.write(event_id, self.registered_attendees.read(event_id) + 1);

            // Update registered attendees count
            let current_count = self.attendee_event_registration_counts.read(event_id);
            self.attendee_event_registration_counts.write(event_id, current_count + 1);

            self
                .emit(
                    RegisteredForEvent {
                        event_id: event_id, event_name: _event.name, user_address: caller
                    }
                );
        }

        fn unregister_from_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();
            let event = self.event_details.read(event_id);
            assert(!event.is_closed, CLOSED_EVENT);

            let attendee_registration = self.attendee_event_details.read((event_id, caller));
            assert(attendee_registration.attendee_address == caller, NOT_REGISTERED);

            let zero_address: ContractAddress = 0.try_into().unwrap();
            self
                .attendee_event_details
                .write(
                    (event_id, caller),
                    EventRegistration {
                        attendee_address: zero_address,
                        amount_paid: 0,
                        has_rsvp: false,
                        nft_contract_address: zero_address,
                        nft_token_id: 0,
                        organizer: zero_address
                    }
                );

            self.event_registrations.write(caller, 0);

            self.registered_attendees.write(event_id, self.registered_attendees.read(event_id) - 1);
            let current_count = self.attendee_event_registration_counts.read(event_id);
            self.attendee_event_registration_counts.write(event_id, current_count - 1);

            self.emit(UnregisteredEvent { event_id, user_address: caller });
        }


        /// @notice Ends registration for an event
        /// @param event_id The ID of the event to close registration for
        /// @dev Only callable by event owner
        fn end_event_registration(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();
            let event_owner = self.event_owners.read(event_id);
            assert(!event_owner.is_zero(), INVALID_EVENT);
            assert(caller == event_owner, NOT_OWNER);

            let event_details = self.event_details.read(event_id);
            assert(!event_details.is_closed, EVENT_CLOSED);

            let updated_event_details = EventDetails {
                event_id: event_details.event_id,
                name: event_details.name.clone(),
                location: event_details.location,
                organizer: event_details.organizer,
                total_register: event_details.total_register,
                total_attendees: event_details.total_attendees,
                event_type: event_details.event_type,
                is_closed: true, // Set to true
                paid_amount: event_details.paid_amount,
            };

            self.event_details.write(event_id, updated_event_details);

            self
                .emit(
                    EndEventRegistration {
                        event_id, event_name: event_details.name, event_owner: caller,
                    }
                );
        }

        /// @notice Allows an attendee to RSVP for an event
        /// @param event_id The ID of the event to RSVP for
        /// @dev Reverts if user is not registered or has already RSVP'd
        fn rsvp_for_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();

            let attendee_event_details = self
                .attendee_event_details
                .entry((event_id, caller))
                .read();

            assert(attendee_event_details.attendee_address == caller, NOT_REGISTERED);
            assert(attendee_event_details.has_rsvp == false, ALREADY_RSVP);

            self.attendee_event_details.entry((event_id, caller)).has_rsvp.write(true);

            self.emit(RSVPForEvent { event_id, attendee_address: caller, });
        }

        /// @notice Upgrades an event from free to paid
        /// @param event_id The ID of the event to upgrade
        /// @param paid_amount The amount to charge for the event
        /// @dev Only callable by event owner
        fn upgrade_event(ref self: ContractState, event_id: u256, paid_amount: u256) {
            let caller = get_caller_address();
            let event_owner = self.event_owners.read(event_id);
            assert(caller == event_owner, NOT_OWNER);
            let mut event_details = self.event_details.read(event_id);
            event_details.event_type = EventType::Paid;
            event_details.paid_amount = paid_amount;
            self.event_details.write(event_id, event_details.clone());
            self
                .emit(
                    UpgradedEvent {
                        event_id: event_id,
                        event_name: event_details.name,
                        paid_amount: paid_amount,
                        event_type: EventType::Paid,
                    }
                );
        }


        /// @notice Gets the details of an event
        /// @param event_id The ID of the event to query
        /// @return EventDetails struct containing event information
        fn event_details(self: @ContractState, event_id: u256) -> EventDetails {
            let event_detail = self.event_details.read(event_id);

            event_detail
        }

        /// @notice Gets the owner of an event
        /// @param event_id The ID of the event to query
        /// @return Address of the event owner
        fn event_owner(self: @ContractState, event_id: u256) -> ContractAddress {
            let event_owners = self.event_owners.read(event_id);

            event_owners
        }

        /// @notice Gets the registration details for an attendee
        /// @param event_id The ID of the event to query
        /// @return EventRegistration struct containing registration details
        fn attendee_event_details(self: @ContractState, event_id: u256) -> EventRegistration {
            let register_event_id = self.event_registrations.read(get_caller_address());

            assert(event_id == register_event_id, 'different event_id');

            let attendee_event_details = self
                .attendee_event_details
                .read((event_id, get_caller_address()));

            attendee_event_details
        }

        /// @notice Gets the number of registered attendees for an event
        /// @param event_id The ID of the event to query
        /// @return Number of registered attendees
        /// @dev Only callable by event owner
        fn attendees_registered(self: @ContractState, event_id: u256) -> u256 {
            let caller = get_caller_address();
            let event_owner = self.event_owners.read(event_id);
            assert(caller == event_owner, NOT_OWNER);
            self.registered_attendees.read(event_id)
        }

        /// @notice Gets the total registration count for an event
        /// @param event_id The ID of the event to query
        /// @return Total registration count
        /// @dev Only callable by event owner
        fn event_registration_count(self: @ContractState, event_id: u256) -> u256 {
            let caller = get_caller_address();
            let event_owner = self.event_owners.read(event_id);
            assert(caller == event_owner, NOT_OWNER);
            self.attendee_event_registration_counts.read(event_id)
        }

        /// @notice Upgrades the contract implementation
        /// @param new_class_hash The new class hash to upgrade to
        /// @dev Only callable by owner
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }

        /// @notice Allows users to pay for an event
        /// @param event_id: The id of the event to be paid for
        fn pay_for_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();
            let event = self.event_details.entry(event_id).read();
            let attendee_event = self.attendee_event_details.entry((event_id, caller)).read();

            assert(caller == attendee_event.attendee_address, NOT_REGISTERED);

            self._pay_for_event(event.event_id, event.paid_amount, caller);

            self.emit(
                EventPayment {
                    event_id: event.event_id,
                    caller,
                    amount: event.paid_amount
                }
            );
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// @notice Deploys an NFT contract for an event
        /// @param event_nft_classhash The class hash of the NFT contract to deploy
        /// @param event_id The ID of the event to associate with the NFT
        /// @return Address of the deployed NFT contract
        fn deploy_event_nft(
            ref self: ContractState, event_nft_classhash: ClassHash, event_id: u256
        ) -> ContractAddress {
            let mut constructor_calldata: Array<felt252> = array![
                event_id.low.into(), event_id.high.into()
            ];

            let (event_nft, _) = deploy_syscall(
                event_nft_classhash,
                get_block_timestamp().try_into().unwrap(),
                constructor_calldata.span(),
                false
            )
                .unwrap();
            event_nft
        }

        /// @notice Pays for an event by transferring from caller address to contract
        /// @param event_id The ID of the event to be paid for
        /// @param event_amount The class amount to be paid
        /// @param caller Address of the user calling the pay_for_event() function
        fn _pay_for_event(ref self: ContractState, event_id: u256, event_amount: u256, caller: ContractAddress) {
            let this_contract = get_contract_address();
            let token = ERC20ABIDispatcher {contract_address: self.event_payment_token.read()};
            let transfer = token.transfer_from(caller, this_contract, event_amount);

            assert(transfer, TRANSFER_FAILED);

            self.attendee_event_details.entry((event_id, caller)).amount_paid.write(event_amount);
        }
    }
}

