import jwt from "jsonwebtoken";
import dotenv from "dotenv";
dotenv.config();

const secretKey = process.env.JWT_SECRET;

export const generateToken = (user, type = "user") => {
  return jwt.sign({ id: user.id, type: type }, secretKey, {
    expiresIn: "30d",
  });
};

export const verifyToken = (token) => {
  return jwt.verify(token, secretKey);
};
