import Event from "./../models/Event.js";
import { success, failure } from "./../utils/response.js";

export const add = async (req, res) => {
  try {
    const { name, event_id, location, event_owner } = req.body;

    const event = await Event.create({
      name,
      event_id,
      location,
      event_owner,
    });

    return success(res, "successful", event, 201);
  } catch (err) {
    return failure(res, err.message, [], 500);
  }
};

export const all = async (req, res) => {
  try {
    const { page, limit } = req.query;
    let data = null;
    if (page || limit) {
      data = await Event.paginateData(page, limit);
    } else {
      data = await Event.all();
    }
    return success(res, "successful", data, 200);
  } catch (err) {
    return failure(res, err.message, [], 500);
  }
};

export const search = async (req, res) => {
  try {
    const { keyword } = req.query;
    const data = await Event.search(keyword);
    return success(res, "successful", data, 200);
  } catch (err) {
    return failure(res, err.message, [], 500);
  }
};

export const view = async (req, res) => {
  try {
    const { id } = req.params;
    const data = await Event.find(id);
    return success(res, "successful", data, 200);
  } catch (err) {
    return failure(res, err.message, [], 500);
  }
};

export const viewByEventId = async (req, res) => {
  try {
    const { event_id } = req.params;
    const data = await Event.findByEventId(event_id);
    return success(res, "successful", data, 200);
  } catch (err) {
    return failure(res, err.message, [], 500);
  }
};

export const viewByEventOwner = async (req, res) => {
  try {
    const { event_owner } = req.params;
    const data = await Event.findByEventOwner(event_owner);
    return success(res, "successful", data, 200);
  } catch (err) {
    return failure(res, err.message, [], 500);
  }
};

export const fetchSingleEventDetails = async (req, res) => {
  try {
    const { event_id } = req.params;

    const event = await Event.findByEventId(event_id);

    if (!event) {
      return failure(res, "Event not found", [], 404);
    }

    return success(res, "Event details fetched successfully", event, 200);
  } catch (err) {
    return failure(res, err.message, [], 500);
  }
};

export const fetchEventRegistrationAttendeesForOneEvent = async (req, res) => {
  try {
    const { event_id } = req.params;
    const { page = 1, limit = 10 } = req.query;

    const event = await Event.findByEventId(event_id);
    
    if (!event) {
      return failure(res, "Event not found", [], 404);
    }

    const registrations = await Event.getRegisteredUsersWithPagination(
      event_id,
      page,
      limit
    );

    return success(
      res,
      "Registered attendees fetched successfully",
      registrations,
      200
    );
  } catch (err) {
    return failure(res, err.message, [], 500);
  }
};
