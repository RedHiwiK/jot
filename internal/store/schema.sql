CREATE TABLE IF NOT EXISTS projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  repo_path TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  color TEXT,
  repo_url TEXT
);
CREATE TABLE IF NOT EXISTS reqs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body_path TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'inbox',
  project_id INTEGER REFERENCES projects(id),
  priority INTEGER NOT NULL DEFAULT 0,
  origin_cwd TEXT,
  origin_note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  started_at INTEGER,
  finished_at INTEGER,
  done_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_reqs_state ON reqs(state);
CREATE INDEX IF NOT EXISTS idx_reqs_project ON reqs(project_id, state);
CREATE INDEX IF NOT EXISTS idx_reqs_updated ON reqs(updated_at DESC);
CREATE TABLE IF NOT EXISTS state_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  req_id INTEGER NOT NULL REFERENCES reqs(id),
  from_state TEXT,
  to_state TEXT NOT NULL,
  actor TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_state_log_req ON state_log(req_id, created_at DESC);
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- Tags are free-form labels (version numbers, themes). "Referenced means it exists":
-- there is no tag registry, so the tag list is SELECT DISTINCT over this table and
-- orphans disappear on their own.
CREATE TABLE IF NOT EXISTS req_tags (
  req_id INTEGER NOT NULL REFERENCES reqs(id),
  tag    TEXT    NOT NULL,
  PRIMARY KEY (req_id, tag)
);
CREATE INDEX IF NOT EXISTS idx_req_tags_tag ON req_tags(tag, req_id);
-- External links such as PRs/MRs, attached during implementation (jot link). Shown in the order added.
CREATE TABLE IF NOT EXISTS req_links (
  req_id     INTEGER NOT NULL REFERENCES reqs(id),
  url        TEXT    NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (req_id, url)
);
