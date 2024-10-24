import { verifyToken } from "./../utils/auth.js";
import { unauthorized } from "./../utils/response.js";
export const authenticateJWT = async (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) {
    return unauthorized(res);
  }
  try {
    const data = verifyToken(token);
    req.user = data;
    next();
  } catch (err) {
    return unauthorized(res);
  }
};
