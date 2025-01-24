import { StreamClient, v1alpha2 } from "@apibara/protocol";
import {
  FieldElement,
  Filter,
  v1alpha2 as starknet,
  StarkNetCursor,
} from "@apibara/starknet";
import { events } from "../config/events";
import {
  handleNewEventAdded,
  handleRegisteredForEvent,
  handleEventAttendanceMark,
  handleEndEventRegistration,
  handleRSVPForEvent,
} from "./handlers";

const client = new StreamClient({
  url: process.env.DNA_CLIENT_URL!,
  clientOptions: {
    "grpc.max_receive_message_length": 100 * 1024 * 1024, // 100MB
  },
  token: process.env.DNA_TOKEN,
});

// Create filter combining all event handlers
const filter = Filter.create().withHeader({ weak: true });

// Map your events to handlers
const eventHandlers: Record<string, (event: starknet.IEvent) => Promise<void>> =
  {
    [events.NewEventAdded]: handleNewEventAdded,
    [events.RegisteredForEvent]: handleRegisteredForEvent,
    [events.EventAttendanceMark]: handleEventAttendanceMark,
    [events.EndEventRegistration]: handleEndEventRegistration,
    [events.RSVPForEvent]: handleRSVPForEvent,
  };

// Add all events to filter
Object.keys(eventHandlers).forEach((eventKey) => {
  filter.addEvent((event) =>
    event.withKeys([FieldElement.fromBigInt(BigInt(eventKey))]),
  );
});

// Start indexer function
export async function startIndexer() {
  client.configure({
    filter: filter.encode(),
    batchSize: 1,
    finality: v1alpha2.DataFinality.DATA_STATUS_FINALIZED,
    cursor: StarkNetCursor.createWithBlockNumber(0),
  });

  for await (const message of client) {
    if (message.message === "data") {
      const { data } = message.data!;
      for (const item of data) {
        const block = starknet.Block.decode(item);
        for (const event of block.events) {
          if (!event.event) continue;
          const eventKey = FieldElement.toHex(event.event.keys![0]);
          const handler = eventHandlers[eventKey];
          if (handler) {
            await handler(event.event);
          }
        }
      }
    }
  }
}
