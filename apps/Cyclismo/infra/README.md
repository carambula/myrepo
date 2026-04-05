Bootstrap the database and start the API with Docker:

1) Run compose:
   - `docker compose up --build`

This starts Postgres, runs ingestion bootstrap once with default sources, and serves the API on `http://localhost:4000`.
