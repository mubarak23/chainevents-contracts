pub mod Errors {
    pub const ZERO_ADDRESS_OWNER: felt252 = 'Owner cannot be zero addr';
    pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller cannot be zero addr';
    pub const NOT_OWNER: felt252 = 'Caller Not Owner';
    pub const CLOSED_EVENT: felt252 = 'Event is closed';
    pub const ALREADY_REGISTERED: felt252 = 'Caller already registered';
    pub const NOT_REGISTERED: felt252 = 'rsvp only for registered event';
    pub const ALREADY_RSVP: felt252 = 'rsvp already exist';
}
