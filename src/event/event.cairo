#[starknet::contract]
pub mod Event {
    use core::num::traits::zero::Zero;
    use chainevents_contracts::base::types::{EventDetailsParams};
    use chainevents_contracts::base::errors::Errors::{ZERO_ADDRESS_OWNER, ZERO_ADDRESS_CALLER, NOT_OWNER};
    use chainevents_contracts::interfaces::IEvent::IEvent;
        use core::starknet::{
        ContractAddress, get_caller_address,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess}
    };

    #[storage]
    struct Storage {
        new_events: Map<u256, EventDetailsParams>, // map <eventId, EventDetailsParams>
        event_count: u256,
        registered_events: Map<u256, ContractAddress>, // map <eventId, RegisteredUser Address> 
        event_attendances: Map<u256, ContractAddress>  //  map <eventId, RegisteredUser Address> 
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
        user_address: ContractAddress
     }

    #[derive(Drop, starknet::Event)]
     struct EventAttendanceMark {
        event_id: u256,
        user_address: ContractAddress
     }

     #[constructor]
     fn constructor (ref self: ContractState) {
        self.event_count.write(0)
     }
     
}