pub mod Errors {
    pub const ZERO_ADDRESS_OWNER: felt252 = 'Owner cannot be zero addr';
    pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller cannot be zero addr';
    pub const NOT_OWNER: felt252 = 'Caller Not Owner';
    pub const CLOSED_EVENT: felt252 = 'Event is closed';
    pub const OPEN_EVENT: felt252 = 'Event is open';
    pub const ALREADY_REGISTERED: felt252 = 'Caller already registered';
    pub const NOT_REGISTERED: felt252 = 'rsvp only for registered event';
    pub const ALREADY_RSVP: felt252 = 'rsvp already exist';

    pub const INVALID_EVENT: felt252 = 'Invalid event';
    pub const EVENT_NOT_CLOSED: felt252 = 'Event is not closed';
    pub const EVENT_CLOSED: felt252 = 'Event closed';
    pub const ALREADY_MINTED: felt252 = 'Event NFT already minted';
    pub const NOT_TOKEN_OWNER: felt252 = 'Not Token Owner';
    pub const TOKEN_DOES_NOT_EXIST: felt252 = 'Token Does Not Exist';

    pub const NOT_A_PAID_EVENT: felt252 = 'Not a Paid Event';
    pub const TRANSFER_FAILED: felt252 = 'Transfer Failed';
    pub const PAYMENT_TOKEN_NOT_SET: felt252 = 'Payment Token Not Set';
}
