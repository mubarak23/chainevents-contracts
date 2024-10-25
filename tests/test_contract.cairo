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

fn test_event_details() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    
    // Add event
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, "Event was not created");

    // Retrieve event details
    let event_details = event_dispatcher.event_details(event_id);

    // Assert event details
    assert(event_details.event_id == 1, "Event ID mismatch");
    assert(event_details.name == "bitcoin dev meetup", "Event name mismatch");
    assert(event_details.location == "Dan Marna road", "Event location mismatch");
    assert(event_details.organizer == event_contract_address, "Organizer mismatch");
    assert(event_details.total_register == 0, "Total register should be 0");
    assert(event_details.total_attendees == 0, "Total attendees should be 0");
    assert(event_details.event_type == EventType::Free, "Event type mismatch"); 
    assert(event_details.is_closed == false, "Event should not be closed");
    assert(event_details.paid_amount == 0, "Paid amount should be 0");
    
    stop_cheat_caller_address(event_contract_address);
}

