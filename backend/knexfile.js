import dotenv from "dotenv";
dotenv.config();

const config = {
  development: {
    client: "sqlite3",
    connection: {
      filename: process.env.DB_FILENAME,
    },
    useNullAsDefault: true,
  },
  production: {
    client: "pg",
    connection: {
      connectionString: process.env.DB_URL,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
      ssl: process.env.DB_SSL ? { rejectUnauthorized: false } : false,
    },
    pool: {
      min: 2,
      max: 10,
    },
    migrations: {
      tableName: "knex_migrations",
    },
  },
  useNullAsDefault: true,
};

export default config;
