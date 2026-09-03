import pg from "pg";

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || "postgres://postgres:postgres@localhost:5433/mincloud",
  max: 10
});

export const query = (text: string, params?: unknown[]) => pool.query(text, params);

export const withTransaction = async <T,>(runner: (client: pg.PoolClient) => Promise<T>) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await runner(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};

export const closePool = async () => {
  await pool.end();
};

export type QueryResultRow = pg.QueryResultRow;
