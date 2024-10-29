#[starknet::contract]
pub mod Events {
    use core::num::traits::zero::Zero;
    use chainevents_contracts::base::types::{EventDetails, EventRegistration, EventType};
    use chainevents_contracts::base::errors::Errors::{
        ZERO_ADDRESS_OWNER, ZERO_ADDRESS_CALLER, NOT_OWNER, CLOSED_EVENT, ALREADY_REGISTERED,
        NOT_REGISTERED, ALREADY_RSVP, INVALID_EVENT, EVENT_CLOSED
    };
    use chainevents_contracts::interfaces::IEvent::IEvent;
    use core::starknet::{
        ContractAddress, get_caller_address,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry}
    };

    #[storage]
    struct Storage {
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
        registered_attendees: Map<u256, u256> // map<event_id, registered_attendees_count>
    }

    // event
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NewEventAdded: NewEventAdded,
        RegisteredForEvent: RegisteredForEvent,
        EventAttendanceMark: EventAttendanceMark,
        UpgradedEvent: UpgradedEvent,
        EndEventRegistration: EndEventRegistration,
        RSVPForEvent: RSVPForEvent
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewEventAdded {
        pub name: ByteArray,
        pub event_id: u256,
        pub location: ByteArray,
        pub event_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct RegisteredForEvent {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub user_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct EndEventRegistration {
        pub event_id: u256,
        pub event_name: ByteArray,
        pub event_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct RSVPForEvent {
        pub event_id: u256,
        pub attendee_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct UpgradedEvent {
        pub event_id: u256,
        pub event_name: felt252,
        pub paid_amount: u256,
        pub event_type: EventType
    }


    #[derive(Drop, starknet::Event)]
    pub struct EventAttendanceMark {
        pub event_id: u256,
        pub user_address: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.event_counts.write(0)
    }

    #[abi(embed_v0)]
    impl EventsImpl of IEvent<ContractState> {
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

            self
                .emit(
                    RegisteredForEvent {
                        event_id: event_id, event_name: _event.name, user_address: caller
                    }
                );
        }


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
                is_closed: true,  // Set to true
                paid_amount: event_details.paid_amount,
            };
            
            self.event_details.write(event_id, updated_event_details);
        
            self.emit(EndEventRegistration {
                event_id,
                event_name: event_details.name,
                event_owner: caller,
            });
        }
    

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

        fn upgrade_event(ref self: ContractState, event_id: u256, paid_amount: u256) {}

        // GETTER FUNCTION
        fn event_details(self: @ContractState, event_id: u256) -> EventDetails {
            let event_detail = self.event_details.read(event_id);
            // let event_details = EventDetails {
            //     event_id: 1,
            //     name: event_detail.name,
            //     location: event_detail.location,
            //     organizer: event_detail.organizer,
            //     total_register: 1,
            //     total_attendees: 2,
            //     event_type: EventType::Free,
            //     is_closed: false,
            //     paid_amount: 0,
            // };
            event_detail
        }

        fn event_owner(self: @ContractState, event_id: u256) -> ContractAddress {
            let event_owners = self.event_owners.read(event_id);

            event_owners
        }

        fn attendee_event_details(self: @ContractState, event_id: u256) -> EventRegistration {
            let register_event_id = self.event_registrations.read(get_caller_address());

            assert(event_id == register_event_id, 'different event_id');

            let attendee_event_details = self
                .attendee_event_details
                .read((event_id, get_caller_address()));

            attendee_event_details
        }

        fn attendees_registered(self: @ContractState, event_id: u256) -> u256 {
            let caller = get_caller_address();
            let event_owner = self.event_owners.read(event_id);
            assert(caller == event_owner, NOT_OWNER);
            self.registered_attendees.read(event_id)
        }
    }
}
