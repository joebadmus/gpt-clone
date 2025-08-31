-- Create the health check table
CREATE TABLE IF NOT EXISTS "_health_check" (
  id SERIAL PRIMARY KEY,
  status TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
