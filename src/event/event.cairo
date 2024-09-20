#[starknet::contract]
pub mod Event {
    use core::num::traits::zero::Zero;
    use chainevents_contracts::base::types::{EventDetailsParams};
    use chainevents_contracts::base::errors::Errors::{
        ZERO_ADDRESS_OWNER, ZERO_ADDRESS_CALLER, NOT_OWNER
    };
    use chainevents_contracts::interfaces::IEvent::IEvent;
    use core::starknet::{
        ContractAddress, get_caller_address,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry}
    };

    #[storage]
    struct Storage {
        new_events: Map<u256, EventDetailsParams>, // map <eventId, EventDetailsParams>
        event_counts: u256,
        registered_events: Map<
            u256, Map<u256, ContractAddress>
        >, // map <eventId, RegisteredUser Address> 
        event_attendances: Map<u256, ContractAddress> //  map <eventId, RegisteredUser Address> 
    }

    // event
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewEventRegistered: NewEventRegistered,
        RegisteredForEvent: RegisteredForEvent,
        EventAttendanceMark: EventAttendanceMark
    }

    #[derive(Drop, starknet::Event)]
    struct NewEventRegistered {
        name: felt252,
        event_id: u256,
        location: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct RegisteredForEvent {
        event_id: u256,
        event_name: felt252,
        user_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct EventAttendanceMark {
        event_id: u256,
        user_address: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.event_counts.write(0)
    }

    #[abi(embed_v0)]
    impl EventImpl of IEvent<ContractState> {
        fn create_an_event(ref self: ContractState, name: felt252, location: felt252) {
            // ensure user cannot register multiple event with the same name,

            let event_counts = self.event_counts.read();
            let event_id = event_counts + 1;
            let event_orgainer = get_caller_address();
            let event_details = EventDetailsParams {
                name: name, location: location, event_id: event_id, organizer: event_orgainer
            };
            self.new_events.write(event_id, event_details);

            // dispatch events
            self.emit(NewEventRegistered { name: name, event_id: event_id, location: location });
        }

        fn register_for_event(ref self: ContractState, event_id: u256) {
            let event = self.new_events.read(event_id);
            let registered_user = get_caller_address();
            //  let all_registered_events = self.registered_events.read(event_id);
            let already_registered_user = self
                .registered_events
                .entry(event_id)
                .entry(event_id)
                .read();
            assert(already_registered_user == registered_user, 'Already Registered');

            self.registered_events.entry(event_id).entry(event_id).write(registered_user);

            self
                .emit(
                    RegisteredForEvent {
                        event_id: event_id, event_name: event.name, user_address: registered_user
                    }
                );
        }

        fn mark_event_attendance(ref self: ContractState, event_id: u256) {
            let has_registered = self.registered_events.entry(event_id).entry(event_id).read();
            let registered_user = get_caller_address();
            assert(has_registered != registered_user, 'Not Registered');

            // mark attendance
            self.event_attendances.write(event_id, registered_user);

            self.emit(EventAttendanceMark { event_id: event_id, user_address: registered_user });
        }

        fn attendees_event(self: @ContractState, event_id: u256) -> ContractAddress {
            self.event_attendances.read(event_id)
        }
        fn process_poa(ref self: ContractState, event_id: u256) -> bool {
            true
        }
    }
}
