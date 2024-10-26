// *************************************************************************
//                              Events TEST
// *************************************************************************
use core::option::OptionTrait;
use core::starknet::SyscallResultTrait;
use core::result::ResultTrait;
use core::traits::{TryInto, Into};
use starknet::{ContractAddress};

use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait,
};

use chainevents_contracts::interfaces::IEvent::{IEventDispatcher, IEventDispatcherTrait};

use chainevents_contracts::events::events::Events;
use chainevents_contracts::base::types::EventType;

const USER_ONE: felt252 = 'JOE';
const USER_TWO: felt252 = 'DOE';

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> ContractAddress {
    // deploy  events
    let events_class_hash = declare("Events").unwrap().contract_class();

    let mut events_constructor_calldata: Array<felt252> = array![];
    let (event_contract_address, _) = events_class_hash
        .deploy(@events_constructor_calldata)
        .unwrap();

    return (event_contract_address);
}

#[test]
fn test_add_event() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_end_event_registration() {
fn test_event_registration() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let user_one_address: ContractAddress = USER_ONE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, user_one_address);

    let event_id = event_dispatcher.add_event("ethereum dev meetup", "Main street 101");
    assert(event_id == 1, 'Event was not created');

    stop_cheat_caller_address(event_contract_address);

    let user_two_address: ContractAddress = USER_TWO.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, user_two_address);

    event_dispatcher.register_for_event(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    let attendee_registration_details = event_dispatcher.attendee_event_details(event_id);

    assert(
        attendee_registration_details.attendee_address == user_two_address,
        'attendee_address mismatch'
    );
    assert(
        attendee_registration_details.nft_contract_address == user_two_address,
        'nft_contract_address mismatch'
    );
    assert(attendee_registration_details.nft_token_id == 0, 'nft_token_id mismatch');
    assert(
        attendee_registration_details.organizer == event_details.organizer, 'organizer mismatch'
    );
    stop_cheat_caller_address(event_contract_address);
}

fn test_register_for_event() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    
    event_dispatcher.end_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);

    assert(event_details.is_closed == true, 'Event was not closed');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_end_event_registration_not_owner() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO.try_into().unwrap());
    event_dispatcher.end_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: ('INVALID_EVENT',))]
fn test_end_event_registration_invalid_event() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    event_dispatcher.end_event_registration(999);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: ('EVENT_CLOSED',))]
fn test_end_event_registration_already_closed() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    
    event_dispatcher.end_event_registration(event_id);
    
    event_dispatcher.end_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_event_details() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let user_address: ContractAddress = USER_ONE.try_into().unwrap();

    start_cheat_caller_address(event_contract_address, user_address);

    // Add event
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    // Retrieve event details
    let event_details = event_dispatcher.event_details(event_id);

    // Compare each field independently
    let id_matches = event_details.event_id == 1;
    let name_matches = event_details.name == "bitcoin dev meetup";
    let location_matches = event_details.location == "Dan Marna road";
    let organizer_matches = event_details.organizer == user_address;
    let total_register_matches = event_details.total_register == 1;
    let total_attendees_matches = event_details.total_attendees == 2;
    let event_type_matches = event_details.event_type == EventType::Free;
    let is_closed_matches = !event_details.is_closed;
    let paid_amount_matches = event_details.paid_amount == 0;

    // Assert each condition
    assert(id_matches, 'Event ID mismatch');
    assert(name_matches, 'Event name mismatch');
    assert(location_matches, 'Event location mismatch');
    assert(organizer_matches, 'Organizer mismatch');
    assert(total_register_matches, 'Total register should be 1');
    assert(total_attendees_matches, 'Total attendees should be 2');
    assert(event_type_matches, 'Event type mismatch');
    assert(is_closed_matches, 'Event should not be closed');
    assert(paid_amount_matches, 'Paid amount should be 0');

    stop_cheat_caller_address(event_contract_address);
}
