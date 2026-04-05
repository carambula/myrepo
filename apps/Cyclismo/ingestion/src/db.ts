import pg from "pg";
import dotenv from "dotenv";

dotenv.config();

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 4
});

export const query = (text: string, params?: unknown[]) =>
  pool.query(text, params);

export const closePool = async () => {
  await pool.end();
};
