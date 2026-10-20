// Package store reads and writes the SQLite database and markdown files.
//
// SQLite owns state and queries; markdown owns the body text.
// Markdown is the single source of truth for the body; SQLite stores the path and the title used in lists.
package store

import (
	"database/sql"
	_ "embed"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

//go:embed schema.sql
var schemaSQL string

type Store struct {
	db   *sql.DB
	root string // ~/.jot
}

// Root returns the data root directory; JOT_HOME overrides it (used by tests).
func Root() (string, error) {
	if r := os.Getenv("JOT_HOME"); r != "" {
		return r, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".jot"), nil
}

func (s *Store) Root() string    { return s.root }
func (s *Store) ReqsDir() string { return filepath.Join(s.root, "reqs") }
func (s *Store) DB() *sql.DB     { return s.db }
func (s *Store) Close() error    { return s.db.Close() }

// Open opens the database, creating it if needed.
func Open() (*Store, error) {
	root, err := Root()
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Join(root, "reqs"), 0o755); err != nil {
		return nil, fmt.Errorf("create data directory: %w", err)
	}

	dbPath := filepath.Join(root, "jot.db")
	db, err := sql.Open("sqlite", dbPath+"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)")
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}
	if _, err := db.Exec(schemaSQL); err != nil {
		db.Close()
		return nil, fmt.Errorf("initialize schema: %w", err)
	}
	return &Store{db: db, root: root}, nil
}

// Exists reports whether the database has been initialized.
func Exists() bool {
	root, err := Root()
	if err != nil {
		return false
	}
	_, err = os.Stat(filepath.Join(root, "jot.db"))
	return err == nil
}
