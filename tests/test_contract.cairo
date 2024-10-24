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
fn test_event_registration() {
    let event_contract_address = __setup__();
    
    let event_dispatcher = IEventDispatcher{contract_address : event_contract_address};

    let user_two_address: ContractAddress = USER_TWO.try_into().unwrap();
    
    start_cheat_caller_address(event_contract_address, user_two_address);
 
    let event_id = event_dispatcher.add_event("ethereum dev meetup", "Main street 101");
    assert(event_id == 1, 'Event was not created');
    let event_details = event_dispatcher.event_details(event_id);
    let registration_details = event_dispatcher.attendee_event_details(event_id);

    assert(registration_details.attendee_address == user_two_address , 'attendee_address mismatch');
    assert(registration_details.amount_paid == event_details.paid_amount, 'amount_paid mismatch');
    assert(registration_details.has_rsvp == true, 'has_rsvp mismatch');
    assert(registration_details.nft_contract_address == user_two_address, 'nft_contract_address mismatch');
    assert(registration_details.nft_token_id == 34, 'nft_token_id mismatch');
    assert(registration_details.organizer == event_details.organizer, 'organizer mismatch');


    stop_cheat_caller_address(event_contract_address);
}

