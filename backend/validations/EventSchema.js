import Joi from "joi";

export const addNewSchema = Joi.object({
  name: Joi.string().required().messages({
    "string.empty": "Name is required",
  }),
  event_id: Joi.string().required().messages({
    "string.empty": "Event ID is required",
  }),
  location: Joi.string().required().messages({
    "string.empty": "Location is required",
  }),
  event_owner: Joi.string().required().messages({
    "string.empty": "Event owner is required",
  }),
});
