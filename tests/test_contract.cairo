// *************************************************************************
//                              Events TEST
// *************************************************************************

use core::result::ResultTrait;
use core::traits::TryInto;
use starknet::{ContractAddress};

use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait,
};

use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};

use chainevents_contracts::interfaces::IEvent::{IEventDispatcher, IEventDispatcherTrait};
use chainevents_contracts::events::chainevents::ChainEvents;
use chainevents_contracts::base::types::{EventDetails, EventType, EventRegistration};
use chainevents_contracts::interfaces::IPaymentToken::{IERC20Dispatcher, IERC20DispatcherTrait};

const USER_ONE: felt252 = 'JOE';
const USER_TWO: felt252 = 'DOE';
const USER_THREE: felt252 = 'JACK';


fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__(strk_token: ContractAddress) -> ContractAddress {
    // deploy  events
    let events_class_hash = declare("ChainEvents").unwrap().contract_class();

    let mut events_constructor_calldata: Array<felt252> = array![];

    let owner = OWNER();

    owner.serialize(ref events_constructor_calldata);
    strk_token.serialize(ref events_constructor_calldata);

    let (event_contract_address, _) = events_class_hash
        .deploy(@events_constructor_calldata)
        .unwrap();

    return (event_contract_address);
}

fn deploy_token_contract() -> ContractAddress {
    let contract = declare("PaymentToken").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_add_event() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_event_registration() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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

#[test]
fn test_registration_to_multiple_events() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let user_one_address: ContractAddress = USER_ONE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, user_one_address);

    let event_id_1 = event_dispatcher.add_event("ethereum dev meetup", "Main street 101");
    let event_id_2 = event_dispatcher.add_event("ethereum dev meetup 2", "Main street 102");
    assert(event_id_1 == 1, 'Event 1 was not created');
    assert(event_id_2 == 2, 'Event 2 was not created');

    stop_cheat_caller_address(event_contract_address);

    let user_two_address: ContractAddress = USER_TWO.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, user_two_address);

    event_dispatcher.register_for_event(event_id_1);
    event_dispatcher.register_for_event(event_id_2);

    let event_details_1 = event_dispatcher.event_details(event_id_1);
    let event_details_2 = event_dispatcher.event_details(event_id_2);

    let attendee_registration_details_1 = event_dispatcher.attendee_event_details(event_id_1);
    let attendee_registration_details_2 = event_dispatcher.attendee_event_details(event_id_2);

    assert(
        attendee_registration_details_1.attendee_address == user_two_address,
        'E1: attendee_address mismatch',
    );
    assert(
        attendee_registration_details_2.attendee_address == user_two_address,
        'E2: attendee_address mismatch',
    );
    assert(
        attendee_registration_details_1.nft_contract_address == user_two_address,
        'E1nft_contract_address mismatch',
    );
    assert(
        attendee_registration_details_2.nft_contract_address == user_two_address,
        'E2nft_contract_address mismatch',
    );
    assert(attendee_registration_details_1.nft_token_id == 0, 'E1: nft_token_id mismatch');
    assert(attendee_registration_details_2.nft_token_id == 0, 'E2: nft_token_id mismatch');
    assert(
        attendee_registration_details_1.organizer == event_details_1.organizer,
        'E1: organizer mismatch',
    );
    assert(
        attendee_registration_details_2.organizer == event_details_2.organizer,
        'E2: organizer mismatch',
    );
    stop_cheat_caller_address(event_contract_address);
}

fn test_register_for_event() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let caller: ContractAddress = starknet::contract_address_const::<0x123626789>();

    start_cheat_caller_address(event_contract_address, caller);

    let event_id: u256 = 1;

    event_dispatcher.rsvp_for_event(event_id);

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_rsvp_for_event_should_emit_event_on_success() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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

    assert(!event_details.is_closed, 'Event should not be closed');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_owner() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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
fn test_open_event_registration_success() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    let event_details = event_dispatcher.event_details(event_id);
    event_dispatcher.end_event_registration(event_id);
    event_dispatcher.open_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(!event_details.is_closed, 'Event was not opened');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'Caller Not Owner')]
fn test_not_owner_open_event_registration() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO.try_into().unwrap());
    event_dispatcher.open_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'Invalid event')]
fn test_open_event_registration_for_invalid_event() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    event_dispatcher.open_event_registration(2);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_event_details_after_open_event_registration() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    event_dispatcher.end_event_registration(event_id);
    event_dispatcher.open_event_registration(event_id);

    let event_details = event_dispatcher.event_details(event_id);
    assert(!event_details.is_closed, 'Event should not be closed');
    assert(event_details.event_id == 1, 'Event ID mismatch');
    assert(event_details.name == "bitcoin dev meetup", 'Event name mismatch');
    assert(event_details.location == "Dan Marna road", 'Event location mismatch');
    assert(event_details.organizer == USER_ONE.try_into().unwrap(), 'Organizer mismatch');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_open_event_emission() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    let event_details = event_dispatcher.event_details(event_id);

    event_dispatcher.end_event_registration(event_id);

    let mut spy = spy_events();

    event_dispatcher.open_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(!event_details.is_closed, 'Event was not opened');

    spy
        .assert_emitted(
            @array![
                (
                    event_contract_address,
                    ChainEvents::Event::OpenEventRegistration(
                        ChainEvents::OpenEventRegistration {
                            event_id,
                            event_name: event_details.name,
                            event_owner: USER_ONE.try_into().unwrap()
                        }
                    )
                )
            ]
        );

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_end_event_registration_success() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

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
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
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
fn test_pay_for_event() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IERC20Dispatcher { contract_address: strk_token };

    let user_1 = USER_ONE.try_into().unwrap();
    let user_2 = USER_TWO.try_into().unwrap();

    // user one adds an event
    start_cheat_caller_address(event_contract_address, user_1);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    // user one makes event paid
    let paid_amount: u256 = 1000000_u256;
    event_dispatcher.upgrade_event(event_id, paid_amount);
    stop_cheat_caller_address(event_contract_address);

    // user two mints token for payment and approves event contract to spend token
    start_cheat_caller_address(strk_token, user_2);
    payment_token.mint(user_2, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(
        payment_token.allowance(user_2, event_contract_address) == paid_amount, 'approval failed',
    );
    stop_cheat_caller_address(strk_token);

    // user two register's and pay's for an event
    start_cheat_caller_address(event_contract_address, user_2);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    assert(payment_token.balance_of(event_contract_address) == paid_amount, 'payment failed');
    assert(payment_token.balance_of(user_2) == 0, 'deduction failed');
}

#[test]
fn test_pay_for_event_by_event_owner() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IERC20Dispatcher { contract_address: strk_token };

    // user1 is the event owner that adds an event
    let user_1 = USER_ONE.try_into().unwrap();

    // user one adds an event
    start_cheat_caller_address(event_contract_address, user_1);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    // user one makes event paid
    let paid_amount: u256 = 1000000_u256;
    event_dispatcher.upgrade_event(event_id, paid_amount);
    stop_cheat_caller_address(event_contract_address);

    // user one mints token for payment and approves event contract to spend token
    start_cheat_caller_address(strk_token, user_1);
    payment_token.mint(user_1, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(
        payment_token.allowance(user_1, event_contract_address) == paid_amount, 'approval failed',
    );
    stop_cheat_caller_address(strk_token);

    // user one register's and pay's for an event
    start_cheat_caller_address(event_contract_address, user_1);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    assert(payment_token.balance_of(event_contract_address) == paid_amount, 'payment failed');
    assert(payment_token.balance_of(user_1) == 0, 'deduction failed');
}

#[test]
fn test_pay_for_event_emits_event_on_success() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IERC20Dispatcher { contract_address: strk_token };

    let user_1 = USER_ONE.try_into().unwrap();
    let user_2 = USER_TWO.try_into().unwrap();

    // user one adds an event
    start_cheat_caller_address(event_contract_address, user_1);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    // user one makes event paid
    let paid_amount: u256 = 1000000_u256;
    event_dispatcher.upgrade_event(event_id, paid_amount);
    stop_cheat_caller_address(event_contract_address);

    // user two mints token for payment and approves event contract to spend token
    start_cheat_caller_address(strk_token, user_2);
    payment_token.mint(user_2, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(
        payment_token.allowance(user_2, event_contract_address) == paid_amount, 'approval failed',
    );
    stop_cheat_caller_address(strk_token);

    let mut spy = spy_events();

    // user two register's and pay's for an event
    start_cheat_caller_address(event_contract_address, user_2);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    let expected_event = ChainEvents::Event::EventPayment(
        ChainEvents::EventPayment { event_id, caller: user_2, amount: paid_amount },
    );
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
}

#[test]
#[should_panic(expected: 'Not a Paid Event')]
fn test_pay_for_event_should_panic_for_free_event() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IERC20Dispatcher { contract_address: strk_token };

    let user_1 = USER_ONE.try_into().unwrap();
    let user_2 = USER_TWO.try_into().unwrap();

    // user one adds an event
    start_cheat_caller_address(event_contract_address, user_1);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    let paid_amount: u256 = 1000000_u256;

    // user two mints token for payment and approves event contract to spend token
    start_cheat_caller_address(strk_token, user_2);
    payment_token.mint(user_2, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(
        payment_token.allowance(user_2, event_contract_address) == paid_amount, 'approval failed',
    );
    stop_cheat_caller_address(strk_token);

    // user two register's and pay's for an event
    start_cheat_caller_address(event_contract_address, user_2);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);
}

fn test_get_paid_event_ticket_counts() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);

    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IERC20Dispatcher { contract_address: strk_token };

    let user_1 = USER_ONE.try_into().unwrap();
    let user_2 = USER_TWO.try_into().unwrap();

    // user one adds an event
    start_cheat_caller_address(event_contract_address, user_1);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    // user one makes event paid
    let paid_amount: u256 = 1000000_u256;
    event_dispatcher.upgrade_event(event_id, paid_amount);
    stop_cheat_caller_address(event_contract_address);

    // user two mints token for payment and approves event contract to spend token
    start_cheat_caller_address(strk_token, user_2);
    payment_token.mint(user_2, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(
        payment_token.allowance(user_2, event_contract_address) == paid_amount, 'approval failed',
    );
    stop_cheat_caller_address(strk_token);

    // user two register's and pay's for an event
    start_cheat_caller_address(event_contract_address, user_2);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    assert(event_dispatcher.paid_event_ticket_counts(event_id) == 1, 'Wrong number of tickets');
}

#[test]
fn test_get_events() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    let organizer: ContractAddress = USER_ONE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, organizer);
    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(initial_event_id == 1, 'First event ID incorrect');
    let events = event_dispatcher.get_events();
    let expected = event_dispatcher.event_details(initial_event_id);
    expected_events.append(expected);
    assert(events == expected_events, 'Events not retrieved');

    stop_cheat_caller_address(event_contract_address);

    let organizer: ContractAddress = USER_TWO.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, organizer);
    let second_event_id = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(second_event_id == 2, 'Second event ID incorrect');
    let expected = event_dispatcher.event_details(second_event_id);
    let events = event_dispatcher.get_events();
    expected_events.append(expected);
    assert(events == expected_events, 'Events not retrieved');

    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_event_total_amount_paid() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());

    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    event_dispatcher.event_total_amount_paid(event_id);
    assert(event_id == 1, 'Invalid event');
}

#[test]
fn test_events_by_organizer() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut events: Array<EventDetails> = ArrayTrait::<EventDetails>::new();

    let organizer: ContractAddress = USER_ONE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, organizer);
    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");

    let organizer_events: Array<EventDetails> = event_dispatcher.events_by_organizer(organizer);

    let first_event: EventDetails = organizer_events.at(0).clone().try_into().unwrap();

    assert(first_event.organizer == organizer, 'Wrong organizer');
}

#[test]
fn test_fetch_all_attendees_on_event() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let user_one_address: ContractAddress = USER_ONE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, user_one_address);
    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    let another_event_id = event_dispatcher.add_event("Starknet Confrence", "Times Square");
    stop_cheat_caller_address(event_contract_address);

    let user_two_address: ContractAddress = USER_TWO.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, user_two_address);
    event_dispatcher.register_for_event(initial_event_id);
    stop_cheat_caller_address(event_contract_address);

    let user_three_address: ContractAddress = USER_THREE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, user_three_address);
    event_dispatcher.register_for_event(initial_event_id);
    stop_cheat_caller_address(event_contract_address);

    let all_attendees_on_event: Array<EventRegistration> = event_dispatcher
        .fetch_all_attendees_on_event(initial_event_id);
    println!("the number is {}", all_attendees_on_event.len());
    assert(all_attendees_on_event.len() == 2, 'Wrong number of attendees');
    let first_attendee: EventRegistration = all_attendees_on_event
        .at(0)
        .clone()
        .try_into()
        .unwrap();
    let second_attendee: EventRegistration = all_attendees_on_event
        .at(1)
        .clone()
        .try_into()
        .unwrap();
    assert(first_attendee.attendee_address == USER_TWO.try_into().unwrap(), 'Wrong first attendee');
    assert(
        second_attendee.attendee_address == USER_THREE.try_into().unwrap(), 'Wrong second attendee',
    );
}

#[test]
fn test_get_open_events() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    let organizer: ContractAddress = USER_ONE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, organizer);
    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(initial_event_id == 1, 'First event ID incorrect');
    let open_events = event_dispatcher.get_open_events();
    let expected = event_dispatcher.event_details(initial_event_id);
    expected_events.append(expected);
    assert(open_events == expected_events, 'Events not retrieved');

    stop_cheat_caller_address(event_contract_address);

    let organizer: ContractAddress = USER_TWO.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, organizer);
    let second_event_id = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(second_event_id == 2, 'Second event ID incorrect');
    event_dispatcher.end_event_registration(second_event_id);
    let second_event_details = event_dispatcher.event_details(second_event_id);
    assert(second_event_details.is_closed, 'Event was not closed');
    let open_events = event_dispatcher.get_open_events();
    expected_events.append(second_event_details);
    assert(open_events != expected_events, 'Function fetches closed events');
}

#[test]
fn test_get_closed_events() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    let organizer: ContractAddress = USER_ONE.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, organizer);
    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(initial_event_id == 1, 'First event ID incorrect');
    event_dispatcher.end_event_registration(initial_event_id);
    let closed_events = event_dispatcher.get_closed_events();
    let expected = event_dispatcher.event_details(initial_event_id);
    expected_events.append(expected);
    assert(closed_events == expected_events, 'Events not retrieved');

    stop_cheat_caller_address(event_contract_address);

    let organizer: ContractAddress = USER_TWO.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, organizer);
    let second_event_id = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(second_event_id == 2, 'Second event ID incorrect');
    let second_event_details = event_dispatcher.event_details(second_event_id);
    let closed_events = event_dispatcher.get_closed_events();
    expected_events.append(second_event_details);
    assert(closed_events != expected_events, 'Function includes open events');
}

#[test]
fn test_fetch_all_paid_events() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    let customer: ContractAddress = USER_ONE.try_into().unwrap();

    start_cheat_caller_address(event_contract_address, customer);
    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    stop_cheat_caller_address(event_contract_address);

    let customer: ContractAddress = USER_TWO.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, customer);
    let second_event_id = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());
    let paid_amount: u256 = 1000000_u256;
    event_dispatcher.upgrade_event(initial_event_id, paid_amount);
    let paid_events = event_dispatcher.fetch_all_paid_events();
    let expected = event_dispatcher.event_details(initial_event_id);
    expected_events.append(expected);
    assert(paid_events == expected_events, 'Paid events not retrieved');

    start_cheat_caller_address(event_contract_address, USER_TWO.try_into().unwrap());
    event_dispatcher.upgrade_event(second_event_id, paid_amount);
    let paid_events = event_dispatcher.fetch_all_paid_events();
    let expected = event_dispatcher.event_details(second_event_id);
    expected_events.append(expected);
    assert(paid_events == expected_events, 'Paid events not retrieved');
}

#[test]
fn test_fetch_all_unpaid_events() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    let customer: ContractAddress = USER_ONE.try_into().unwrap();

    start_cheat_caller_address(event_contract_address, customer);
    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Zone Tech Park");
    stop_cheat_caller_address(event_contract_address);

    let customer: ContractAddress = USER_TWO.try_into().unwrap();
    start_cheat_caller_address(event_contract_address, customer);
    let second_event_id = event_dispatcher
        .add_event("Starknet ZK Stark Proof Workshop", "TheBuidl Hub");
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE.try_into().unwrap());

    let unpaid_events = event_dispatcher.fetch_all_unpaid_events();
    let expected = event_dispatcher.event_details(initial_event_id);
    let expected_2 = event_dispatcher.event_details(second_event_id);
    println!("Unpaid event numbers : {:?}", unpaid_events.len());
    expected_events.append(expected);
    expected_events.append(expected_2);
    assert(unpaid_events.len() == expected_events.len(), 'Unpaid events not retrieved');
}

#[test]
#[should_panic(expected: 'Caller Not Owner')]
fn test_only_owner_can_withdraw_paid_event_amount() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IERC20Dispatcher { contract_address: strk_token };

    let user_one: ContractAddress = USER_ONE.try_into().unwrap();
    let user_two: ContractAddress = USER_TWO.try_into().unwrap();

    // Create paid event
    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("Paid Workshop", "Devcon");

    // Upgrade event to paid with 100 token fee
    let event_fee: u256 = 100;
    event_dispatcher.upgrade_event(event_id, event_fee);
    stop_cheat_caller_address(event_contract_address);

    // Mint and approve tokens for event contract
    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, event_fee);
    payment_token.approve(event_contract_address, event_fee);
    stop_cheat_caller_address(strk_token);

    // Check allowance is correct
    let allowance = payment_token.allowance(user_two, event_contract_address);
    assert(allowance == event_fee, 'Incorrect allowance');

    // Register for event
    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    // Assert token balance of event contract is correct
    let event_contract_balance = payment_token.balance_of(event_contract_address);
    assert(event_contract_balance == event_fee, 'Incorrect balance');

    // Withdraw tokens
    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.withdraw_paid_event_amount(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[should_panic(expected: 'Event is not closed')]
fn test_withdraw_paid_event_amount_for_open_event() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IERC20Dispatcher { contract_address: strk_token };

    let user_one: ContractAddress = USER_ONE.try_into().unwrap();
    let user_two: ContractAddress = USER_TWO.try_into().unwrap();

    // Create paid event
    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("Paid Workshop", "Devcon");

    // Upgrade event to paid with 100 token fee
    let event_fee: u256 = 100;
    event_dispatcher.upgrade_event(event_id, event_fee);
    stop_cheat_caller_address(event_contract_address);

    // Register for event
    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    // Mint and approve tokens for event contract
    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, event_fee);
    payment_token.approve(event_contract_address, event_fee);
    stop_cheat_caller_address(strk_token);

    // Check allowance is correct
    let allowance = payment_token.allowance(user_two, event_contract_address);
    assert(allowance == event_fee, 'Incorrect allowance');

    // Register for event
    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    // Assert token balance of event contract is correct
    let event_contract_balance = payment_token.balance_of(event_contract_address);
    assert(event_contract_balance == event_fee, 'Incorrect balance');

    // Withdraw tokens
    start_cheat_caller_address(event_contract_address, user_one);
    event_dispatcher.withdraw_paid_event_amount(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
fn test_withdraw_paid_event_amount_for_closed_event() {
    let strk_token = deploy_token_contract();
    let event_contract_address = __setup__(strk_token);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IERC20Dispatcher { contract_address: strk_token };

    let user_one: ContractAddress = USER_ONE.try_into().unwrap();
    let user_two: ContractAddress = USER_TWO.try_into().unwrap();

    // Create paid event
    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("Paid Workshop", "Devcon");

    // Upgrade event to paid with 100 token fee
    let event_fee: u256 = 100;
    event_dispatcher.upgrade_event(event_id, event_fee);
    stop_cheat_caller_address(event_contract_address);

    // Mint and approve tokens for event contract
    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, event_fee);
    payment_token.approve(event_contract_address, event_fee);
    stop_cheat_caller_address(strk_token);

    // Check allowance is correct
    let allowance = payment_token.allowance(user_two, event_contract_address);
    assert(allowance == event_fee, 'Incorrect allowance');

    // Register for event
    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    // Assert token balance of event contract is correct
    let event_contract_balance = payment_token.balance_of(event_contract_address);
    assert(event_contract_balance == event_fee, 'Incorrect balance');

    // End event registration
    start_cheat_caller_address(event_contract_address, user_one);
    event_dispatcher.end_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);

    let mut spy = spy_events();

    // Withdraw tokens
    start_cheat_caller_address(event_contract_address, user_one);
    event_dispatcher.withdraw_paid_event_amount(event_id);
    stop_cheat_caller_address(event_contract_address);

    let expected_event = ChainEvents::Event::WithdrawalMade(
        ChainEvents::WithdrawalMade { event_id, event_organizer: user_one, amount: event_fee }
    );
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);

    let event_contract_balance = payment_token.balance_of(event_contract_address);
    assert(event_contract_balance == 0, 'Incorrect contract balance');

    let user_one_balance = payment_token.balance_of(user_one);
    assert(user_one_balance == event_fee, 'Incorrect organizer balance');

    let user_two_balance = payment_token.balance_of(user_two);
    assert(user_two_balance == 0, 'Incorrect attendee balance');
}
