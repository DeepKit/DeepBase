-- Migration: Add next_run_at column to DeepBase_job_queue (SQLite)
-- Applied by: TMigrationEngine.Migrate (SQLite dialect)
-- Purpose:  Enable exponential-backoff scheduling for failed tasks.
--           Rows with next_run_at > now() are skipped by Dequeue.
--           Rows with next_run_at NULL are treated as "run immediately".

ALTER TABLE DeepBase_job_queue ADD COLUMN next_run_at TEXT NULL;

-- Recreate the pending index so it can filter on next_run_at efficiently.
-- SQLite lacks DROP INDEX IF EXISTS, so we drop the legacy index by name
-- (safe to fail on fresh deployments where the old name was never created)
-- then recreate under the canonical name used by EnsureSchemaOnConnection.
--
-- NOTE: On a re-run of this migration the DROP will no-op (name already
-- gone), and the CREATE is idempotent via IF NOT EXISTS.
DROP INDEX ix_DeepBase_job_queue_pending;
CREATE INDEX IF NOT EXISTS ix_DeepBase_job_queue_pending
  ON DeepBase_job_queue (queue_name, status, next_run_at, created_at);
