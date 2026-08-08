PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY CHECK (length(id) BETWEEN 5 AND 16),
  goal_type TEXT NOT NULL,
  goal_payload TEXT NOT NULL CHECK (json_valid(goal_payload)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS goals_updated_at_idx ON goals(updated_at);

