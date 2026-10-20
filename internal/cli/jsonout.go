package cli

import (
	"encoding/json"
	"os"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
)

// reqJSON is the requirement representation consumed by agents and scripts.
// It has more fields than the human view: agents need context (origin_cwd, note), not formatting.
type reqJSON struct {
	ID        int64    `json:"id"`
	Title     string   `json:"title"`
	Priority  int      `json:"priority"`
	State     string   `json:"state"`
	Project   string   `json:"project,omitempty"`
	Tags      []string `json:"tags,omitempty"`
	Links     []string `json:"links,omitempty"`
	Path      string   `json:"path"`
	Note      string   `json:"note,omitempty"`
	OriginCwd string   `json:"origin_cwd,omitempty"`
	CreatedAt string   `json:"created_at"`
	UpdatedAt string   `json:"updated_at"`
}

func toReqJSON(r *model.Req) reqJSON {
	j := reqJSON{
		ID: r.ID, Title: r.Title, Priority: r.Priority, State: string(r.State),
		Project: r.Project, Tags: r.Tags, Links: r.Links, Path: r.BodyPath,
		Note: r.OriginNote, OriginCwd: r.OriginCwd,
		CreatedAt: r.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt: r.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
	return j
}

// tagJSON lets an agent learn the available tags from a single ls --json call.
type tagJSON struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

type projectJSON struct {
	Name      string `json:"name"`
	RepoPath  string `json:"repo_path"`
	OpenCount int    `json:"open_count"`
	Color     string `json:"color,omitempty"`
	// RepoURL is the effective repository web URL: the configured value, else inferred from the git remote
	RepoURL         string `json:"repo_url,omitempty"`
	RepoURLInferred bool   `json:"repo_url_inferred,omitempty"`
}

func toProjectJSON(p *model.Project, open int) projectJSON {
	url, inferred := store.ProjectRepoURL(p)
	return projectJSON{Name: p.Name, RepoPath: p.RepoPath, OpenCount: open,
		Color: p.Color, RepoURL: url, RepoURLInferred: inferred}
}

// lsJSON is the output of jot ls --json. It includes detected_project because
// the current repository is the strongest signal when an agent triages the INBOX.
type lsJSON struct {
	Reqs            []reqJSON     `json:"reqs"`
	Projects        []projectJSON `json:"projects,omitempty"`
	Tags            []tagJSON     `json:"tags,omitempty"`
	DetectedProject string        `json:"detected_project,omitempty"`
	Cwd             string        `json:"cwd,omitempty"`
}

func writeJSON(v any) error {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(v)
}

func projectsJSON(s *store.Store) ([]projectJSON, error) {
	ps, err := s.ListProjects()
	if err != nil {
		return nil, err
	}
	out := make([]projectJSON, 0, len(ps))
	for _, p := range ps {
		j, err := projectJSONFor(s, p)
		if err != nil {
			return nil, err
		}
		out = append(out, j)
	}
	return out, nil
}

func projectJSONFor(s *store.Store, p *model.Project) (projectJSON, error) {
	var n int
	if err := s.DB().QueryRow(`SELECT COUNT(*) FROM reqs WHERE project_id = ? AND state NOT IN ('done','archived')`, p.ID).Scan(&n); err != nil {
		return projectJSON{}, err
	}
	return toProjectJSON(p, n), nil
}
