import { 
    NewEventAdded, 
    RegisteredForEvent, 
    EventAttendanceMark, 
    EndEventRegistration, 
    RSVPForEvent 
} from "./types";
import { v1alpha2 as starknet } from '@apibara/starknet';

export async function handleNewEventAdded(event: starknet.IEvent) {
    console.log(event);
}

export async function handleRegisteredForEvent(event: starknet.IEvent) {
    console.log(event);
}

export async function handleEventAttendanceMark(event: starknet.IEvent) {
    console.log(event);
}

export async function handleEndEventRegistration(event: starknet.IEvent) {
    console.log(event);
}

export async function handleRSVPForEvent(event: starknet.IEvent) {
    console.log(event);
}