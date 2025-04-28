// *************************************************************************
//                              Events TEST
// *************************************************************************

use chainevents_contracts::base::types::EventType;
use chainevents_contracts::events::chainevents::ChainEvents;
use chainevents_contracts::events::feecollector::FeeCollector;
use chainevents_contracts::interfaces::IEvent::{IEventDispatcher, IEventDispatcherTrait};
use chainevents_contracts::interfaces::IFeeCollector::{
    IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait,
};
use core::result::ResultTrait;
use core::traits::TryInto;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

const USER_ONE: felt252 = 'JOE';
const USER_TWO: felt252 = 'DOE';

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn RECIPIENT() -> ContractAddress {
    'recipient'.try_into().unwrap()
}

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> ContractAddress {
    // deploy  events
    let events_class_hash = declare("ChainEvents").unwrap().contract_class();

    let mut events_constructor_calldata: Array<felt252> = array![];

    let owner = OWNER();

    owner.serialize(ref events_constructor_calldata);

    let (event_contract_address, _) = events_class_hash
        .deploy(@events_constructor_calldata)
        .unwrap();

    return (event_contract_address);
}

fn __deploy_erc20__() -> IERC20CamelDispatcher {
    let erc20_class_hash = declare("MyToken").unwrap().contract_class();
    let recipient = RECIPIENT();
    let mut erc20_constructor_calldata: Array<felt252> = array![];

    recipient.serialize(ref erc20_constructor_calldata);

    let (erc20_contract_address, _) = erc20_class_hash.deploy(@erc20_constructor_calldata).unwrap();

    return IERC20CamelDispatcher { contract_address: erc20_contract_address };
}

fn __setup_fee_collector__(
    erc20_address: ContractAddress, event_contract_address: ContractAddress,
) -> ContractAddress {
    // deploy fee collector contract
    let fee_collector_class_hash = declare("FeeCollector").unwrap().contract_class();

    let mut constructor_calldata: Array<felt252> = array![];

    // fee percentage of 2,5% (250 basis points)
    let fee_percentage: u256 = 250;
    fee_percentage.serialize(ref constructor_calldata);
    erc20_address.serialize(ref constructor_calldata);
    event_contract_address.serialize(ref constructor_calldata);

    let (fee_collector_address, _) = fee_collector_class_hash
        .deploy(@constructor_calldata)
        .unwrap();

    return fee_collector_address;
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

    assert(
        attendee_registration_details.attendee_address == user_two_address,
        'attendee_address mismatch',
    );
    assert(
        attendee_registration_details.nft_contract_address == user_two_address,
        'nft_contract_address mismatch',
    );
    assert(attendee_registration_details.nft_token_id == 0, 'nft_token_id mismatch');
    assert(
        attendee_registration_details.organizer == event_details.organizer, 'organizer mismatch',
    );
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

    let expected_event = ChainEvents::Event::RSVPForEvent(
        ChainEvents::RSVPForEvent { event_id: 1, attendee_address: caller },
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
    let total_register_matches = event_details.total_register == 0;
    let total_attendees_matches = event_details.total_attendees == 0;
    let event_type_matches = event_details.event_type == EventType::Free;
    let is_closed_matches = !event_details.is_closed;
    let paid_amount_matches = event_details.paid_amount == 0;

    // Assert each condition
    assert(id_matches, 'Event ID mismatch');
    assert(name_matches, 'Event name mismatch');
    assert(location_matches, 'Event location mismatch');
    assert(organizer_matches, 'Organizer mismatch');
    assert(total_register_matches, 'Total register should be 0');
    assert(total_attendees_matches, 'Total attendees should be 0');
    assert(event_type_matches, 'Event type mismatch');
    assert(is_closed_matches, 'Event should not be closed');
    assert(paid_amount_matches, 'Paid amount should be 0');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'Caller Not Owner')]
fn test_registered_attendees_only_owner() {
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

    // Assert only owner can call registered_attendees
    event_dispatcher.attendees_registered(event_id);
}

#[test]
fn test_attendees_registered_updates_correctly() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    // USER_ONE adds event
    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    // Ensure Registered attendees is at default value (0)
    let attendees_registered = event_dispatcher.attendees_registered(event_id);
    assert(attendees_registered == 0, 'Attendees Must be 0');
    stop_cheat_caller_address(event_contract_address);

    // Use a new user(caller) to register for event & rsvp for event
    let caller: ContractAddress = starknet::contract_address_const::<0x123626789>();
    start_cheat_caller_address(event_contract_address, caller);
    event_dispatcher.register_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    // Assert attendees registered increases correctly
    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let attendees_registered = event_dispatcher.attendees_registered(event_id);
    assert(attendees_registered == 1, 'Attendees Not Tallying');
}

#[test]
fn test_end_event_registration_success() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    event_dispatcher.end_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.is_closed, 'Event was not closed');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'Caller Not Owner')]
fn test_not_owner_end_event_registration() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO.try_into().unwrap());
    event_dispatcher.end_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'Invalid event')]
fn test_end_event_registration_for_invalid_event() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    event_dispatcher.end_event_registration(2);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_event_details_after_end_event_registration() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    event_dispatcher.end_event_registration(event_id);

    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.is_closed, 'Event should be closed');
    assert(event_details.event_id == 1, 'Event ID mismatch');
    assert(event_details.name == "bitcoin dev meetup", 'Event name mismatch');
    assert(event_details.location == "Dan Marna road", 'Event location mismatch');
    assert(event_details.organizer == USER_ONE.try_into().unwrap(), 'Organizer mismatch');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_end_event_emission() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    event_dispatcher.end_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.is_closed, 'Event was not closed');

    // Compare each field independently
    let name_matches = event_details.name == "bitcoin dev meetup";
    let location_matches = event_details.location == "Dan Marna road";

    assert(name_matches, 'Event name mismatch');
    assert(location_matches, 'Event location mismatch');
    assert(event_details.event_id == event_id, 'Event ID mismatch in details');
    assert(event_details.is_closed, 'Event should not be closed');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_upgrade_event() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.upgrade_event(event_id, 20);
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.event_type == EventType::Paid, 'Event was Not Upgraded');
    assert(event_details.paid_amount == 20, 'Event was Not Upgraded');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'Caller Not Owner')]
fn test_upgrade_event_with_wrong_owner() {
    let event_contract_address = __setup__();

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO.try_into().unwrap());
    event_dispatcher.upgrade_event(event_id, 20);
}

#[test]
fn test_unregister_from_event() {
    let event_contract_address = __setup__();
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO.try_into().unwrap());
    event_dispatcher.register_for_event(event_id);

    let mut spy = spy_events();
    event_dispatcher.unregister_from_event(event_id);

    let expected_event = ChainEvents::Event::UnregisteredEvent(
        ChainEvents::UnregisteredEvent { event_id, user_address: USER_TWO.try_into().unwrap() },
    );
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_collect_fee_for_event() {
    // Setup contracts
    let event_contract_address = __setup__();
    let erc20 = __deploy_erc20__();

    let fee_collector_address = __setup_fee_collector__(
        erc20.contract_address, event_contract_address,
    );

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let fee_collector = IFeeCollectorDispatcher { contract_address: fee_collector_address };

    // Create a paid event
    let organizer: ContractAddress = USER_ONE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, organizer);
    let event_id = event_dispatcher.add_event("Paid Conference", "Tech Hub");

    // Upgrade event to paid with 100 token fee
    let event_fee: u256 = 100;
    event_dispatcher.upgrade_event(event_id, event_fee);
    stop_cheat_caller_address(event_contract_address);

    // Setup attendee
    let attendee: ContractAddress = RECIPIENT();

    // Register for event first
    start_cheat_caller_address(event_contract_address, attendee);
    event_dispatcher.register_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    // Approve tokens for fee collector
    start_cheat_caller_address(erc20.contract_address, attendee);
    let fee_amount: u256 = (event_fee * 250) / 10000; // 2.5% fee
    erc20.approve(fee_collector_address, fee_amount);
    stop_cheat_caller_address(erc20.contract_address);

    // Collect fee
    start_cheat_caller_address(fee_collector_address, attendee);
    let mut spy = spy_events();
    fee_collector.collect_fee_for_event(event_id);

    // Verify event emission
    let expected_event = FeeCollector::Event::FeesCollected(
        FeeCollector::FeesCollected { event_id, fee_amount, user_address: attendee },
    );
    spy.assert_emitted(@array![(fee_collector_address, expected_event)]);

    // Verify fee collection
    let total_fees = fee_collector.total_fees_collected();
    assert(total_fees == fee_amount, 'Incorrect total fees');

    stop_cheat_caller_address(fee_collector_address);
}
