package store

import (
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/RedHiwiK/jot/internal/model"
)

var ErrNotFound = errors.New("requirement not found")

const reqCols = `r.id, r.title, r.body_path, r.state, r.project_id, r.priority,
    r.origin_cwd, r.origin_note, r.created_at, r.updated_at,
    r.started_at, r.finished_at, r.done_at, COALESCE(p.name, '')`

func scanReq(sc interface{ Scan(...any) error }) (*model.Req, error) {
	var r model.Req
	var projectID sql.NullInt64
	var cwd, note sql.NullString
	var createdAt, updatedAt int64
	var startedAt, finishedAt, doneAt sql.NullInt64
	err := sc.Scan(&r.ID, &r.Title, &r.BodyPath, &r.State, &projectID, &r.Priority,
		&cwd, &note, &createdAt, &updatedAt, &startedAt, &finishedAt, &doneAt, &r.Project)
	if err != nil {
		return nil, err
	}
	if projectID.Valid {
		r.ProjectID = &projectID.Int64
	}
	r.OriginCwd, r.OriginNote = cwd.String, note.String
	r.CreatedAt, r.UpdatedAt = time.Unix(createdAt, 0), time.Unix(updatedAt, 0)
	r.StartedAt, r.FinishedAt, r.DoneAt = nullTime(startedAt), nullTime(finishedAt), nullTime(doneAt)
	return &r, nil
}

// touchReq bumps updated_at. Tag changes count as requirement changes, or list ordering wouldn't reflect them.
func touchReq(tx *sql.Tx, id int64) error {
	_, err := tx.Exec(`UPDATE reqs SET updated_at = ? WHERE id = ?`, time.Now().Unix(), id)
	return err
}

func nullTime(n sql.NullInt64) *time.Time {
	if !n.Valid {
		return nil
	}
	t := time.Unix(n.Int64, 0)
	return &t
}

// CreateReq inserts the row to get an ID, builds the file path from that ID, then writes the markdown.
func (s *Store) CreateReq(title, note, cwd string, projectID *int64) (*model.Req, error) {
	now := time.Now()
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	res, err := tx.Exec(`INSERT INTO reqs (title, body_path, state, project_id, origin_cwd, origin_note, created_at, updated_at)
		VALUES (?, '', 'inbox', ?, ?, ?, ?, ?)`,
		title, projectID, cwd, note, now.Unix(), now.Unix())
	if err != nil {
		return nil, fmt.Errorf("insert requirement: %w", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		return nil, err
	}

	// The project name decides the markdown directory; no project means _inbox/
	var projectName string
	if projectID != nil {
		tx.QueryRow(`SELECT name FROM projects WHERE id = ?`, *projectID).Scan(&projectName)
	}
	bodyPath := model.BodyPath(projectName, id, title, now)

	if _, err := tx.Exec(`UPDATE reqs SET body_path = ? WHERE id = ?`, bodyPath, id); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(`INSERT INTO state_log (req_id, from_state, to_state, actor, created_at)
		VALUES (?, NULL, 'inbox', 'cli', ?)`, id, now.Unix()); err != nil {
		return nil, err
	}
	r := &model.Req{
		ID: id, Title: title, BodyPath: bodyPath, State: model.StateInbox,
		ProjectID: projectID, Project: projectName,
		OriginCwd: cwd, OriginNote: note,
		CreatedAt: now, UpdatedAt: now,
	}
	if err := s.WriteBody(r, ""); err != nil {
		return nil, fmt.Errorf("write markdown: %w", err)
	}
	if err := tx.Commit(); err != nil {
		os.Remove(s.AbsBodyPath(r))
		return nil, err
	}
	return r, nil
}

func (s *Store) GetReq(id int64) (*model.Req, error) {
	row := s.db.QueryRow(`SELECT `+reqCols+` FROM reqs r LEFT JOIN projects p ON r.project_id = p.id WHERE r.id = ?`, id)
	r, err := scanReq(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if r.Tags, err = s.ReqTags(r.ID); err != nil {
		return nil, err
	}
	if r.Links, err = s.ReqLinks(r.ID); err != nil {
		return nil, err
	}
	return r, nil
}

type ListFilter struct {
	States      []model.State
	Project     string
	IncludeDone bool

	// Tags requires all to match (AND); TagsAny requires any one (OR).
	// Untagged keeps only requirements with no tags.
	Tags     []string
	TagsAny  []string
	Untagged bool
}

func (s *Store) ListReqs(f ListFilter) ([]*model.Req, error) {
	q := `SELECT ` + reqCols + ` FROM reqs r LEFT JOIN projects p ON r.project_id = p.id WHERE 1=1`
	var args []any

	if len(f.States) > 0 {
		ph := make([]string, len(f.States))
		for i, st := range f.States {
			ph[i] = "?"
			args = append(args, string(st))
		}
		q += ` AND r.state IN (` + strings.Join(ph, ",") + `)`
	} else if !f.IncludeDone {
		q += ` AND r.state NOT IN ('done','archived')`
	}
	if f.Project != "" {
		q += ` AND p.name = ?`
		args = append(args, f.Project)
	}
	// AND semantics: one EXISTS per tag, all must hold
	for _, t := range f.Tags {
		q += ` AND EXISTS (SELECT 1 FROM req_tags rt WHERE rt.req_id = r.id AND rt.tag = ?)`
		args = append(args, t)
	}
	if len(f.TagsAny) > 0 {
		ph := make([]string, len(f.TagsAny))
		for i, t := range f.TagsAny {
			ph[i] = "?"
			args = append(args, t)
		}
		q += ` AND EXISTS (SELECT 1 FROM req_tags rt WHERE rt.req_id = r.id AND rt.tag IN (` + strings.Join(ph, ",") + `))`
	}
	if f.Untagged {
		q += ` AND NOT EXISTS (SELECT 1 FROM req_tags rt WHERE rt.req_id = r.id)`
	}
	q += ` ORDER BY r.priority DESC, r.id DESC`

	rows, err := s.db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []*model.Req
	for rows.Next() {
		r, err := scanReq(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := s.loadTags(out); err != nil {
		return nil, err
	}
	if err := s.loadLinks(out); err != nil {
		return nil, err
	}
	return out, nil
}

// UpdateReqFields updates arbitrary fields and maintains updated_at.
func (s *Store) UpdateReqFields(id int64, fields map[string]any) error {
	if len(fields) == 0 {
		return nil
	}
	var oldPath string
	if _, moving := fields["body_path"]; moving {
		if err := s.db.QueryRow(`SELECT body_path FROM reqs WHERE id = ?`, id).Scan(&oldPath); err != nil {
			return err
		}
	}
	sets := make([]string, 0, len(fields)+1)
	args := make([]any, 0, len(fields)+2)
	for k, v := range fields {
		sets = append(sets, k+" = ?")
		args = append(args, v)
	}
	sets = append(sets, "updated_at = ?")
	args = append(args, time.Now().Unix(), id)

	_, err := s.db.Exec(`UPDATE reqs SET `+strings.Join(sets, ", ")+` WHERE id = ?`, args...)
	if err == nil && oldPath != "" && fields["body_path"] != oldPath {
		// The old file remains authoritative until the database points to its copy.
		os.Remove(filepath.Join(s.ReqsDir(), oldPath))
	}
	return err
}

// SetState changes the state and logs the transition. actor: human | cli
func (s *Store) SetState(r *model.Req, to model.State, actor string) error {
	now := time.Now()
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	fields := "state = ?, updated_at = ?"
	args := []any{string(to), now.Unix()}

	switch to {
	case model.StateInProgress:
		fields += ", started_at = COALESCE(started_at, ?)"
		args = append(args, now.Unix())
	case model.StateDone:
		fields += ", done_at = ?"
		args = append(args, now.Unix())
	}
	args = append(args, r.ID)

	if _, err := tx.Exec(`UPDATE reqs SET `+fields+` WHERE id = ?`, args...); err != nil {
		return err
	}
	if _, err := tx.Exec(`INSERT INTO state_log (req_id, from_state, to_state, actor, created_at)
		VALUES (?, ?, ?, ?, ?)`, r.ID, string(r.State), string(to), actor, now.Unix()); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	r.State = to
	r.UpdatedAt = now
	return nil
}

// PurgeReq permanently deletes a requirement: the database rows and the markdown file.
//
// Only archived requirements can be purged: archiving is the soft delete and this is the hard delete,
// so one slip can't wipe a requirement that is still active.
//
// Order matters: delete child tables before the main table, or foreign keys block it.
// Delete the file last: if the DB delete succeeds and the file delete fails, at worst an orphan file remains;
// the reverse would leave a zombie row in the list that errors when opened.
func (s *Store) PurgeReq(id int64) error {
	r, err := s.GetReq(id)
	if err != nil {
		return err
	}
	if r.State != model.StateArchived {
		return fmt.Errorf("#%d is not archived; run jot rm %d to archive it before deleting", id, id)
	}

	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := purgeTags(tx, id); err != nil {
		return err
	}
	if err := purgeLinks(tx, id); err != nil {
		return err
	}
	for _, t := range []string{"state_log"} {
		if _, err := tx.Exec("DELETE FROM "+t+" WHERE req_id = ?", id); err != nil {
			return err
		}
	}
	if _, err := tx.Exec("DELETE FROM reqs WHERE id = ?", id); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}

	if r.BodyPath != "" {
		full := filepath.Join(s.ReqsDir(), r.BodyPath)
		if err := os.Remove(full); err != nil && !os.IsNotExist(err) {
			// The DB rows are gone; failing to remove the file is not an error, just report it
			return fmt.Errorf("row deleted, but the file remains: %w", err)
		}
	}
	return nil
}
