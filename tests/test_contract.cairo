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

    let event_name = "Devcon";
    let event_location = "Barcelona";
    let expected_event_id = 1;

    let event_id = event_dispatcher.add_event(event_name, event_location);

    // Check if event ID is correct
    assert(event_id == expected_event_id, 'Event ID mismatch');

    // Verify event details
    let emitted_event = event_dispatcher.event_details(event_id);
    
    assert(emitted_event.name == event_name, 'Event name mismatch');
    // assert(emitted_event.location == event_location, 'Event location mismatch');
    // assert(emitted_event.event_id == event_id, 'Event ID mismatch in details');
    // assert(!emitted_event.is_closed, 'Event should not be closed');
    
    stop_cheat_caller_address(event_contract_address);
}