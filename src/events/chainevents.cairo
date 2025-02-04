#[starknet::contract]
/// @title Events Management Contract
/// @notice A contract for creating and managing events with registration and attendance tracking
/// @dev Implements Ownable and Upgradeable components from OpenZeppelin
pub mod ChainEvents {
    use core::num::traits::zero::Zero;
    use chainevents_contracts::base::types::{EventDetails, EventRegistration, EventType};
    use chainevents_contracts::base::errors::Errors::{
        ZERO_ADDRESS_CALLER, NOT_OWNER, CLOSED_EVENT, ALREADY_REGISTERED, NOT_REGISTERED,
        ALREADY_RSVP, INVALID_EVENT, EVENT_NOT_CLOSED, EVENT_CLOSED, TRANSFER_FAILED,
        NOT_A_PAID_EVENT, PAYMENT_TOKEN_NOT_SET,
    };
    use chainevents_contracts::interfaces::IEvent::IEvent;
    use core::starknet::{
        ContractAddress, get_caller_address, syscalls::deploy_syscall, ClassHash,
        get_block_timestamp, get_contract_address, contract_address_const,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry},
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
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
        event_owners: Map<u256, ContractAddress>, // map(event_id, eventOwnerAddress)
        event_counts: u256,
        event_details: Map<u256, EventDetails>, // map(event_id, EventDetailsParams)
        event_registrations: Map<
            (ContractAddress, u256), bool,
        >, // map<(attendeeAddress, event_id), bool> -> true means that the attende is registered to the event
        attendee_event_details: Map<
            (u256, ContractAddress), EventRegistration,
        >, // map <(event_id, attendeeAddress), EventRegistration>
        attendee_event_addresses: Map<
            (u256, u256), ContractAddress,
        >, // map <(event_id, registration_index), attendee_address>
        // paid_events: Map<
        //     (ContractAddress, u256), u256
        // >, // map<(attendeeAddress, event_id), amount_paid>
        registered_attendees: Map<u256, u256>, // map<event_id, registered_attendees_count>
        attendee_event_registration_counts: Map<u256, u256>, // map<event_id, registration_count>
        paid_events: Map<
            ContractAddress, (u256, u256),
        >, // map<user_address, (event_id, amount_paid)>
        paid_events_amount: Map<u256, u256>, // map<event_id, total_amount>
        paid_event_ticket_count: Map<u256, u256>, // map<event_id, count_number_of_ticket>
        event_payment_token: ContractAddress,
    }

    /// @notice Events emitted by the contract
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NewEventAdded: NewEventAdded,
        RegisteredForEvent: RegisteredForEvent,
        EventAttendanceMark: EventAttendanceMark,
        UpgradedEvent: UpgradedEvent,
        OpenEventRegistration: OpenEventRegistration,
        EndEventRegistration: EndEventRegistration,
        RSVPForEvent: RSVPForEvent,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        UnregisteredEvent: UnregisteredEvent,
        EventPayment: EventPayment,
        WithdrawalMade: WithdrawalMade,
    }

    /// @notice Event emitted when a new event is created
    #[derive(Drop, starknet::Event)]
    pub struct NewEventAdded {
        pub name: ByteArray,
        pub event_id: u256,
        pub location: ByteArray,
        pub event_owner: ContractAddress,
    }

    /// @notice Event emitted when a user registers for an event
    #[derive(Drop, starknet::Event)]
    pub struct RegisteredForEvent {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub user_address: ContractAddress,
    }

    /// @notice Event emitted when registration for an event is opened
    #[derive(Drop, starknet::Event)]
    pub struct OpenEventRegistration {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub event_owner: ContractAddress,
    }

    /// @notice Event emitted when registration for an event is closed
    #[derive(Drop, starknet::Event)]
    pub struct EndEventRegistration {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub event_owner: ContractAddress,
    }

    /// @notice Event emitted when an attendee RSVPs for an event
    #[derive(Drop, starknet::Event)]
    pub struct RSVPForEvent {
        pub event_id: u256,
        pub attendee_address: ContractAddress,
    }

    /// @notice Event emitted when an event is upgraded (e.g., from free to paid)
    #[derive(Drop, starknet::Event)]
    pub struct UpgradedEvent {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub paid_amount: u256,
        pub event_type: EventType,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UnregisteredEvent {
        pub event_id: u256,
        pub user_address: ContractAddress,
    }


    #[derive(Drop, starknet::Event)]
    pub struct EventAttendanceMark {
        pub event_id: u256,
        pub user_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventPayment {
        pub event_id: u256,
        pub caller: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalMade {
        pub event_id: u256,
        pub event_organizer: ContractAddress,
        pub amount: u256,
    }
    /// @notice Initializes the Events contract
    /// @dev Sets the initial event count to 0
    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, payment_token_address: ContractAddress,
    ) {
        self.event_counts.write(0);
        self.ownable.initializer(owner);
        self.event_payment_token.write(payment_token_address);
    }

    #[abi(embed_v0)]
    impl EventsImpl of IEvent<ContractState> {
        /// @notice Creates a new event
        /// @param name Name of the event
        /// @param location Location of the event
        /// @return event_id The ID of the newly created event
        fn add_event(ref self: ContractState, name: ByteArray, location: ByteArray) -> u256 {
            let event_owner = get_caller_address();
            let event_name = name.clone();
            let event_location = location.clone();

            let event_id = self._create_event(event_name, event_location, event_owner);

            // emit event
            self
                .emit(
                    NewEventAdded {
                        event_id: event_id,
                        name: name,
                        location: location,
                        event_owner: event_owner,
                    },
                );
            event_id
        }

        /// @notice Registers a user for an event
        /// @param event_id The ID of the event to register for
        /// @dev Reverts if event is closed or user is already registered
        fn register_for_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();

            let event_name = self._register_for_event(caller.clone(), event_id.clone());

            // emit event for indexer
            self
                .emit(
                    RegisteredForEvent {
                        event_id: event_id, event_name: event_name, user_address: caller,
                    },
                );
        }

        fn unregister_from_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();

            self._unregister_from_event(event_id.clone(), caller.clone());

            // emit event for the indexers
            self.emit(UnregisteredEvent { event_id, user_address: caller });
        }

        /// @notice Opens registration for an event
        /// @param event_id The ID of the event to open registration for
        /// @dev Only callable by event owner
        fn open_event_registration(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();

            let event_name = self._open_event_registration(caller.clone(), event_id.clone());

            self.emit(OpenEventRegistration { event_id, event_name, event_owner: caller });
        }


        /// @notice Ends registration for an event
        /// @param event_id The ID of the event to close registration for
        /// @dev Only callable by event owner
        fn end_event_registration(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();

            let event_name = self._end_event_registration(caller.clone(), event_id.clone());

            self.emit(EndEventRegistration { event_id, event_name, event_owner: caller });
        }

        /// @notice Allows an attendee to RSVP for an event
        /// @param event_id The ID of the event to RSVP for
        /// @dev Reverts if user is not registered or has already RSVP'd
        fn rsvp_for_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();

            self._rsvp_for_event(event_id.clone(), caller.clone());

            self.emit(RSVPForEvent { event_id, attendee_address: caller });
        }

        /// @notice Upgrades an event from free to paid
        /// @param event_id The ID of the event to upgrade
        /// @param paid_amount The amount to charge for the event
        /// @dev Only callable by event owner
        fn upgrade_event(ref self: ContractState, event_id: u256, paid_amount: u256) {
            let caller = get_caller_address();
            let event_name = self
                ._upgrade_event(caller.clone(), event_id.clone(), paid_amount.clone());
            self
                .emit(
                    UpgradedEvent {
                        event_id: event_id,
                        event_name: event_name,
                        paid_amount: paid_amount,
                        event_type: EventType::Paid,
                    },
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
            let attendee_event_details = self._attendee_event_details(event_id.clone());

            attendee_event_details
        }

        /// @notice Gets the number of registered attendees for an event
        /// @param event_id The ID of the event to query
        /// @return Number of registered attendees
        /// @dev Only callable by event owner
        fn attendees_registered(self: @ContractState, event_id: u256) -> u256 {
            let caller = get_caller_address();
            // let event_owner = self.event_owners.read(event_id);
            // assert(caller == event_owner, NOT_OWNER);
            // self.registered_attendees.read(event_id)
            self._attendees_registered(event_id, caller)
        }

        /// @notice Gets the total registration count for an event
        /// @param event_id The ID of the event to query
        /// @return Total registration count
        /// @dev Only callable by event owner
        fn event_registration_count(self: @ContractState, event_id: u256) -> u256 {
            self._event_registration_count(event_id)
        }

        /// @notice Allows users to pay for an event
        /// @param event_id: The id of the event to be paid for
        fn pay_for_event(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();
            let event = self.event_details.entry(event_id).read();
            let attendee_event = self.attendee_event_details.entry((event_id, caller)).read();

            assert(caller == attendee_event.attendee_address, NOT_REGISTERED);
            assert(event.event_type == EventType::Paid, NOT_A_PAID_EVENT);
            assert(
                self.event_payment_token.read() != contract_address_const::<0>(),
                PAYMENT_TOKEN_NOT_SET,
            );

            self._pay_for_event(event.event_id, event.paid_amount, caller);

            self.emit(EventPayment { event_id: event.event_id, caller, amount: event.paid_amount });
        }

        /// @notice Allows the event owner to withdraw the paid amount for an event
        /// @param event_id The ID of the event to withdraw from
        /// @dev Only callable by event owner
        fn withdraw_paid_event_amount(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();
            let event_owner = self.event_owners.read(event_id);
            assert(!event_owner.is_zero(), INVALID_EVENT);
            assert(caller == event_owner, NOT_OWNER);

            let event_details = self.event_details.read(event_id);
            assert(event_details.is_closed, EVENT_NOT_CLOSED);

            let event_amount = self.paid_events_amount.read(event_id);
            let token = ERC20ABIDispatcher { contract_address: self.event_payment_token.read() };
            let transfer = token.transfer(event_owner, event_amount);
            assert(transfer, TRANSFER_FAILED);

            self
                .emit(
                    WithdrawalMade { event_id, event_organizer: event_owner, amount: event_amount }
                );
        }
        fn fetch_user_paid_event(self: @ContractState, user: ContractAddress) -> (u256, u256) {
            self._fetch_user_paid_event(user)
        }

        fn paid_event_ticket_counts(self: @ContractState, event_id: u256) -> u256 {
            self._paid_event_ticket_counts(event_id)
        }
        fn event_total_amount_paid(self: @ContractState, event_id: u256) -> u256 {
            self._event_total_amount_paid(event_id)
        }

        fn get_events(self: @ContractState) -> Array<EventDetails> {
            self._get_all_events()
        }

        /// @notice Upgrades the contract implementation
        /// @param new_class_hash The new class hash to upgrade to
        /// @dev Only callable by owner
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }

        /// @notice Get fetch all event created by the function caller to pay for an event
        /// @return Array of events created by the caller
        fn events_by_organizer(
            self: @ContractState, organizer: ContractAddress
        ) -> Array<EventDetails> {
            self._events_by_organizer(organizer)
        }


        /// @notice Get fetch all attendees by event
        /// @return Array of eventregistrations from contract adddresses
        fn fetch_all_attendees_on_event(
            self: @ContractState, event_id: u256,
        ) -> Array<EventRegistration> {
            self._fetch_all_attendees_on_event(event_id)
        }

        // get all events same way as the general get_events functions
        // initialize an array called open events
        // append events to the array if their is_closed property is false
        fn get_open_events(self: @ContractState) -> Array<EventDetails> {
            self._get_open_events()
        }

        fn get_closed_events(self: @ContractState) -> Array<EventDetails> {
            self._get_closed_events()
        }

        fn fetch_all_paid_events(self: @ContractState) -> Array<EventDetails> {
            self._fetch_all_paid_events()
        }

        fn fetch_all_unpaid_events(self: @ContractState) -> Array<EventDetails> {
            self._fetch_all_unpaid_events()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// @notice Deploys an NFT contract for an event
        /// @param event_nft_classhash The class haevents created by the callersh of the NFT
        /// contract to deploy @param event_id The ID of the event to associate with the NFT
        /// @return Address of the deployed NFT contract
        fn deploy_event_nft(
            ref self: ContractState, event_nft_classhash: ClassHash, event_id: u256,
        ) -> ContractAddress {
            let mut constructor_calldata: Array<felt252> = array![
                event_id.low.into(), event_id.high.into(),
            ];

            let (event_nft, _) = deploy_syscall(
                event_nft_classhash,
                get_block_timestamp().try_into().unwrap(),
                constructor_calldata.span(),
                false,
            )
                .unwrap();
            event_nft
        }

        /// @notice create new event
        /// @param event_name: Name of the event.
        /// @param event_location: the location the event will hold.
        /// @param event_owner: the chief organizer of the event.
        /// @return Address of the deployed NFT contract
        fn _create_event(
            ref self: ContractState,
            event_name: ByteArray,
            event_location: ByteArray,
            event_owner: ContractAddress,
        ) -> u256 {
            let event_id = self.event_counts.read() + 1;
            self.event_counts.write(event_id);

            let event_details = EventDetails {
                event_id: event_id,
                name: event_name,
                location: event_location,
                organizer: event_owner,
                total_register: 0,
                total_attendees: 0,
                event_type: EventType::Free,
                is_closed: false,
                paid_amount: 0,
            };

            // save the event details
            self.event_details.write(event_id, event_details);

            // save event owner
            self.event_owners.write(event_id, event_owner);

            event_id
        }

        fn _register_for_event(
            ref self: ContractState, caller: ContractAddress, event_id: u256,
        ) -> ByteArray {
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
                organizer: _event.organizer,
            };

            self.attendee_event_details.write((event_id, caller), _attendee_event_details);
            self
                .attendee_event_addresses
                .write((event_id, self.registered_attendees.read(event_id)), caller);

            self.event_registrations.write((caller, event_id), true);

            // update event attendees count.
            self.registered_attendees.write(event_id, self.registered_attendees.read(event_id) + 1);

            // Update registered attendees count
            let current_count = self.attendee_event_registration_counts.read(event_id);
            self.attendee_event_registration_counts.write(event_id, current_count + 1);
            _event.name
        }

        fn _unregister_from_event(
            ref self: ContractState, event_id: u256, caller: ContractAddress,
        ) {
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
                        organizer: zero_address,
                    },
                );

            self.event_registrations.write((caller, event_id), false);

            self.registered_attendees.write(event_id, self.registered_attendees.read(event_id) - 1);
            let current_count = self.attendee_event_registration_counts.read(event_id);
            self.attendee_event_registration_counts.write(event_id, current_count - 1);
        }

        fn _rsvp_for_event(ref self: ContractState, event_id: u256, caller: ContractAddress) {
            let attendee_event_details = self
                .attendee_event_details
                .entry((event_id, caller))
                .read();

            assert(attendee_event_details.attendee_address == caller, NOT_REGISTERED);
            assert(attendee_event_details.has_rsvp == false, ALREADY_RSVP);

            self.attendee_event_details.entry((event_id, caller)).has_rsvp.write(true);
        }

        fn _fetch_all_paid_events(self: @ContractState) -> Array<EventDetails> {
            let mut paid_events = ArrayTrait::new();
            let events_count = self.event_counts.read();
            let mut count: u256 = 1;

            while count <= events_count {
                let current_event: EventDetails = self.event_details.read(count);
                if current_event.event_type == EventType::Paid {
                    paid_events.append(current_event);
                };
                count += 1;
            };

            paid_events
        }

        fn _upgrade_event(
            ref self: ContractState, caller: ContractAddress, event_id: u256, paid_amount: u256,
        ) -> ByteArray {
            let event_owner = self.event_owners.read(event_id);
            assert(caller == event_owner, NOT_OWNER);
            let mut event_details = self.event_details.read(event_id);
            event_details.event_type = EventType::Paid;
            event_details.paid_amount = paid_amount;
            self.event_details.write(event_id, event_details.clone());
            event_details.name
        }

        fn _open_event_registration(
            ref self: ContractState, caller: ContractAddress, event_id: u256,
        ) -> ByteArray {
            let event_owner = self.event_owners.read(event_id);
            assert(!event_owner.is_zero(), INVALID_EVENT);
            assert(caller == event_owner, NOT_OWNER);

            let mut event_details = self.event_details.read(event_id);
            assert(event_details.is_closed, EVENT_NOT_CLOSED);
            event_details.is_closed = false;
            self.event_details.write(event_id, event_details.clone());
            event_details.name
        }

        fn _end_event_registration(
            ref self: ContractState, caller: ContractAddress, event_id: u256,
        ) -> ByteArray {
            let event_owner = self.event_owners.read(event_id);
            assert(!event_owner.is_zero(), INVALID_EVENT);
            assert(caller == event_owner, NOT_OWNER);

            let mut event_details = self.event_details.read(event_id);
            assert(!event_details.is_closed, EVENT_CLOSED);
            event_details.is_closed = true;
            self.event_details.write(event_id, event_details.clone());
            event_details.name
        }

        /// @notice Pays for an event by transferring from caller address to contract
        /// @param event_id The ID of the event to be paid for
        /// @param event_amount The class amount to be paid
        /// @param caller Address of the user calling the pay_for_event() function
        fn _pay_for_event(
            ref self: ContractState, event_id: u256, event_amount: u256, caller: ContractAddress,
        ) {
            let this_contract = get_contract_address();
            let token = ERC20ABIDispatcher { contract_address: self.event_payment_token.read() };
            let transfer = token.transfer_from(caller, this_contract, event_amount);

            assert(transfer, TRANSFER_FAILED);

            self.attendee_event_details.entry((event_id, caller)).amount_paid.write(event_amount);
            self.paid_events.entry(caller).write((event_id, event_amount));

            let total_event_amount_paid = self.paid_events_amount.entry(event_id).read();
            let prev_event_ticket_count = self.paid_event_ticket_count.entry(event_id).read();

            self.paid_events_amount.entry(event_id).write(total_event_amount_paid + event_amount);
            self.paid_event_ticket_count.entry(event_id).write(prev_event_ticket_count + 1);
        }

        fn _attendee_event_details(self: @ContractState, event_id: u256) -> EventRegistration {
            let register_event_id = self.event_registrations.read((get_caller_address(), event_id));

            assert(register_event_id, 'different event_id');

            let attendee_event_details = self
                .attendee_event_details
                .read((event_id, get_caller_address()));

            attendee_event_details
        }
        fn _attendees_registered(
            self: @ContractState, event_id: u256, caller: ContractAddress,
        ) -> u256 {
            let event_owner = self.event_owners.read(event_id);
            assert(caller == event_owner, NOT_OWNER);
            self.registered_attendees.read(event_id)
        }

        fn _event_registration_count(self: @ContractState, event_id: u256) -> u256 {
            let caller = get_caller_address();
            let event_owner = self.event_owners.read(event_id);
            assert(caller == event_owner, NOT_OWNER);
            self.attendee_event_registration_counts.read(event_id)
        }

        fn _get_all_events(self: @ContractState) -> Array<EventDetails> {
            let mut events = ArrayTrait::new();
            let events_count = self.event_counts.read();
            let mut count: u256 = 1;

            while count <= events_count {
                let event: EventDetails = self.event_details.read(count);
                events.append(event);
                count += 1;
            };

            events
        }


        fn _fetch_all_attendees_on_event(
            self: @ContractState, event_id: u256,
        ) -> Array<EventRegistration> {
            let mut attendees = ArrayTrait::<EventRegistration>::new();
            let mut count: u256 = 0;
            let total_attendees: u256 = self.registered_attendees.read(event_id);
            while count < total_attendees {
                let attendee_address = self.attendee_event_addresses.read((event_id, count));
                if !attendee_address.is_zero() {
                    let attendee_details = self
                        .attendee_event_details
                        .read((event_id, attendee_address));
                    attendees.append(attendee_details);
                }
                count += 1;
            };
            attendees
        }

        fn _events_by_organizer(
            self: @ContractState, organizer: ContractAddress
        ) -> Array<EventDetails> {
            //  let caller = get_caller_address();
            let mut caller_events = ArrayTrait::new();
            let mut count = 0;
            let event_count = self.event_counts.read();

            while count <= event_count {
                if self.event_owners.read(count) == organizer {
                    caller_events.append(self.event_details.read(count));
                }
                count += 1;
            };
            caller_events
        }

        fn _event_total_amount_paid(self: @ContractState, event_id: u256) -> u256 {
            let event_details = self.event_details.read(event_id);
            assert(event_details.event_id == event_id, INVALID_EVENT);
            let event = self.paid_events_amount.read(event_id);
            event
        }

        fn _get_closed_events(self: @ContractState) -> Array<EventDetails> {
            let mut closed_events = ArrayTrait::new();
            let events_count = self.event_counts.read();
            let mut count: u256 = 1;

            while count <= events_count {
                let current_event: EventDetails = self.event_details.read(count);
                if current_event.is_closed {
                    closed_events.append(current_event);
                };
                count += 1;
            };

            closed_events
        }

        fn _get_open_events(self: @ContractState) -> Array<EventDetails> {
            let mut open_events = ArrayTrait::new();
            let events_count = self.event_counts.read();
            let mut count: u256 = 1;

            while count <= events_count {
                let current_event: EventDetails = self.event_details.read(count);
                if !current_event.is_closed {
                    open_events.append(current_event);
                };
                count += 1;
            };

            open_events
        }

        fn _paid_event_ticket_counts(self: @ContractState, event_id: u256) -> u256 {
            let caller = get_caller_address();
            let (event_id, _) = self.paid_events.read(caller);
            self.paid_event_ticket_count.read(event_id)
        }

        fn _fetch_all_unpaid_events(self: @ContractState) -> Array<EventDetails> {
            let mut all_unpaid_events = ArrayTrait::new();
            let total_events_counts = self.event_counts.read();

            let mut count: u256 = 1;

            while count <= total_events_counts {
                let current_event = self.event_details.read(count);
                if current_event.event_type == EventType::Free {
                    all_unpaid_events.append(current_event);
                }
                count += 1;
            };
            all_unpaid_events
        }

        fn _fetch_user_paid_event(self: @ContractState, caller: ContractAddress) -> (u256, u256) {
            // read the paid event details.
            let (event_id, amount_paid) = self.paid_events.read(caller);

            // return event_id and amount paid.
            (event_id, amount_paid)
        }
    }
}
