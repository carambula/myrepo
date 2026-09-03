ALTER TABLE devices
  ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE devices
  ADD COLUMN IF NOT EXISTS device_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS devices_key_idx
  ON devices (device_key)
  WHERE device_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS device_subscriptions (
  device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('pod', 'mov')),
  item_id TEXT NOT NULL,
  feed_url TEXT,
  title TEXT,
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (device_id, kind, item_id)
);

CREATE INDEX IF NOT EXISTS device_subscriptions_item_idx
  ON device_subscriptions (kind, item_id);

ALTER TABLE notification_queue
  ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE notification_queue
  ADD COLUMN IF NOT EXISTS device_id UUID REFERENCES devices(id) ON DELETE CASCADE;

ALTER TABLE notification_queue
  DROP CONSTRAINT IF EXISTS notification_queue_audience_chk;

ALTER TABLE notification_queue
  ADD CONSTRAINT notification_queue_audience_chk
  CHECK (user_id IS NOT NULL OR device_id IS NOT NULL);
