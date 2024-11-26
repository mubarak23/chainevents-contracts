import knex from "knex";
import dotenv from "dotenv";
import config from "./../knexfile.js";
dotenv.config();

const db = knex(config[process.env.NODE_ENV]);

export default db;
