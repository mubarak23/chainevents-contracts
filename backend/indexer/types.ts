export type NewEventAdded = {
    name: string;
    event_id: number;
    location: string;
    event_owner: string;
};

export type RegisteredForEvent = {
    event_id: number;
    event_name: string;
    user_address: string;
};

export type EndEventRegistration = {
    event_id: number;
    event_name: string;
    event_owner: string;
};

export type RSVPForEvent = {
    event_id: number;
    attendee_address: string;
};

export type EventAttendanceMark = {
    event_id: number;
    user_address: string;
};
