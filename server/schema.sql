-- Koco community, D1 (SQLite). project/community-api.md; retro 6 (discuss/retro-6.md).
-- Times are ISO 8601 UTC text. Days are the person's own day in their fixed tz.

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,                 -- our id (uuid)
  apple_sub TEXT NOT NULL UNIQUE,      -- Sign in with Apple subject
  name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 30),
  tz TEXT NOT NULL DEFAULT 'UTC',      -- fixed at sign-up
  is_admin INTEGER NOT NULL DEFAULT 0,
  banned INTEGER NOT NULL DEFAULT 0,
  apple_refresh TEXT,                  -- from the authorization code, to revoke on deletion
  rules_version INTEGER NOT NULL DEFAULT 0,  -- the community rules agreed to (C4a)
  rules_at TEXT,
  leaving_at TEXT,                     -- deleting under way: no claims from here (retro 9)
  name_norm TEXT,                      -- the name as compared (S3); NULL: not yet settled
  pending_name TEXT,                   -- asked for, waiting for approval (shown to them only)
  pending_at TEXT,
  name_changed_at TEXT,
  must_rename INTEGER NOT NULL DEFAULT 0,  -- an earlier account holds their name
  shown_name TEXT,                     -- a turned-down name, still shown to them alone
  bio TEXT,                            -- a line on their page, approved (S2b)
  pending_bio TEXT,                    -- asked for, shown to them alone until approved
  pending_bio_at TEXT,
  shown_bio TEXT,                      -- turned down, still shown to them alone
  created_at TEXT NOT NULL
);

-- Sessions are rows, so they can be ended at once (ban, deletion, sign-out).
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,         -- sha256 of the bearer token
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);

-- Apple identity tokens already used (nonce replay).
CREATE TABLE IF NOT EXISTS used_nonces (
  nonce TEXT PRIMARY KEY,
  used_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS themes (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('daily', 'weekly', 'festival')),
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  title TEXT NOT NULL,                 -- JSON {lang: text}
  prompt TEXT NOT NULL,                -- JSON {lang: text}
  suggested_film TEXT,
  limited_film TEXT
);

CREATE TABLE IF NOT EXISTS posts (
  id TEXT PRIMARY KEY,
  author TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme_id TEXT NOT NULL REFERENCES themes(id),
  photo_key TEXT NOT NULL,
  thumb_key TEXT NOT NULL,
  film_id TEXT NOT NULL,
  caption TEXT CHECK (caption IS NULL OR length(caption) <= 80),
  taken_at TEXT,
  created_at TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'public', 'hidden')),
  like_count INTEGER NOT NULL DEFAULT 0,
  client_id TEXT,                      -- the app's id for this post: a retry returns the same post
  approved_at TEXT,                    -- when it went public: that day counts (user 11/24)
  approved_day TEXT,                   -- that day, in the author's own day
  approved_stamp TEXT                  -- which approval request it was (concurrent approvals count once)
);
CREATE UNIQUE INDEX IF NOT EXISTS posts_client ON posts(author, client_id);
CREATE INDEX IF NOT EXISTS posts_theme ON posts(theme_id, state, created_at DESC);
CREATE INDEX IF NOT EXISTS posts_author ON posts(author, created_at DESC);
CREATE INDEX IF NOT EXISTS posts_film ON posts(film_id, state, created_at DESC);
CREATE INDEX IF NOT EXISTS posts_latest ON posts(state, created_at DESC);

-- One row per person per own-day with a public post: the streak counts these.
-- A deleted post keeps its day (community-api.md).
CREATE TABLE IF NOT EXISTS checkins (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day TEXT NOT NULL,                   -- YYYY-MM-DD in the user's tz
  PRIMARY KEY (user_id, day)
);

CREATE TABLE IF NOT EXISTS likes (
  post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reporter TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('nudity', 'violence', 'hate', 'spam', 'not-koco', 'other')),
  note TEXT CHECK (note IS NULL OR length(note) <= 200),
  created_at TEXT NOT NULL,
  handled INTEGER NOT NULL DEFAULT 0,
  UNIQUE (post_id, reporter)
);

CREATE TABLE IF NOT EXISTS blocks (
  blocker TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (blocker, blocked)
);

-- A milestone reached is kept for good: it can be claimed after the streak breaks.
CREATE TABLE IF NOT EXISTS eligibility (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  milestone INTEGER NOT NULL CHECK (milestone IN (3, 7, 14)),
  reached_at TEXT NOT NULL,
  PRIMARY KEY (user_id, milestone)
);

CREATE TABLE IF NOT EXISTS rewards (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  milestone INTEGER NOT NULL CHECK (milestone IN (3, 7, 14)),
  film_id TEXT NOT NULL,
  claimed_at TEXT NOT NULL,
  PRIMARY KEY (user_id, milestone)
);

-- Uploads not yet in a post (cleaned after a day).
CREATE TABLE IF NOT EXISTS uploads (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  photo_key TEXT,
  thumb_key TEXT,
  created_at TEXT NOT NULL
);

-- A post's like count follows its likes, however they go (also when a liker leaves).
CREATE TRIGGER IF NOT EXISTS likes_added AFTER INSERT ON likes
BEGIN UPDATE posts SET like_count = like_count + 1 WHERE id = NEW.post_id; END;
CREATE TRIGGER IF NOT EXISTS likes_removed AFTER DELETE ON likes
BEGIN UPDATE posts SET like_count = max(like_count - 1, 0) WHERE id = OLD.post_id; END;

-- Apple grants still to revoke (leaving while Apple could not be reached, or before the key was set).
CREATE TABLE IF NOT EXISTS pending_revocations (
  refresh_token TEXT PRIMARY KEY,
  created_at TEXT NOT NULL
);

-- Rewards claimed by an Apple account that has left (hashed subject): a
-- rebuilt account can't claim them again (user 11/24).
CREATE TABLE IF NOT EXISTS departed_rewards (
  sub_hash TEXT NOT NULL,
  milestone INTEGER NOT NULL,
  PRIMARY KEY (sub_hash, milestone)
);

-- Every admin step (C2c): who did what to what, why, when.
CREATE TABLE IF NOT EXISTS admin_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin TEXT NOT NULL,                 -- kept even if that admin leaves
  action TEXT NOT NULL,
  target_kind TEXT NOT NULL,
  target TEXT NOT NULL,
  reason TEXT,
  created_at TEXT NOT NULL
);

-- Counters for rate limits, one row per person, step and window.
CREATE TABLE IF NOT EXISTS rate (
  key TEXT PRIMARY KEY,
  n INTEGER NOT NULL,
  expires_at TEXT NOT NULL
);

-- What admins should know: new reports, a long queue, usage nearing the free plan.
CREATE TABLE IF NOT EXISTS alerts (
  kind TEXT NOT NULL,
  day TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (kind, day)
);

-- Comments (C7, retro 7): plain text on the back of a picture, approved
-- before they show, like posts. One level, no links or pictures.
CREATE TABLE IF NOT EXISTS comments (
  id TEXT PRIMARY KEY,
  post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text TEXT NOT NULL CHECK (length(text) BETWEEN 1 AND 120),
  state TEXT NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'public', 'hidden')),
  client_id TEXT,
  created_at TEXT NOT NULL,
  approved_at TEXT
);
CREATE INDEX IF NOT EXISTS comments_post ON comments(post_id, state, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS comments_client ON comments(author, client_id);

CREATE TABLE IF NOT EXISTS comment_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  comment_id TEXT NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  reporter TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('nudity', 'violence', 'hate', 'spam', 'not-koco', 'other')),
  created_at TEXT NOT NULL,
  handled INTEGER NOT NULL DEFAULT 0,
  UNIQUE (comment_id, reporter)
);

-- When each person last looked at what's new for them (in-app unread).
CREATE TABLE IF NOT EXISTS seen (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  at TEXT NOT NULL
);

-- Left accounts whose picture prefix is cleared again later (an upload
-- may still have been on its way when they left; retro 8).
CREATE TABLE IF NOT EXISTS pending_purges (
  user_id TEXT PRIMARY KEY,
  passes INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

-- Messages to the admins (C6a): reports, a long queue, usage. One row per
-- merge key (reports in the same hour are one message); sent, retried with
-- growing waits, or failed after eight tries.
CREATE TABLE IF NOT EXISTS outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,
  merge_key TEXT NOT NULL UNIQUE,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 1,
  state TEXT NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'sending', 'sent', 'failed')),
  version INTEGER NOT NULL DEFAULT 1,  -- grows with each line added
  sent_len INTEGER NOT NULL DEFAULT 0, -- how much of the body has gone out
  attempts INTEGER NOT NULL DEFAULT 0,
  next_at TEXT NOT NULL,
  last_error TEXT,
  created_at TEXT NOT NULL,
  sent_at TEXT
);
CREATE INDEX IF NOT EXISTS outbox_due ON outbox(state, next_at);

-- Test Worker only: sends the fake sender should fail on purpose.
CREATE TABLE IF NOT EXISTS test_flags (
  key TEXT PRIMARY KEY,
  n INTEGER NOT NULL
);

-- Test Worker only: the fake sender's inbox (what would have been mailed).
CREATE TABLE IF NOT EXISTS test_mail (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  at TEXT NOT NULL
);

-- Names, one to a person (S3, user 11/25): held by their compared form,
-- whether in use or asked for and waiting for approval.
CREATE TABLE IF NOT EXISTS names (
  name_norm TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('current', 'pending')),
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS names_user ON names(user_id);

-- Following (S1, user 11/25): one way; nobody's totals are shown.
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
  handled INTEGER NOT NULL DEFAULT 0,
  handled_at TEXT                      -- the copy goes 90 days after this (user 11/25)
);
