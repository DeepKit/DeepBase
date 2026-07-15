-- Migration: Create the dedicated dead-letter queue table (SQLite)
-- Applied by: TMigrationEngine.Migrate (SQLite dialect)
-- Purpose:  Move exhausted/repeatedly-failed tasks out of the hot-path
--           DeepBase_job_queue so Dequeue stays fast and ops get a
--           dedicated inspection surface (PeekDeadLetters / Replay / Purge).

CREATE TABLE IF NOT EXISTS DeepBase_job_queue_dlq (
  original_id  TEXT PRIMARY KEY,
  queue_name   TEXT NOT NULL,
  logical_key  TEXT NOT NULL,
  payload      TEXT NOT NULL DEFAULT '{}',
  attempts     INTEGER NOT NULL DEFAULT 0,
  last_error   TEXT,
  created_at   TEXT NOT NULL,
  moved_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_DeepBase_job_queue_dlq_queue_moved
  ON DeepBase_job_queue_dlq (queue_name, moved_at DESC);
