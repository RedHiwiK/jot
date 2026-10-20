package store

import (
	"database/sql"
	"errors"
	"fmt"
)

// Config lives in the meta table rather than a separate toml file:
// the database already exists, and a kv table is simpler than maintaining another file format.

const (
	KeyEditor = "editor"
)

func (s *Store) GetConfig(key string) string {
	var v string
	err := s.db.QueryRow(`SELECT value FROM meta WHERE key = ?`, "cfg_"+key).Scan(&v)
	if errors.Is(err, sql.ErrNoRows) {
		return ""
	}
	return v
}

func (s *Store) SetConfig(key, value string) error {
	if key != KeyEditor {
		return fmt.Errorf("unknown setting %q (available: editor)", key)
	}
	if value == "" {
		_, err := s.db.Exec(`DELETE FROM meta WHERE key = ?`, "cfg_"+key)
		return err
	}
	_, err := s.db.Exec(
		`INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)`,
		"cfg_"+key, value)
	return err
}

func (s *Store) AllConfig() map[string]string {
	out := map[string]string{}
	rows, err := s.db.Query(`SELECT key, value FROM meta WHERE key = 'cfg_editor'`)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var k, v string
		if rows.Scan(&k, &v) == nil {
			out[k[4:]] = v
		}
	}
	return out
}
