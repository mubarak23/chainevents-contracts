import { Indexer, IndexerRunner } from "@apibara/indexer";
import { StarkNetEvent } from "@apibara/protocol";
import { RawEvent } from "@apibara/protocol/starknet";
import { prisma } from "../db";
import express from "express";

const CONTRACT_ADDRESS =
  "0x01913600de72b1a698430c76c233d687d0aac3f4380127db208e48e18ba76a42";

const EVENT_KEYS = [
  // Add your event keys here
];

export class ChainEventsIndexer implements Indexer {
  async *handleEvents(events: StarkNetEvent[]): AsyncGenerator<void> {
    for (const event of events) {
      try {
        const rawEvent = event as RawEvent;
        const parsedData = this.parseEventData(rawEvent);
        await this.saveEvent(parsedData);
        console.log(`Indexed event: ${rawEvent.keys[0]}`);
      } catch (error) {
        console.error("Error processing event:", error);
      }
    }
  }

  private parseEventData(rawEvent: RawEvent) {
    const eventKey = rawEvent.keys[0];
    switch (eventKey) {
      case EVENT_KEYS[0]:
        return {
          type: "example_event",
          data: rawEvent.data,
          timestamp: new Date(),
        };
      default:
        throw new Error(`Unknown event key: ${eventKey}`);
    }
  }

  private async saveEvent(eventData: any) {
    await prisma.chainEvent.create({
      data: eventData,
    });
  }

  getFilter() {
    return {
      header: { weak: true },
      events: [
        {
          fromAddress: CONTRACT_ADDRESS,
          keys: EVENT_KEYS,
        },
      ],
    };
  }
}

// Router setup
const router = express.Router();

router.get("/events", async (req, res) => {
  try {
    const events = await prisma.chainEvent.findMany({
      orderBy: { timestamp: "desc" },
      take: 100,
    });
    res.json(events);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch events" });
  }
});

export { router as eventsRouter };
