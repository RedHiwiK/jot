package store

import (
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/RedHiwiK/jot/internal/model"
)

var ErrProjectNotFound = errors.New("project not found")

func scanProject(sc interface{ Scan(...any) error }) (*model.Project, error) {
	var p model.Project
	var created int64
	if err := sc.Scan(&p.ID, &p.Name, &p.RepoPath, &p.Color, &p.RepoURL, &created); err != nil {
		return nil, err
	}
	p.CreatedAt = time.Unix(created, 0)
	return &p, nil
}

const projCols = `id, name, repo_path, COALESCE(color, ''), COALESCE(repo_url, ''), created_at`

func (s *Store) AddProject(name, repoPath string) (*model.Project, error) {
	abs, err := filepath.Abs(expandHome(repoPath))
	if err != nil {
		return nil, err
	}
	now := time.Now()

	res, err := s.db.Exec(`INSERT INTO projects (name, repo_path, created_at)
		VALUES (?, ?, ?)`, name, abs, now.Unix())
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			return nil, fmt.Errorf("project %q already exists", name)
		}
		return nil, err
	}
	id, _ := res.LastInsertId()
	return &model.Project{
		ID: id, Name: name, RepoPath: abs, CreatedAt: now,
	}, nil
}

func (s *Store) GetProjectByName(name string) (*model.Project, error) {
	row := s.db.QueryRow(`SELECT `+projCols+` FROM projects WHERE name = ?`, name)
	p, err := scanProject(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrProjectNotFound
	}
	return p, err
}

func (s *Store) ListProjects() ([]*model.Project, error) {
	rows, err := s.db.Query(`SELECT ` + projCols + ` FROM projects ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*model.Project
	for rows.Next() {
		p, err := scanProject(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// RemoveProject detaches requirements without changing their status or body path.
func (s *Store) RemoveProject(name string) (err error) {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var id int64
	if err = tx.QueryRow("SELECT id FROM projects WHERE name = ?", name).Scan(&id); errors.Is(err, sql.ErrNoRows) {
		return ErrProjectNotFound
	} else if err != nil {
		return err
	}
	rows, err := tx.Query("SELECT "+reqCols+" FROM reqs r LEFT JOIN projects p ON p.id = r.project_id WHERE r.project_id = ?", id)
	if err != nil {
		return err
	}
	var reqs []*model.Req
	for rows.Next() {
		r, e := scanReq(rows)
		if e != nil {
			rows.Close()
			return e
		}
		reqs = append(reqs, r)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	originals := map[string][]byte{}
	for _, r := range reqs {
		path := s.AbsBodyPath(r)
		data, e := os.ReadFile(path)
		if e != nil {
			return e
		}
		originals[path] = data
	}
	changed := []string{}
	defer func() {
		if err != nil {
			for _, path := range changed {
				if e := atomicWrite(path, originals[path]); e != nil {
					err = errors.Join(err, fmt.Errorf("restore %s: %w", path, e))
				}
			}
		}
	}()
	if _, err = tx.Exec("UPDATE reqs SET project_id = NULL WHERE project_id = ?", id); err != nil {
		return err
	}
	if _, err = tx.Exec("DELETE FROM projects WHERE id = ?", id); err != nil {
		return err
	}
	for _, r := range reqs {
		r.ProjectID = nil
		r.Project = ""
		if err = s.SyncFrontmatter(r); err != nil {
			return err
		}
		changed = append(changed, s.AbsBodyPath(r))
	}
	return tx.Commit()
}

// DetectProject infers which registered project the working directory belongs to.
//
// It uses the longest matching prefix, so nested repos resolve to the innermost one.
// This lets captures avoid asking which project something belongs to.
func (s *Store) DetectProject(cwd string) (*model.Project, bool) {
	projects, err := s.ListProjects()
	if err != nil || len(projects) == 0 {
		return nil, false
	}
	abs, err := filepath.Abs(cwd)
	if err != nil {
		return nil, false
	}
	sort.Slice(projects, func(i, j int) bool {
		return len(projects[i].RepoPath) > len(projects[j].RepoPath)
	})
	for _, p := range projects {
		if abs == p.RepoPath || strings.HasPrefix(abs, p.RepoPath+string(filepath.Separator)) {
			return p, true
		}
	}
	return nil, false
}

func expandHome(p string) string {
	if strings.HasPrefix(p, "~/") {
		if home, err := homeDir(); err == nil {
			return filepath.Join(home, p[2:])
		}
	}
	return p
}

// RenameProject changes a project's display name and moves its markdown directory.
// Auto-discovery uses the repo directory name (myapp-monorepo); a shorter name (myapp) may be preferred.
func (s *Store) RenameProject(old, new string) error {
	new = strings.TrimSpace(new)
	// The name is also the directory under reqs/, so it can't be empty or contain path separators
	if new == "" || strings.ContainsAny(new, `/\`) || new == "." || new == ".." || new == model.InboxDir {
		return fmt.Errorf("invalid project name %q", new)
	}
	p, err := s.GetProjectByName(old)
	if err != nil {
		return err
	}
	if _, err := s.GetProjectByName(new); err == nil {
		return fmt.Errorf("project name %q is already taken", new)
	}

	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`UPDATE projects SET name = ? WHERE id = ?`, new, p.ID); err != nil {
		return err
	}
	// body_path includes the project directory name, so update it too
	if _, err := tx.Exec(
		`UPDATE reqs SET body_path = ? || SUBSTR(body_path, ?) WHERE project_id = ?`,
		new+"/", len(old)+2, p.ID); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}

	// Move the directory on disk as well
	oldDir := filepath.Join(s.ReqsDir(), old)
	newDir := filepath.Join(s.ReqsDir(), new)
	if _, err := os.Stat(oldDir); err == nil {
		if err := os.Rename(oldDir, newDir); err != nil {
			return fmt.Errorf("move directory (the database was already updated): %w", err)
		}
	}
	return nil
}

func (s *Store) GetProjectByID(id int64) (*model.Project, error) {
	row := s.db.QueryRow(`SELECT `+projCols+` FROM projects WHERE id = ?`, id)
	p, err := scanProject(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrProjectNotFound
	}
	return p, err
}

// SetProjectRepoURL sets the project's repo web URL. An empty string clears it, falling back to the git remote.
func (s *Store) SetProjectRepoURL(name, repoURL string) (*model.Project, error) {
	p, err := s.GetProjectByName(name)
	if err != nil {
		return nil, err
	}
	u := strings.TrimRight(strings.TrimSpace(repoURL), "/")
	if u != "" && !strings.HasPrefix(u, "https://") && !strings.HasPrefix(u, "http://") {
		return nil, fmt.Errorf("repository URL must start with http:// or https://: %q", repoURL)
	}
	if _, err := s.db.Exec(`UPDATE projects SET repo_url = NULLIF(?, '') WHERE id = ?`, u, p.ID); err != nil {
		return nil, err
	}
	p.RepoURL = u
	return p, nil
}

// SetProjectColor sets the project color (its icon in the GUI sidebar). An empty string clears it.
func (s *Store) SetProjectColor(name, color string) (*model.Project, error) {
	p, err := s.GetProjectByName(name)
	if err != nil {
		return nil, err
	}
	c, err := model.ParseProjectColor(color)
	if err != nil {
		return nil, err
	}
	if _, err := s.db.Exec(`UPDATE projects SET color = NULLIF(?, '') WHERE id = ?`, c, p.ID); err != nil {
		return nil, err
	}
	p.Color = c
	return p, nil
}
