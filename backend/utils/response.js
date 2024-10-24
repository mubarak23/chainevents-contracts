export const failure = (res, message = "failed", data = [], status = 500) => {
  res.status(status).json({
    success: false,
    message,
    data,
  });
};

export const success = (
  res,
  message = "successful",
  data = [],
  status = 200
) => {
  res.status(status).json({
    success: true,
    message,
    data,
  });
};

export const unauthorized = (res) => {
  res.status(401).json({
    success: false,
    message: "unauthorized",
  });
};
