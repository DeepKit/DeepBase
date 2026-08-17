-- Migration: Add next_run_at column to DeepBase_job_queue (PostgreSQL)
-- Applied by: TMigrationEngine.Migrate (PostgreSQL dialect)
-- Purpose:  Enable exponential-backoff scheduling for failed tasks.
--           Rows with next_run_at > now() are skipped by Dequeue.
--           Rows with next_run_at NULL are treated as "run immediately".

-- Idempotent: ADD COLUMN IF NOT EXISTS is supported by PG 9.6+.
ALTER TABLE DeepBase_job_queue
  ADD COLUMN IF NOT EXISTS next_run_at TIMESTAMP WITH TIME ZONE NULL;

-- Recreate the pending index so it can filter on next_run_at efficiently.
DROP INDEX IF EXISTS ix_DeepBase_job_queue_pending;
CREATE INDEX IF NOT EXISTS ix_DeepBase_job_queue_pending
  ON DeepBase_job_queue (queue_name, status, next_run_at, created_at);
