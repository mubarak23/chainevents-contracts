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
