import { Indexer, IndexerRunner } from "@apibara/indexer";
import { StarkNetEvent } from "@apibara/protocol";
import { RawEvent } from "@apibara/protocol/starknet";
import { prisma } from "../db";
import express from "express";

const CONTRACT_ADDRESS =
  "0x00c1bf18fbad102df788918aea78c48cea5637a9be1f2ddc8fcf0839d9dc8abb";

const EVENT_KEYS = {
  NEW_EVENT_ADDED:
    "0x007071a624828cf7f8ad801fd89bd1e8886d916964a0799652034daab54c6551",
  REGISTERED_FOR_EVENT:
    "0x00b7cb78e6c73aa302bba8b99f537ce645f6755e6d1d1e39138e81742d9e0988",
  END_EVENT_REGISTRATION:
    "0x03ba3cfdeaeb0a6ab6764f8cad48d98ebdabfd13fb28771cbe7f2fb168369245",
  RSVP_FOR_EVENT:
    "0x00dacb36075353c090f2e5d777b63a4eddda41699b7d7509bb72f081d80ae3a7",
  UPGRADED_EVENT:
    "0x01d66aa12377f012013ea3290cf9936bd22c40d1287b7ec452e831e2663b9ef7",
  UNREGISTERED_EVENT:
    "0x025e6211280fb0f251e869157cfb958b58dc63614661b338b5ed159b92307174",
};

export class ChainEventsIndexer implements Indexer {
  async *handleEvents(events: StarkNetEvent[]): AsyncGenerator<void> {
    for (const event of events) {
      try {
        const rawEvent = event as RawEvent;
        const parsedData = this.parseEventData(rawEvent);
        await this.saveEvent(parsedData);
        console.log(
          `Indexed event: ${parsedData.eventType} for event ID: ${parsedData.eventId}`
        );
      } catch (error) {
        console.error("Error processing event:", error);
      }
    }
  }

  private parseEventData(rawEvent: RawEvent) {
    const eventKey = rawEvent.keys[0];
    const data = rawEvent.data;

    switch (eventKey) {
      case EVENT_KEYS.NEW_EVENT_ADDED:
        return {
          eventType: "NewEventAdded",
          name: data[0],
          eventId: data[1],
          location: data[2],
          eventOwner: data[3],
        };

      case EVENT_KEYS.REGISTERED_FOR_EVENT:
        return {
          eventType: "RegisteredForEvent",
          eventId: data[0],
          name: data[1],
          userAddress: data[2],
        };

      case EVENT_KEYS.OPEN_EVENT_REGISTRATION:
        return {
          eventType: "OpenEventRegistration",
          eventId: data[0],
          name: data[1],
          eventOwner: data[2],
        };

      case EVENT_KEYS.END_EVENT_REGISTRATION:
        return {
          eventType: "EndEventRegistration",
          eventId: data[0],
          name: data[1],
          eventOwner: data[2],
        };

      case EVENT_KEYS.RSVP_FOR_EVENT:
        return {
          eventType: "RSVPForEvent",
          eventId: data[0],
          userAddress: data[1],
        };

      case EVENT_KEYS.UPGRADED_EVENT:
        return {
          eventType: "UpgradedEvent",
          eventId: data[0],
          name: data[1],
          paidAmount: data[2],
        };

      case EVENT_KEYS.UNREGISTERED_EVENT:
        return {
          eventType: "UnregisteredEvent",
          eventId: data[0],
          userAddress: data[1],
        };

      case EVENT_KEYS.EVENT_ATTENDANCE_MARK:
        return {
          eventType: "EventAttendanceMark",
          eventId: data[0],
          userAddress: data[1],
        };

      case EVENT_KEYS.EVENT_PAYMENT:
        return {
          eventType: "EventPayment",
          eventId: data[0],
          userAddress: data[1],
          paidAmount: data[2],
        };

      case EVENT_KEYS.WITHDRAWAL_MADE:
        return {
          eventType: "WithdrawalMade",
          eventId: data[0],
          eventOwner: data[1],
          paidAmount: data[2],
        };

      default:
        throw new Error(`Unknown event key: ${eventKey}`);
    }
  }

  private async saveEvent(eventData: any) {
    await prisma.chainEvent.create({
      data: {
        ...eventData,
        eventId: eventData.eventId.toString(),
        paidAmount: eventData.paidAmount?.toString(),
      },
    });
  }

  getFilter() {
    return {
      header: { weak: true },
      events: [
        {
          fromAddress: CONTRACT_ADDRESS,
          keys: Object.values(EVENT_KEYS),
        },
      ],
    };
  }
}

const router = express.Router();

router.get("/events", async (req, res) => {
  try {
    const { eventType, eventId, limit = 100 } = req.query;

    const where: any = {};
    if (eventType) where.eventType = eventType;
    if (eventId) where.eventId = eventId;

    const events = await prisma.chainEvent.findMany({
      where,
      orderBy: { timestamp: "desc" },
      take: Number(limit),
    });
    res.json(events);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch events" });
  }
});

export { router as eventsRouter };
