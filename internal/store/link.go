package store

import (
	"database/sql"
	"strings"
	"time"

	"github.com/RedHiwiK/jot/internal/model"
)

// Links record the PRs/MRs for a requirement: an agent runs jot link after opening a PR,
// and the detail view lists them without searching or network access.

// loadLinks fills links for a set of requirements in one query, avoiding N+1 lookups.
func (s *Store) loadLinks(reqs []*model.Req) error {
	if len(reqs) == 0 {
		return nil
	}
	byID := make(map[int64]*model.Req, len(reqs))
	ph := make([]string, 0, len(reqs))
	args := make([]any, 0, len(reqs))
	for _, r := range reqs {
		r.Links = nil
		byID[r.ID] = r
		ph = append(ph, "?")
		args = append(args, r.ID)
	}
	rows, err := s.db.Query(`SELECT req_id, url FROM req_links
		WHERE req_id IN (`+strings.Join(ph, ",")+`) ORDER BY rowid`, args...)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var id int64
		var url string
		if err := rows.Scan(&id, &url); err != nil {
			return err
		}
		if r, ok := byID[id]; ok {
			r.Links = append(r.Links, url)
		}
	}
	return rows.Err()
}

// ReqLinks returns a requirement's links in the order they were added.
func (s *Store) ReqLinks(id int64) ([]string, error) {
	rows, err := s.db.Query(`SELECT url FROM req_links WHERE req_id = ? ORDER BY rowid`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var u string
		if err := rows.Scan(&u); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// AddLinks appends links, ignoring ones already present. It returns the full updated list.
func (s *Store) AddLinks(id int64, urls []string) ([]string, error) {
	return s.editLinks(id, func(tx *sql.Tx) error {
		now := time.Now().Unix()
		for _, u := range urls {
			if _, err := tx.Exec(`INSERT OR IGNORE INTO req_links (req_id, url, created_at) VALUES (?, ?, ?)`, id, u, now); err != nil {
				return err
			}
		}
		return nil
	})
}

// RemoveLinks removes the given links, or all of them when all is true. Unknown links are skipped silently.
func (s *Store) RemoveLinks(id int64, urls []string, all bool) ([]string, error) {
	return s.editLinks(id, func(tx *sql.Tx) error {
		if all {
			_, err := tx.Exec(`DELETE FROM req_links WHERE req_id = ?`, id)
			return err
		}
		for _, u := range urls {
			if _, err := tx.Exec(`DELETE FROM req_links WHERE req_id = ? AND url = ?`, id, u); err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Store) editLinks(id int64, edit func(*sql.Tx) error) ([]string, error) {
	if err := s.requireReq(id); err != nil {
		return nil, err
	}
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	if err := edit(tx); err != nil {
		return nil, err
	}
	if err := touchReq(tx, id); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return s.ReqLinks(id)
}

// purgeLinks deletes a requirement's links when it is purged (used by PurgeReq).
func purgeLinks(tx *sql.Tx, id int64) error {
	_, err := tx.Exec(`DELETE FROM req_links WHERE req_id = ?`, id)
	return err
}
