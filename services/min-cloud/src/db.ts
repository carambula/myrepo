import pg from "pg";

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || "postgres://postgres:postgres@localhost:5433/mincloud",
  max: 10
});

export const query = (text: string, params?: unknown[]) => pool.query(text, params);

export const closePool = async () => {
  await pool.end();
};

export type QueryResultRow = pg.QueryResultRow;
