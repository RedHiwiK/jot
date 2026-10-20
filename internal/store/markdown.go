package store

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/RedHiwiK/jot/internal/model"
)

// The markdown frontmatter is a redundant readable copy; SQLite is authoritative.
// Opening the file directly still shows full context, including for agents reading it.
// On mismatch SQLite wins (jot sync repairs it).

// renderFrontmatter is the only place frontmatter is generated. All three write paths (create/sync/full
// overwrite) go through it so a new field can't be missed in one of them.
func renderFrontmatter(r *model.Req) string {
	var b strings.Builder
	fmt.Fprintf(&b, "---\nid: %d\ntitle: %q\nstate: %s\nproject: %q\n", r.ID, r.Title, r.State, r.Project)
	// Omit the line entirely when there are no tags, so untagged files stay unchanged
	if len(r.Tags) > 0 {
		fmt.Fprintf(&b, "tags: [%s]\n", strings.Join(r.Tags, ", "))
	}
	// Links contain colons, so use a block list rather than an inline array to avoid YAML ambiguity
	if len(r.Links) > 0 {
		b.WriteString("links:\n")
		for _, u := range r.Links {
			fmt.Fprintf(&b, "  - %s\n", u)
		}
	}
	fmt.Fprintf(&b, "created: %s\n---\n", r.CreatedAt.Format(time.RFC3339))
	return b.String()
}

const bodyTemplate = `## Requirement

%s

## Acceptance criteria

- [ ] 

## Notes

%s
`

// WriteBody creates a requirement's markdown file.
func (s *Store) WriteBody(r *model.Req, desc string) error {
	abs := filepath.Join(s.ReqsDir(), r.BodyPath)
	if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
		return fmt.Errorf("create directory: %w", err)
	}
	if desc == "" {
		desc = r.Title
	}
	content := renderFrontmatter(r) + "\n" + fmt.Sprintf(bodyTemplate, desc, r.OriginNote)
	return atomicWrite(abs, []byte(content))
}

// ReadBody reads the full markdown body.
func (s *Store) ReadBody(r *model.Req) (string, error) {
	b, err := os.ReadFile(filepath.Join(s.ReqsDir(), r.BodyPath))
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// AbsBodyPath returns the markdown file's absolute path.
func (s *Store) AbsBodyPath(r *model.Req) string {
	return filepath.Join(s.ReqsDir(), r.BodyPath)
}

// MoveBody moves the markdown to a new path (used when the project changes: _inbox/ → myapp/).
func (s *Store) MoveBody(r *model.Req, newPath string) error {
	if r.BodyPath == newPath {
		return nil
	}
	oldAbs := filepath.Join(s.ReqsDir(), r.BodyPath)
	newAbs := filepath.Join(s.ReqsDir(), newPath)
	if err := os.MkdirAll(filepath.Dir(newAbs), 0o755); err != nil {
		return err
	}
	if _, err := os.Stat(oldAbs); os.IsNotExist(err) {
		// The source file is gone (deleted by hand?); recreate it at the new path instead of failing
		r.BodyPath = newPath
		return s.WriteBody(r, "")
	}
	data, err := os.ReadFile(oldAbs)
	if err != nil {
		return err
	}
	if err := atomicWrite(newAbs, data); err != nil {
		return fmt.Errorf("move file: %w", err)
	}
	r.BodyPath = newPath
	return nil
}

// SyncFrontmatter refreshes the markdown frontmatter from SQLite.
func (s *Store) SyncFrontmatter(r *model.Req) error {
	abs := s.AbsBodyPath(r)
	data, err := os.ReadFile(abs)
	if err != nil {
		return err
	}
	body := string(data)
	// Only a leading, closed block is metadata; horizontal rules in prose stay intact.
	if strings.HasPrefix(body, "---\n") {
		if end := strings.Index(body[4:], "\n---\n"); end >= 0 {
			body = body[4+end+5:]
		}
	}

	return atomicWrite(abs, []byte(renderFrontmatter(r)+body))
}

// SetBody writes metadata and body together, without an intermediate truncated file.
func (s *Store) SetBody(r *model.Req, body string) error {
	if err := atomicWrite(s.AbsBodyPath(r), []byte(renderFrontmatter(r)+"\n"+body)); err != nil {
		return err
	}
	_, err := s.db.Exec(`UPDATE reqs SET updated_at = ? WHERE id = ?`, time.Now().Unix(), r.ID)
	return err
}
