import express from "express";
import {
  add,
  all,
  fetchEventRegistrationAttendeesForOneEvent,
  fetchSingleEventDetails,
  search,
  view,
  viewByEventId,
  viewByEventOwner,
} from "./../controllers/EventController.js";
import { validateRequest } from "./../middlewares/validation.js";
import { addNewSchema } from "./../validations/EventSchema.js";
const router = express.Router();

router.post("/", validateRequest(addNewSchema), add);
router.get("/", all);
router.get("/search", search);
router.get("/id/:event_id", viewByEventId);
router.get("/owner/:event_owner", viewByEventOwner);
router.get("/:id", view);
router.get("/:event_id/details", fetchSingleEventDetails);
router.get(
  "/:event_id/registrations",
  fetchEventRegistrationAttendeesForOneEvent
);

export default router;
