pub mod Errors {
    pub const ZERO_ADDRESS_OWNER: felt252 = 'Owner cannot be zero addr';
    pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller cannot be zero addr';
    pub const NOT_OWNER: felt252 = 'Caller Not Owner';
    pub const CLOSED_EVENT: felt252 = 'Event is closed';
    pub const ALREADY_REGISTERED: felt252 = 'Caller already registered';
    pub const NOT_REGISTERED: felt252 = 'rsvp only for registered event';
    pub const ALREADY_RSVP: felt252 = 'rsvp already exist';

    pub const INVALID_EVENT: felt252 = 'Invalid event';
    pub const EVENT_CLOSED: felt252 = 'Event closed';
    pub const ALREADY_MINTED: felt252 = 'Event NFT already minted';
    pub const NOT_TOKEN_OWNER: felt252 = 'Not Token Owner';
    pub const TOKEN_DOES_NOT_EXIST: felt252 = 'Token Does Not Exist';
    pub const EVENT_NOT_PAID: felt252 = 'Event is not paid';

    pub const GROUP_ID_EXISTS: felt252 = 'Group ID Already In Use';
    pub const INVALID_MAX_MEMBERS: felt252 = 'Maximum Member Must Be > 0';
    pub const INVALID_CONTRIBUTION: felt252 = 'Contribution Amount Must Be > 0';
    pub const INVALID_DURATION: felt252 = 'Duration Must Be > 0';
    pub const PAYOUT_ORDER_MISMATCH: felt252 = 'Payout Order Mismatch';
    pub const DUPLICATE_ADDRESS: felt252 = 'Duplicate Address Detected';
    pub const GROUP_NOT_FOUND: felt252 = 'Group Not Found';
    pub const GROUP_NOT_ACCEPTING_MEMBERS: felt252 = 'Group Not Accepting Members';
    pub const MEMBER_ALREADY_IN_GROUP: felt252 = 'Member Already In Group';
    pub const GROUP_FULL: felt252 = 'Group Is Full';

    pub const NOT_CREATOR: felt252 = 'Caller Is Not Group Creator';
    pub const GROUP_ACTIVE: felt252 = 'Group Is Already Active';
    pub const GROUP_NOT_FULL: felt252 = 'Group Is Not Yet Full';
    pub const GROUP_ROUNDS_COMPLETED: felt252 = 'Group RoundS Already Completed';
}
