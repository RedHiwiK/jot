package store

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
)

// findRepoRoot walks up from dir to the git repository root.
//
// Worktrees need special handling: --show-toplevel returns the worktree path,
// not the main repository. --git-common-dir points at the main repo's .git; stripping that suffix gives the real root.
func findRepoRoot(dir string) (string, bool) {
	run := func(args ...string) (string, bool) {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		out, err := cmd.Output()
		if err != nil {
			return "", false
		}
		return strings.TrimSpace(string(out)), true
	}

	common, ok := run("rev-parse", "--git-common-dir")
	if !ok {
		return "", false
	}
	// common may be relative (.git) or absolute (/path/to/repo/.git)
	if !filepath.IsAbs(common) {
		top, ok := run("rev-parse", "--show-toplevel")
		if !ok {
			return "", false
		}
		common = filepath.Join(top, common)
	}
	root := filepath.Dir(filepath.Clean(common))
	abs, err := filepath.Abs(root)
	if err != nil {
		return "", false
	}
	return abs, true
}

// ResolveProject determines the project from the working directory, registering it if needed.
//
// This is the auto-discovery entry point: the registry is a cache, not a prerequisite.
// Requiring project add before captures are filed correctly would add friction to capturing.
//
// It runs only on capture, never scans the disk, and registers only the repos actually used.
func (s *Store) ResolveProject(cwd string) (*model.Project, bool) {
	// Check registered projects first (the display name may have been changed)
	if p, ok := s.DetectProject(cwd); ok {
		return p, true
	}

	root, ok := findRepoRoot(cwd)
	if !ok {
		return nil, false // not in a git repo → _inbox
	}

	// Path is registered but DetectProject missed it (cwd is inside a worktree)
	if p, err := s.getProjectByPath(root); err == nil {
		return p, true
	}

	p, err := s.autoRegister(root)
	if err != nil {
		return nil, false
	}
	return p, true
}

func (s *Store) getProjectByPath(repoPath string) (*model.Project, error) {
	row := s.db.QueryRow(`SELECT `+projCols+` FROM projects WHERE repo_path = ?`, repoPath)
	return scanProject(row)
}

// autoRegister registers a newly discovered repository.
// The project name is the directory name; on collision the parent directory name is appended (~/work/api vs ~/personal/api).
func (s *Store) autoRegister(root string) (*model.Project, error) {
	name := filepath.Base(root)

	if _, err := s.GetProjectByName(name); err == nil {
		parent := filepath.Base(filepath.Dir(root))
		alt := name + "-" + parent
		if _, err := s.GetProjectByName(alt); err == nil {
			// Still colliding: fall back to a numeric suffix
			for i := 2; ; i++ {
				alt = fmt.Sprintf("%s-%d", name, i)
				if _, err := s.GetProjectByName(alt); err != nil {
					break
				}
			}
		}
		name = alt
	}

	return s.AddProject(name, root)
}
