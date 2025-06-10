use core::result::ResultTrait;
use core::traits::TryInto;
use starknet::{ContractAddress, ClassHash, contract_address_const};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait,
};
use chainevents_contracts::interfaces::IEvent::{IEventDispatcher, IEventDispatcherTrait};
use chainevents_contracts::events::chainevents::ChainEvents;
use chainevents_contracts::base::types::{EventDetails, EventType, EventRegistration};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// Custom interface for PaymentToken to include mint
#[starknet::interface]
trait IPaymentTokenDispatcherTrait<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

#[starknet::contract]
mod PaymentToken {
    use starknet::{ContractAddress, get_caller_address};
    use super::IPaymentTokenDispatcherTrait;

    #[storage]
    struct Storage {
        balances: LegacyMap<ContractAddress, u256>,
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl PaymentTokenImpl of IPaymentTokenDispatcherTrait<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.balances.write(recipient, self.balances.read(recipient) + amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            self.allowances.write((caller, spender), amount);
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let balance = self.balances.read(caller);
            assert(balance >= amount, 'Insufficient balance');
            self.balances.write(caller, balance - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            true
        }

        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let allowance = self.allowances.read((sender, caller));
            assert(allowance >= amount, 'Insufficient allowance');
            let balance = self.balances.read(sender);
            assert(balance >= amount, 'Insufficient balance');
            self.allowances.write((sender, caller), allowance - amount);
            self.balances.write(sender, balance - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            true
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }
    }
}

// Helper functions for contract addresses
fn USER_ONE() -> ContractAddress {
    contract_address_const::<0x1>()
}

fn USER_TWO() -> ContractAddress {
    contract_address_const::<0x2>()
}

fn USER_THREE() -> ContractAddress {
    contract_address_const::<0x3>()
}

fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<0x4>()
}

// Setup function to deploy contracts
fn __setup__(strk_token: ContractAddress, nft_class_hash: ClassHash) -> ContractAddress {
    let events_class = declare("ChainEvents").unwrap().contract_class();
    let owner = OWNER();
    let mut constructor_calldata: Array<felt252> = array![];
    owner.serialize(ref constructor_calldata);
    strk_token.serialize(ref constructor_calldata);
    nft_class_hash.serialize(ref constructor_calldata);
    let (event_contract_address, _) = events_class.deploy(@constructor_calldata).unwrap();
    event_contract_address
}

fn deploy_token_contract() -> ContractAddress {
    let contract = declare("PaymentToken").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

// Tests
#[test]
#[available_gas(2000000)]
fn test_add_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');

    let expected_event = ChainEvents::Event::NewEventAdded(ChainEvents::NewEventAdded {
        name: "bitcoin dev meetup",
        event_id: 1,
        location: "Dan Marna road",
        event_owner: USER_ONE()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_registration() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("ethereum dev meetup", "Main street 101");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.register_for_event(event_id);
    let event_details = event_dispatcher.event_details(event_id);

    let expected_event = ChainEvents::Event::RegisteredForEvent(ChainEvents::RegisteredForEvent {
        event_id: 1,
        event_name: "ethereum dev meetup",
        user_address: USER_TWO()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let attendees = event_dispatcher.fetch_all_attendees_on_event(event_id);
    assert(attendees.len() == 1, 'Wrong attendee count');
    let attendee_details = *attendees.at(0);
    assert(attendee_details.attendee_address == USER_TWO(), 'attendee_address mismatch');
    assert(attendee_details.nft_contract_address != ZERO_ADDRESS(), 'nft_contract_address mismatch');
    assert(attendee_details.nft_token_id == 0, 'nft_token_id mismatch');
    assert(attendee_details.organizer == event_details.organizer, 'organizer mismatch');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_registration_to_multiple_events() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id_1 = event_dispatcher.add_event("ethereum dev meetup", "Main street 101");
    let event_id_2 = event_dispatcher.add_event("ethereum dev meetup 2", "Main street 102");
    assert(event_id_1 == 1, 'Event 1 was not created');
    assert(event_id_2 == 2, 'Event 2 was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.register_for_event(event_id_1);
    event_dispatcher.register_for_event(event_id_2);
    let event_details_1 = event_dispatcher.event_details(event_id_1);
    let event_details_2 = event_dispatcher.event_details(event_id_2);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let attendees_1 = event_dispatcher.fetch_all_attendees_on_event(event_id_1);
    let attendees_2 = event_dispatcher.fetch_all_attendees_on_event(event_id_2);
    assert(attendees_1.len() == 1, 'Wrong attendee count for event 1');
    assert(attendees_2.len() == 1, 'Wrong attendee count for event 2');
    let attendee_details_1 = *attendees_1.at(0);
    let attendee_details_2 = *attendees_2.at(0);
    assert(attendee_details_1.attendee_address == USER_TWO(), 'E1: attendee_address mismatch');
    assert(attendee_details_2.attendee_address == USER_TWO(), 'E2: attendee_address mismatch');
    assert(attendee_details_1.nft_contract_address != ZERO_ADDRESS(), 'E1: nft_contract_address mismatch');
    assert(attendee_details_2.nft_contract_address != ZERO_ADDRESS(), 'E2: nft_contract_address mismatch');
    assert(attendee_details_1.nft_token_id == 0, 'E1: nft_token_id mismatch');
    assert(attendee_details_2.nft_token_id == 0, 'E2: nft_token_id mismatch');
    assert(attendee_details_1.organizer == event_details_1.organizer, 'E1: organizer mismatch');
    assert(attendee_details_2.organizer == event_details_2.organizer, 'E2: organizer mismatch');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_register_for_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.register_for_event(event_id);
    let expected_event = ChainEvents::Event::RegisteredForEvent(ChainEvents::RegisteredForEvent {
        event_id: 1,
        event_name: "bitcoin dev meetup",
        user_address: USER_TWO()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'rsvp only for registered event')]
fn test_should_panic_on_rsvp_for_event_that_was_not_registered_for() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let caller = USER_THREE();
    start_cheat_caller_address(event_contract_address, caller);
    let event_id: u256 = 1;
    event_dispatcher.rsvp_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_rsvp_for_event_should_emit_event_on_success() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    let caller = USER_THREE();
    start_cheat_caller_address(event_contract_address, caller);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.rsvp_for_event(event_id);
    let expected_event = ChainEvents::Event::RSVPForEvent(ChainEvents::RSVPForEvent {
        event_id: 1,
        attendee_address: caller
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'rsvp already exist')]
fn test_should_panic_on_rsvp_for_event_twice() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    let caller = USER_THREE();
    start_cheat_caller_address(event_contract_address, caller);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.rsvp_for_event(event_id);
    event_dispatcher.rsvp_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_count_increase() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let initial_event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(initial_event_id == 1, 'First event ID incorrect');
    let second_event_id = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(second_event_id == 2, 'Second event ID incorrect');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_emission() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("Devcon", "Barcelona");
    assert(event_id == 1, 'Event ID mismatch');
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.name == "Devcon", 'Event name mismatch');
    assert(event_details.location == "Barcelona", 'Event location mismatch');
    assert(!event_details.is_closed, 'Event should not be closed');

    let expected_event = ChainEvents::Event::NewEventAdded(ChainEvents::NewEventAdded {
        name: "Devcon",
        event_id: 1,
        location: "Barcelona",
        event_owner: USER_ONE()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_owner() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let user_address = USER_ONE();
    start_cheat_caller_address(event_contract_address, user_address);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    let retrieved_owner = event_dispatcher.event_owner(1);
    assert(retrieved_owner == user_address, 'Wrong owner returned');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_details() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let user_address = USER_ONE();
    start_cheat_caller_address(event_contract_address, user_address);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.event_id == 1, 'Event ID mismatch');
    assert(event_details.name == "bitcoin dev meetup", 'Event name mismatch');
    assert(event_details.location == "Dan Marna road", 'Event location mismatch');
    assert(event_details.organizer == user_address, 'Organizer mismatch');
    assert(event_details.total_register == 0, 'Total register should be 0');
    assert(event_details.total_attendees == 0, 'Total attendees should be 0');
    assert(event_details.event_type == EventType::Free, 'Event type mismatch');
    assert(!event_details.is_closed, 'Event should not be closed');
    assert(event_details.paid_amount == 0, 'Paid amount should be 0');
    assert(event_details.max_capacity == 100000, 'Max capacity mismatch');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Caller Not Owner')]
fn test_registered_attendees_only_owner() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    let caller = USER_THREE();
    start_cheat_caller_address(event_contract_address, caller);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.attendees_registered(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_attendees_registered_updates_correctly() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    let attendees_registered = event_dispatcher.attendees_registered(event_id);
    assert(attendees_registered == 0, 'Attendees must be 0');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_THREE());
    event_dispatcher.register_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let attendees_registered = event_dispatcher.attendees_registered(event_id);
    assert(attendees_registered == 1, 'Attendees not tallying');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_open_event_registration_success() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.end_event_registration(event_id);
    event_dispatcher.open_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(!event_details.is_closed, 'Event was not opened');

    let expected_event = ChainEvents::Event::OpenEventRegistration(ChainEvents::OpenEventRegistration {
        event_id: 1,
        event_name: "bitcoin dev meetup",
        event_owner: USER_ONE()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Caller Not Owner')]
fn test_not_owner_open_event_registration() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.open_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Invalid event')]
fn test_open_event_registration_for_invalid_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    event_dispatcher.open_event_registration(1);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_details_after_open_event_registration() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.end_event_registration(event_id);
    event_dispatcher.open_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(!event_details.is_closed, 'Event should not be closed');
    assert(event_details.event_id == 1, 'Event ID mismatch');
    assert(event_details.name == "bitcoin dev meetup", 'Event name mismatch');
    assert(event_details.location == "Dan Marna road", 'Event location mismatch');
    assert(event_details.organizer == USER_ONE(), 'Organizer mismatch');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_open_event_emission() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.end_event_registration(event_id);
    event_dispatcher.open_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(!event_details.is_closed, 'Event was not opened');

    let expected_event = ChainEvents::Event::OpenEventRegistration(ChainEvents::OpenEventRegistration {
        event_id: 1,
        event_name: "bitcoin dev meetup",
        event_owner: USER_ONE()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_end_event_registration_success() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.end_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.is_closed, 'Event was not closed');

    let expected_event = ChainEvents::Event::EndEventRegistration(ChainEvents::EndEventRegistration {
        event_id: 1,
        event_name: "bitcoin dev meetup",
        event_owner: USER_ONE()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Caller Not Owner')]
fn test_not_owner_end_event_registration() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.end_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Invalid event')]
fn test_end_event_registration_for_invalid_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    event_dispatcher.end_event_registration(1);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_details_after_end_event_registration() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.end_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.is_closed, 'Event should be closed');
    assert(event_details.event_id == 1, 'Event ID mismatch');
    assert(event_details.name == "bitcoin dev meetup", 'Event name mismatch');
    assert(event_details.location == "Dan Marna road", 'Event location mismatch');
    assert(event_details.organizer == USER_ONE(), 'Organizer mismatch');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_end_event_emission() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.end_event_registration(event_id);
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.is_closed, 'Event was not closed');

    let expected_event = ChainEvents::Event::EndEventRegistration(ChainEvents::EndEventRegistration {
        event_id: 1,
        event_name: "bitcoin dev meetup",
        event_owner: USER_ONE()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_update_event_max_capacity() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.end_event_registration(event_id);
    event_dispatcher.update_event_max_capacity(event_id, 200000);
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.max_capacity == 200000, 'Max capacity not updated');

    let expected_event = ChainEvents::Event::EventCapacityUpdated(ChainEvents::EventCapacityUpdated {
        event_id: 1,
        new_max_capacity: 200000
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Caller Not Owner')]
fn test_update_event_max_capacity_wrong_owner() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.end_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.update_event_max_capacity(event_id, 200000);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Event is not closed')]
fn test_update_event_max_capacity_open_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.update_event_max_capacity(event_id, 200000);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_upgrade_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.upgrade_event(event_id, 20);
    let event_details = event_dispatcher.event_details(event_id);
    assert(event_details.event_type == EventType::Paid, 'Event was not upgraded');
    assert(event_details.paid_amount == 20, 'Paid amount mismatch');

    let expected_event = ChainEvents::Event::UpgradedEvent(ChainEvents::UpgradedEvent {
        event_id: 1,
        event_name: "bitcoin dev meetup",
        paid_amount: 20,
        event_type: EventType::Paid
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Caller Not Owner')]
fn test_upgrade_event_with_wrong_owner() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.upgrade_event(event_id, 20);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_unregister_from_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.unregister_from_event(event_id);
    let expected_event = ChainEvents::Event::UnregisteredEvent(ChainEvents::UnregisteredEvent {
        event_id: 1,
        user_address: USER_TWO()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let attendees = event_dispatcher.fetch_all_attendees_on_event(event_id);
    assert(attendees.len() == 0, 'Attendee count should be 0');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_pay_for_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IPaymentTokenDispatcher { contract_address: strk_token };

    let user_one = USER_ONE();
    let user_two = USER_TWO();
    let paid_amount: u256 = 1000000;

    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.upgrade_event(event_id, paid_amount);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(payment_token.allowance(user_two, event_contract_address) == paid_amount, 'approval failed');
    stop_cheat_caller_address(strk_token);

    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    assert(payment_token.balance_of(event_contract_address) == paid_amount, 'payment failed');
    assert(payment_token.balance_of(user_two) == 0, 'deduction failed');
}

#[test]
#[available_gas(2000000)]
fn test_pay_for_event_by_event_owner() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IPaymentTokenDispatcher { contract_address: strk_token };

    let user_one = USER_ONE();
    let paid_amount: u256 = 1000000;

    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.upgrade_event(event_id, paid_amount);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(strk_token, user_one);
    payment_token.mint(user_one, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(payment_token.allowance(user_one, event_contract_address) == paid_amount, 'approval failed');
    stop_cheat_caller_address(strk_token);

    start_cheat_caller_address(event_contract_address, user_one);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    assert(payment_token.balance_of(event_contract_address) == paid_amount, 'payment failed');
    assert(payment_token.balance_of(user_one) == 0, 'deduction failed');
}

#[test]
#[available_gas(2000000)]
fn test_pay_for_event_emits_event_on_success() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IPaymentTokenDispatcher { contract_address: strk_token };
    let mut spy = spy_events();

    let user_one = USER_ONE();
    let user_two = USER_TWO();
    let paid_amount: u256 = 1000000;

    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.upgrade_event(event_id, paid_amount);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(payment_token.allowance(user_two, event_contract_address) == paid_amount, 'approval failed');
    stop_cheat_caller_address(strk_token);

    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    let expected_event = ChainEvents::Event::EventPayment(ChainEvents::EventPayment {
        event_id: 1,
        caller: user_two,
        amount: paid_amount
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Not a Paid Event')]
fn test_pay_for_event_should_panic_for_free_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IPaymentTokenDispatcher { contract_address: strk_token };

    let user_one = USER_ONE();
    let user_two = USER_TWO();
    let paid_amount: u256 = 1000000;

    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(payment_token.allowance(user_two, event_contract_address) == paid_amount, 'approval failed');
    stop_cheat_caller_address(strk_token);

    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_get_paid_event_ticket_counts() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IPaymentTokenDispatcher { contract_address: strk_token };

    let user_one = USER_ONE();
    let user_two = USER_TWO();
    let paid_amount: u256 = 1000000;

    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.upgrade_event(event_id, paid_amount);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, paid_amount);
    payment_token.approve(event_contract_address, paid_amount);
    assert(payment_token.allowance(user_two, event_contract_address) == paid_amount, 'approval failed');
    stop_cheat_caller_address(strk_token);

    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    let ticket_count = event_dispatcher.paid_event_ticket_counts(event_id);
    assert(ticket_count == 1, 'Wrong number of tickets');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_get_events() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id_1 = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(event_id_1 == 1, 'First event ID incorrect');
    expected_events.append(event_dispatcher.event_details(event_id_1));
    let events = event_dispatcher.get_events();
    assert(events.len() == 1, 'Events length mismatch');
    assert(*events.at(0).event_id == 1, 'Wrong event ID');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    let event_id_2 = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(event_id_2 == 2, 'Second event ID incorrect');
    expected_events.append(event_dispatcher.event_details(event_id_2));
    let events = event_dispatcher.get_events();
    assert(events.len() == 2, 'Events length mismatch');
    assert(*events.at(1).event_id == 2, 'Wrong event ID');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_event_total_amount_paid() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    let amount = event_dispatcher.event_total_amount_paid(event_id);
    assert(amount == 0, 'Invalid amount');
}

#[test]
#[available_gas(2000000)]
fn test_events_by_organizer() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(event_id == 1, 'Event ID incorrect');
    let organizer_events = event_dispatcher.events_by_organizer(USER_ONE());
    assert(organizer_events.len() == 1, 'Wrong number of events');
    let first_event = *organizer_events.at(0);
    assert(first_event.organizer == USER_ONE(), 'Wrong organizer');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    let event_id_2 = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(event_id_2 == 2, 'Second event ID incorrect');
    let organizer_events = event_dispatcher.events_by_organizer(USER_ONE());
    assert(organizer_events.len() == 1, 'Wrong number of events');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_fetch_all_attendees_on_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(event_id == 1, 'Event ID incorrect');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.register_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_THREE());
    event_dispatcher.register_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    let all_attendees = event_dispatcher.fetch_all_attendees_on_event(event_id);
    assert(all_attendees.len() == 2, 'Wrong number of attendees');
    let first_attendee = *all_attendees.at(0);
    let second_attendee = *all_attendees.at(1);
    assert(first_attendee.attendee_address == USER_TWO(), 'Wrong first attendee');
    assert(second_attendee.attendee_address == USER_THREE(), 'Wrong second attendee');
}

#[test]
#[available_gas(2000000)]
fn test_get_open_events() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id_1 = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(event_id_1 == 1, 'First event ID incorrect');
    expected_events.append(event_dispatcher.event_details(event_id_1));
    let open_events = event_dispatcher.get_open_events();
    assert(open_events.len() == 1, 'Open events length mismatch');
    assert(*open_events.at(0).event_id == 1, 'Wrong open event');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    let event_id_2 = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(event_id_2 == 2, 'Second event ID incorrect');
    event_dispatcher.end_event_registration(event_id_2);
    let open_events = event_dispatcher.get_open_events();
    assert(open_events.len() == 1, 'Should only include open events');
    assert(*open_events.at(0).event_id == 1, 'Wrong open event');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_get_closed_events() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id_1 = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(event_id_1 == 1, 'First event ID incorrect');
    event_dispatcher.end_event_registration(event_id_1);
    expected_events.append(event_dispatcher.event_details(event_id_1));
    let closed_events = event_dispatcher.get_closed_events();
    assert(closed_events.len() == 1, 'Closed events length mismatch');
    assert(*closed_events.at(0).event_id == 1, 'Wrong closed event');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    let event_id_2 = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(event_id_2 == 2, 'Second event ID incorrect');
    let closed_events = event_dispatcher.get_closed_events();
    assert(closed_events.len() == 1, 'Should only include closed events');
    assert(*closed_events.at(0).event_id == 1, 'Wrong closed event');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_fetch_all_paid_events() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id_1 = event_dispatcher.add_event("Blockchain Conference", "Tech Park");
    assert(event_id_1 == 1, 'First event ID incorrect');
    let paid_amount: u256 = 1000000;
    event_dispatcher.upgrade_event(event_id_1, paid_amount);
    expected_events.append(event_dispatcher.event_details(event_id_1));
    let paid_events = event_dispatcher.fetch_all_paid_events();
    assert(paid_events.len() == 1, 'Paid events length mismatch');
    assert(*paid_events.at(0).event_id == 1, 'Wrong paid event');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    let event_id_2 = event_dispatcher.add_event("Ethereum Workshop", "Innovation Hub");
    assert(event_id_2 == 2, 'Second event ID incorrect');
    event_dispatcher.upgrade_event(event_id_2, paid_amount);
    expected_events.append(event_dispatcher.event_details(event_id_2));
    let paid_events = event_dispatcher.fetch_all_paid_events();
    assert(paid_events.len() == 2, 'Paid events length mismatch');
    assert(*paid_events.at(1).event_id == 2, 'Wrong paid event');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_fetch_all_unpaid_events() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    let mut expected_events = ArrayTrait::new();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id_1 = event_dispatcher.add_event("Blockchain Conference", "Zone Tech Park");
    assert(event_id_1 == 1, 'First event ID incorrect');
    expected_events.append(event_dispatcher.event_details(event_id_1));
    let unpaid_events = event_dispatcher.fetch_all_unpaid_events();
    assert(unpaid_events.len() == 1, 'Unpaid events length mismatch');
    assert(*unpaid_events.at(0).event_id == 1, 'Wrong unpaid event');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    let event_id_2 = event_dispatcher.add_event("Starknet ZK Stark Proof Workshop", "TheBuidl Hub");
    assert(event_id_2 == 2, 'Second event ID incorrect');
    expected_events.append(event_dispatcher.event_details(event_id_2));
    let unpaid_events = event_dispatcher.fetch_all_unpaid_events();
    assert(unpaid_events.len() == 2, 'Unpaid events length mismatch');
    assert(*unpaid_events.at(1).event_id == 2, 'Wrong unpaid event');
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_join_event_waitlist() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    event_dispatcher.update_event_max_capacity(event_id, 1); // Requires event to be closed first
    event_dispatcher.end_event_registration(event_id);
    event_dispatcher.open_event_registration(event_id);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.register_for_event(event_id); // Fill the event
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_THREE());
    event_dispatcher.join_event_waitlist(event_id);
    let waitlist = event_dispatcher.get_waitlist(event_id);
    assert(waitlist.len() == 1, 'Waitlist length mismatch');
    assert(*waitlist.at(0) == USER_THREE(), 'Wrong waitlist user');

    let expected_event = ChainEvents::Event::JoinEventWaitlist(ChainEvents::JoinEventWaitlist {
        event_id: 1,
        user_address: USER_THREE()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Event is not full')]
fn test_join_event_waitlist_not_full() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_THREE());
    event_dispatcher.join_event_waitlist(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_mark_attendance() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let mut spy = spy_events();

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.register_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_ONE());
    event_dispatcher.mark_attendance(event_id, USER_TWO());
    let attendees = event_dispatcher.fetch_all_attendees_on_event(event_id);
    assert(attendees.len() == 1, 'Wrong attendee count');
    let attendee_details = *attendees.at(0);
    assert(attendee_details.has_attended, 'Attendance not marked');
    assert(attendee_details.nft_token_id != 0, 'NFT not minted');

    let expected_event = ChainEvents::Event::EventAttendanceMark(ChainEvents::EventAttendanceMark {
        event_id: 1,
        user_address: USER_TWO()
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Not authorized')]
fn test_mark_attendance_wrong_owner() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };

    start_cheat_caller_address(event_contract_address, USER_ONE());
    let event_id = event_dispatcher.add_event("bitcoin dev meetup", "Dan Marna road");
    assert(event_id == 1, 'Event was not created');
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(event_contract_address, USER_TWO());
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.mark_attendance(event_id, USER_TWO());
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Caller Not Owner')]
fn test_only_owner_can_withdraw_paid_event_amount() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IPaymentTokenDispatcher { contract_address: strk_token };

    let user_one = USER_ONE();
    let user_two = USER_TWO();
    let event_fee: u256 = 100;

    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("Paid Workshop", "Devcon");
    event_dispatcher.upgrade_event(event_id, event_fee);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, event_fee);
    payment_token.approve(event_contract_address, event_fee);
    assert(payment_token.allowance(user_two, event_contract_address) == event_fee, 'Incorrect allowance');
    stop_cheat_caller_address(strk_token);

    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    assert(payment_token.balance_of(event_contract_address) == event_fee, 'Incorrect balance');

    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.withdraw_paid_event_amount(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: 'Event is not closed')]
fn test_withdraw_paid_event_amount_for_open_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IPaymentTokenDispatcher { contract_address: strk_token };

    let user_one = USER_ONE();
    let user_two = USER_TWO();
    let event_fee: u256 = 100;

    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("Paid Workshop", "Devcon");
    event_dispatcher.upgrade_event(event_id, event_fee);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, event_fee);
    payment_token.approve(event_contract_address, event_fee);
    assert(payment_token.allowance(user_two, event_contract_address) == event_fee, 'Incorrect allowance');
    stop_cheat_caller_address(strk_token);

    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    assert(payment_token.balance_of(event_contract_address) == event_fee, 'Incorrect balance');

    start_cheat_caller_address(event_contract_address, user_one);
    event_dispatcher.withdraw_paid_event_amount(event_id);
    stop_cheat_caller_address(event_contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_withdraw_paid_event_amount_for_closed_event() {
    let strk_token = deploy_token_contract();
    let nft_class = declare("EventNFT").unwrap();
    let event_contract_address = __setup__(strk_token, nft_class.class_hash);
    let event_dispatcher = IEventDispatcher { contract_address: event_contract_address };
    let payment_token = IPaymentTokenDispatcher { contract_address: strk_token };

    let user_one = USER_ONE();
    let user_two = USER_TWO();
    let event_fee: u256 = 100;

    start_cheat_caller_address(event_contract_address, user_one);
    let event_id = event_dispatcher.add_event("Paid Workshop", "Devcon");
    event_dispatcher.upgrade_event(event_id, event_fee);
    stop_cheat_caller_address(event_contract_address);

    start_cheat_caller_address(strk_token, user_two);
    payment_token.mint(user_two, event_fee);
    payment_token.approve(event_contract_address, event_fee);
    assert(payment_token.allowance(user_two, event_contract_address) == event_fee, 'Incorrect allowance');
    stop_cheat_caller_address(strk_token);

    start_cheat_caller_address(event_contract_address, user_two);
    event_dispatcher.register_for_event(event_id);
    event_dispatcher.pay_for_event(event_id);
    stop_cheat_caller_address(event_contract_address);

    assert(payment_token.balance_of(event_contract_address) == event_fee, 'Incorrect balance');

    start_cheat_caller_address(event_contract_address, user_one);
    event_dispatcher.end_event_registration(event_id);
    let mut spy = spy_events();
    event_dispatcher.withdraw_paid_event_amount(event_id);
    let expected_event = ChainEvents::Event::WithdrawalMade(ChainEvents::WithdrawalMade {
        event_id: 1,
        event_organizer: user_one,
        amount: event_fee
    });
    spy.assert_emitted(@array![(event_contract_address, expected_event)]);
    assert(payment_token.balance_of(event_contract_address) == 0, 'Incorrect contract balance');
    assert(payment_token.balance_of(user_one) == event_fee, 'Incorrect organizer balance');
    assert(payment_token.balance_of(user_two) == 0, 'Incorrect attendee balance');
    stop_cheat_caller_address(event_contract_address);
}