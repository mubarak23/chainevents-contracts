import { FieldElement, v1alpha2 as starknet } from '@apibara/starknet';
import Event from "../models/Event.js";
import { uint256 } from 'starknet';
import { hexToAscii } from "../utils/tohexAscii.js";

export async function handleNewEventAdded(event) {
    const data = event.data;

    const eventDetails = {
        name: hexToAscii(FieldElement.toHex(data[0]).toString()),
        event_id: parseInt(uint256
        .uint256ToBN({
          low: FieldElement.toBigInt(data[1]),
          high: FieldElement.toBigInt(data[2]),
        })
        .toString()),
        location: hexToAscii(FieldElement.toHex(data[3]).toString()),
        event_owner: FieldElement.toHex(data[4]).toString()
    };

    //Debugging purposes
    console.log(eventDetails);

    const eventExists = await Event.findByEventId(eventDetails.event_id);
    if (eventExists) {
        console.log("Event already exists");
        return;
    }
    await Event.create(eventDetails);
}

export async function handleRegisteredForEvent(event) {
    const data = event.data;

    const registeredForEvent = {
        event_id: parseInt(uint256
        .uint256ToBN({
          low: FieldElement.toBigInt(data[0]),
          high: FieldElement.toBigInt(data[1]),
        })
        .toString()),
        event_name: hexToAscii(FieldElement.toHex(data[2]).toString()),
        user_address: FieldElement.toHex(data[3]).toString()
    };

    console.log(registeredForEvent);

    const hasRegistered = await Event.isUserRegistered(registeredForEvent.event_id, registeredForEvent.user_address);
    if (hasRegistered) {
        console.log("User has already registered");
        return;
    }
    await Event.registerUser(registeredForEvent.event_id, registeredForEvent.user_address);
}

export async function handleEventAttendanceMark(event) {
    const data = event.data;

    const eventAttendanceMark = {
        event_id: parseInt(uint256
        .uint256ToBN({
          low: FieldElement.toBigInt(data[0]),
          high: FieldElement.toBigInt(data[1]),
        })
        .toString()),
        user_address: FieldElement.toHex(data[2]).toString()
    };

    console.log(eventAttendanceMark);

    const hasMarkedAttendance = await Event.hasUserAttended(eventAttendanceMark.event_id, eventAttendanceMark.user_address);
    if (hasMarkedAttendance) {
        console.log("User has already marked attendance");
        return;
    }
    await Event.markAttendance(eventAttendanceMark.event_id, eventAttendanceMark.user_address);
}

export async function handleEndEventRegistration(event) {
    const data = event.data;

    const endEventRegistration = {
        event_id: parseInt(uint256
        .uint256ToBN({
          low: FieldElement.toBigInt(data[0]),
          high: FieldElement.toBigInt(data[1]),
        })
        .toString()),
        event_name: hexToAscii(FieldElement.toHex(data[2]).toString()),
        event_owner: FieldElement.toHex(data[3]).toString()
    };

    console.log(endEventRegistration);

    const eventExists = await Event.findByEventId(endEventRegistration.event_id);
    if (!eventExists) {
        console.log("Event does not exist");
        return;
    }
    await Event.endRegistration(endEventRegistration.event_id);
}

export async function handleRSVPForEvent(event) {
    const data = event.data;

    const rsvpForEvent = {
        event_id: parseInt(uint256
        .uint256ToBN({
          low: FieldElement.toBigInt(data[0]),
          high: FieldElement.toBigInt(data[1]),
        })
        .toString()),
        attendee_address: FieldElement.toHex(data[2]).toString()
    };

    console.log(rsvpForEvent);

    const hasRSVPed = await Event.hasUserRSVPed(rsvpForEvent.event_id, rsvpForEvent.attendee_address);
    if (hasRSVPed) {
        console.log("User has already RSVPed");
        return;
    }
    await Event.addRSVP(rsvpForEvent.event_id, rsvpForEvent.attendee_address);
}