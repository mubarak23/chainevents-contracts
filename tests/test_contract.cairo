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
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait,
};

use chainevents_contracts::interfaces::IEvent::{IEventDispatcher, IEventDispatcherTrait};
use chainevents_contracts::events::events::Events;

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


    assert(attendee_registration_details.attendee_address == user_two_address, 'attendee_address mismatch');
    assert(attendee_registration_details.amount_paid == 0, 'amount_paid mismatch');
    assert(attendee_registration_details.has_rsvp == false, 'has_rsvp mismatch');
    assert(
        attendee_registration_details.nft_contract_address == user_two_address,
        'nft_contract_address mismatch'
    );
    assert(attendee_registration_details.nft_token_id == 0, 'nft_token_id mismatch');
    assert(attendee_registration_details.organizer == event_details.organizer, 'organizer mismatch');
    stop_cheat_caller_address(event_contract_address);
}

fn test_register_for_event() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");

    assert(event_id == 1, 'Event was not created');

    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO.try_into().unwrap());

    event_dispatcher.register_for_event(event_id);

    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'rsvp only for registered event')]
fn test_should_panic_on_rsvp_for_event_that_was_not_registered_for() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let caller: ContractAddress = starknet::contract_address_const::<0x123626789>();

    start_cheat_caller_address(event_contract_address, caller);

    let event_id: u256 = 1;

    event_dispatcher.rsvp_for_event(event_id);

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_rsvp_for_event_should_emit_event_on_success() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    // USER_ONE adds event
    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    // Use a new user(caller) to register for event & rsvp for event
    let caller: ContractAddress = starknet::contract_address_const::<0x123626789>();

    start_cheat_caller_address(event_contract_address, caller);

    event_dispatcher.register_for_event(event_id);

    let mut spy = spy_events();

    event_dispatcher.rsvp_for_event(event_id);

    let expected_event = Events::Event::RSVPForEvent(
        Events::RSVPForEvent { event_id: 1, attendee_address: caller }
    );
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);

    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'rsvp already exist')]
fn test_should_panic_on_rsvp_for_event_twice() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    // USER_ONE adds event
    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    // Use a new user(caller) to register for event & rsvp for event
    let caller: ContractAddress = starknet::contract_address_const::<0x123626789>();

    start_cheat_caller_address(event_contract_address, caller);

    event_dispatcher.register_for_event(event_id);

    // first rsvp for event
    event_dispatcher.rsvp_for_event(event_id);

    // second rsvp for the same event: should panic
    event_dispatcher.rsvp_for_event(event_id);

    stop_cheat_caller_address(event_contract_address);
}


#[test]
fn test_event_count_increase() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());

    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(initial_event_id == 1, 'First event ID incorrect');

    let second_event_id = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(second_event_id == 2, 'Second event ID incorrect');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_event_emission() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());

    // Add event with string literals
    let event_id = event_dispatcher.add_event("Devcon", "Barcelona");
    assert(event_id == 1, 'Event ID mismatch');

    // Get event details and compare them separately
    let event_details = event_dispatcher.event_details(event_id);

    // Compare each field independently
    let name_matches = event_details.name == "Devcon";
    let location_matches = event_details.location == "Barcelona";

    assert(name_matches, 'Event name mismatch');
    assert(location_matches, 'Event location mismatch');
    assert(event_details.event_id == event_id, 'Event ID mismatch in details');
    assert(!event_details.is_closed, 'Event should not be closed');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_owner() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let user_address: ContractAddress = USER_ONE.try_into().unwrap();

    start_cheat_caller_address(event_contract_address, user_address);

    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    let retrieved_owner = event_dispatcher.event_owner(1);
    assert(retrieved_owner == user_address, 'Wrong owner returned');
    stop_cheat_caller_address(event_contract_address);
}
