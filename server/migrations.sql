-- Changes to a database made from an older schema.sql, in order; each runs
-- once (tools/cf_deploy.py --migrate skips what is already there).
-- C2b (11/24): posts wait for approval; a retry id; when approved.
ALTER TABLE posts ADD COLUMN client_id TEXT;
ALTER TABLE posts ADD COLUMN approved_at TEXT;
