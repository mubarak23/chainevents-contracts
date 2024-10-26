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
fn test_end_event_registration() {
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
