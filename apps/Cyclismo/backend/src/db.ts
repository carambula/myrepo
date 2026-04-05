import pg from "pg";

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10
});

export const query = (text: string, params?: Array<string | number | null>) =>
  pool.query(text, params);

export const closePool = async () => {
  await pool.end();
};
