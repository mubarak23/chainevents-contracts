import express from "express";
import {
  add,
  all,
  deleteEventNft,
  fetchEventNft,
  fetchEventRegistrationAttendeesForOneEvent,
  fetchSingleEventDetails,
  search,
  updateEventNft,
  uploadEventNft,
  view,
  viewByEventId,
  viewByEventOwner,
} from "./../controllers/EventController.js";
import { validateRequest } from "./../middlewares/validation.js";
import { addNewSchema } from "./../validations/EventSchema.js";
import { cloudinaryUploadMiddleware } from "../middlewares/cloudinary.js";
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
router.post("/:event_id/nft", cloudinaryUploadMiddleware(), uploadEventNft);
router.patch("/:event_id/nft", cloudinaryUploadMiddleware(), updateEventNft);
router.get("/:event_id/nft", fetchEventNft);
router.delete("/:event_id/nft", deleteEventNft);

export default router;
