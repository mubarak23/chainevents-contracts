pub mod Errors {
    pub const ZERO_ADDRESS_OWNER: felt252 = 'Owner cannot be zero addr';
    pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller cannot be zero addr';
    pub const NOT_OWNER: felt252 = 'Caller Not Owner';
    pub const INVALID_EVENT: felt252 = 'Invalid event';
    pub const EVENT_CLOSED: felt252 = 'Event closed';
}
