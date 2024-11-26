export const validateRequest = (schema) => {
  return (req, res, next) => {
    const { error } = schema.validate(req.body);

    if (error) {
      let msg = error.details[0].message;
      msg = msg.replaceAll("_", " ");
      msg = msg.replaceAll('"', "");
      return res.status(400).json({
        status: "error",
        message: msg,
      });
    }

    next();
  };
};
