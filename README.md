# Contract Implementation

Create Event
Fetch my event (Backend Service)
Register for an event
RSVP for an event
Mint POA for an Event RSVP
Fetch all Register Attendee of an event

## Deep Implementation Details

Each event will have a uniqueId
Map create event function call with event 
Map <eventOwnerAddress, EventDetailsStruct>

User can register for multiple event
Map Event UniqueId to Register user address – EventRegisterUser

Map Event UniqueId to Register user address – EventRSVPUsers

User the EventRSVPUsers Map to MINT POA NFT
