package store

import (
	"database/sql"
	"fmt"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
)

// A tag exists as long as it is referenced: there is no registry, any tag in req_tags exists,
// and it disappears when its last reference is removed. This avoids separate CRUD and orphan cleanup.

// TagCount is a tag and its reference count, used by jot tag ls and the GUI sidebar.
type TagCount struct {
	Tag   string
	Count int
}

// loadTags fills tags for a set of requirements in one query, avoiding N+1 lookups.
func (s *Store) loadTags(reqs []*model.Req) error {
	if len(reqs) == 0 {
		return nil
	}
	byID := make(map[int64]*model.Req, len(reqs))
	ph := make([]string, 0, len(reqs))
	args := make([]any, 0, len(reqs))
	for _, r := range reqs {
		r.Tags = nil
		byID[r.ID] = r
		ph = append(ph, "?")
		args = append(args, r.ID)
	}

	rows, err := s.db.Query(`SELECT req_id, tag FROM req_tags
		WHERE req_id IN (`+strings.Join(ph, ",")+`) ORDER BY tag`, args...)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var id int64
		var tag string
		if err := rows.Scan(&id, &tag); err != nil {
			return err
		}
		if r, ok := byID[id]; ok {
			r.Tags = append(r.Tags, tag)
		}
	}
	return rows.Err()
}

// ReqTags returns a requirement's tags in alphabetical order.
func (s *Store) ReqTags(id int64) ([]string, error) {
	rows, err := s.db.Query(`SELECT tag FROM req_tags WHERE req_id = ? ORDER BY tag`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// AddTags adds tags incrementally, leaving existing ones alone. It returns the full updated set.
func (s *Store) AddTags(id int64, tags []string) ([]string, error) {
	if err := s.requireReq(id); err != nil {
		return nil, err
	}
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	for _, t := range tags {
		if _, err := tx.Exec(`INSERT OR IGNORE INTO req_tags (req_id, tag) VALUES (?, ?)`, id, t); err != nil {
			return nil, err
		}
	}
	if err := touchReq(tx, id); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return s.ReqTags(id)
}

// RemoveTags removes the given tags; missing tags are skipped silently.
func (s *Store) RemoveTags(id int64, tags []string) ([]string, error) {
	if err := s.requireReq(id); err != nil {
		return nil, err
	}
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	for _, t := range tags {
		if _, err := tx.Exec(`DELETE FROM req_tags WHERE req_id = ? AND tag = ?`, id, t); err != nil {
			return nil, err
		}
	}
	if err := touchReq(tx, id); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return s.ReqTags(id)
}

// SetTags replaces all tags. An empty slice clears them.
func (s *Store) SetTags(id int64, tags []string) ([]string, error) {
	if err := s.requireReq(id); err != nil {
		return nil, err
	}
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`DELETE FROM req_tags WHERE req_id = ?`, id); err != nil {
		return nil, err
	}
	for _, t := range tags {
		if _, err := tx.Exec(`INSERT OR IGNORE INTO req_tags (req_id, tag) VALUES (?, ?)`, id, t); err != nil {
			return nil, err
		}
	}
	if err := touchReq(tx, id); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return s.ReqTags(id)
}

// ListTags summarizes all tags with reference counts. When includeDone is false only open requirements
// are counted, so sidebar counts match what the board shows.
func (s *Store) ListTags(includeDone bool) ([]TagCount, error) {
	q := `SELECT t.tag, COUNT(*) FROM req_tags t JOIN reqs r ON r.id = t.req_id`
	if !includeDone {
		q += ` WHERE r.state NOT IN ('done','archived')`
	}
	q += ` GROUP BY t.tag ORDER BY t.tag`

	rows, err := s.db.Query(q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []TagCount
	for rows.Next() {
		var tc TagCount
		if err := rows.Scan(&tc.Tag, &tc.Count); err != nil {
			return nil, err
		}
		out = append(out, tc)
	}
	return out, rows.Err()
}

// RenameTag renames a tag everywhere and returns the affected requirement IDs.
// If a requirement already has the target tag they are merged (INSERT OR IGNORE), so no duplicate rows appear.
func (s *Store) RenameTag(from, to string) ([]int64, error) {
	ids, err := s.reqIDsWithTag(from)
	if err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return nil, fmt.Errorf("tag %q is not in use", from)
	}
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	for _, id := range ids {
		if _, err := tx.Exec(`INSERT OR IGNORE INTO req_tags (req_id, tag) VALUES (?, ?)`, id, to); err != nil {
			return nil, err
		}
		if _, err := tx.Exec(`DELETE FROM req_tags WHERE req_id = ? AND tag = ?`, id, from); err != nil {
			return nil, err
		}
		if err := touchReq(tx, id); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return ids, nil
}

// DeleteTag removes a tag from all requirements and returns the affected requirement IDs.
func (s *Store) DeleteTag(tag string) ([]int64, error) {
	ids, err := s.reqIDsWithTag(tag)
	if err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return nil, fmt.Errorf("tag %q is not in use", tag)
	}
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`DELETE FROM req_tags WHERE tag = ?`, tag); err != nil {
		return nil, err
	}
	for _, id := range ids {
		if err := touchReq(tx, id); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return ids, nil
}

func (s *Store) reqIDsWithTag(tag string) ([]int64, error) {
	rows, err := s.db.Query(`SELECT req_id FROM req_tags WHERE tag = ? ORDER BY req_id`, tag)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// requireReq checks that the requirement exists. The foreign key only fires on insert into req_tags;
// checking first yields "requirement not found" instead of FOREIGN KEY constraint failed.
func (s *Store) requireReq(id int64) error {
	var exists int
	err := s.db.QueryRow(`SELECT 1 FROM reqs WHERE id = ?`, id).Scan(&exists)
	if err == sql.ErrNoRows {
		return ErrNotFound
	}
	return err
}

// purgeTags deletes a requirement's tag rows when it is purged (used by PurgeReq).
func purgeTags(tx *sql.Tx, id int64) error {
	_, err := tx.Exec(`DELETE FROM req_tags WHERE req_id = ?`, id)
	return err
}
