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
-- Retro 9: an account being deleted takes no more claims.
ALTER TABLE users ADD COLUMN leaving_at TEXT;

-- C18: the album by film, and everyone's latest
CREATE INDEX IF NOT EXISTS posts_film ON posts(film_id, state, created_at DESC);
CREATE INDEX IF NOT EXISTS posts_latest ON posts(state, created_at DESC);

-- S3 names (user 11/25)
ALTER TABLE users ADD COLUMN name_norm TEXT;
ALTER TABLE users ADD COLUMN pending_name TEXT;
ALTER TABLE users ADD COLUMN pending_at TEXT;
ALTER TABLE users ADD COLUMN name_changed_at TEXT;
ALTER TABLE users ADD COLUMN must_rename INTEGER NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS names (
  name_norm TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('current', 'pending')),
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS names_user ON names(user_id);

-- S1 following (user 11/25)
CREATE TABLE IF NOT EXISTS follows (
  follower TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (follower, followee)
);
CREATE INDEX IF NOT EXISTS follows_followee ON follows(followee, created_at DESC);

-- S4: the notices one has been shown ("read" = shown), each with its time;
-- a group that grows later is unread again. Marks older than 30 days are swept.
CREATE TABLE IF NOT EXISTS notice_marks (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  at TEXT NOT NULL,                    -- the version shown: its time
  n INTEGER NOT NULL,                  -- and how many it held
  PRIMARY KEY (user_id, key)
);
CREATE INDEX IF NOT EXISTS follows_followee_day ON follows(followee, created_at);
CREATE INDEX IF NOT EXISTS likes_post_time ON likes(post_id, created_at DESC);
-- A turned-down name stays visible to its author alone (user 11/25).
ALTER TABLE users ADD COLUMN shown_name TEXT;
-- S2b: a line on one's page, approved before others see it.
ALTER TABLE users ADD COLUMN bio TEXT;
ALTER TABLE users ADD COLUMN pending_bio TEXT;
ALTER TABLE users ADD COLUMN pending_bio_at TEXT;
ALTER TABLE users ADD COLUMN shown_bio TEXT;

-- S5: messages between two people who follow each other (pair = the two ids, smaller first).
CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  pair TEXT NOT NULL,
  sender TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text TEXT NOT NULL CHECK (length(text) BETWEEN 1 AND 300),
  client_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  read_at TEXT,
  UNIQUE (sender, client_id)
);
CREATE INDEX IF NOT EXISTS messages_pair ON messages(pair, created_at DESC);
CREATE INDEX IF NOT EXISTS messages_unread ON messages(recipient, read_at);
-- A report on messages keeps the last 20 as they were, for an admin.
CREATE TABLE IF NOT EXISTS dm_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reporter TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  transcript TEXT NOT NULL,
  created_at TEXT NOT NULL,
  handled INTEGER NOT NULL DEFAULT 0
);
-- Letter report copies go 90 days after handling (user 11/25).
ALTER TABLE dm_reports ADD COLUMN handled_at TEXT;

-- This week's picks (club left page, 11/27): an admin marks a public post.
CREATE TABLE IF NOT EXISTS picks (
  post_id TEXT PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
  picked_by TEXT NOT NULL,
  picked_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS picks_at ON picks(picked_at DESC);
