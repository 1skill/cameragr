-- Changes to a database made from an older schema.sql, in order; each runs
-- once (tools/cf_deploy.py --migrate skips what is already there).
-- C2b (11/24): posts wait for approval; a retry id; when approved.
ALTER TABLE posts ADD COLUMN client_id TEXT;
ALTER TABLE posts ADD COLUMN approved_at TEXT;
-- Retro 7: a post's approval day, and which request approved it.
ALTER TABLE posts ADD COLUMN approved_day TEXT;
ALTER TABLE posts ADD COLUMN approved_stamp TEXT;
-- C4a: the community rules each person agreed to.
ALTER TABLE users ADD COLUMN rules_version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN rules_at TEXT;
