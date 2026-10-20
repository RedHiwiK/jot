package store

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
)

// ProjectRepoURL returns the project's repository web URL: the configured value, else inferred from the origin remote.
// inferred is true when the URL came from git config rather than being set explicitly.
func ProjectRepoURL(p *model.Project) (url string, inferred bool) {
	if p.RepoURL != "" {
		return p.RepoURL, false
	}
	if u := inferRepoURL(p.RepoPath); u != "" {
		return u, true
	}
	return "", false
}

// inferRepoURL reads .git/config directly instead of running git: ls --json does this for every project
// on every refresh, and spawning a process is too expensive. Returns empty if unreadable (not a git dir, worktree, etc.).
func inferRepoURL(repoPath string) string {
	f, err := os.Open(filepath.Join(repoPath, ".git", "config"))
	if err != nil {
		return ""
	}
	defer f.Close()
	inOrigin := false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if strings.HasPrefix(line, "[") {
			inOrigin = line == `[remote "origin"]`
			continue
		}
		if !inOrigin {
			continue
		}
		if key, value, ok := strings.Cut(line, "="); ok && strings.TrimSpace(key) == "url" {
			return remoteToWebURL(strings.TrimSpace(value))
		}
	}
	return ""
}

// remoteToWebURL converts a git remote URL into an https URL a browser can open.
//
//	git@github.com:owner/repo.git          → https://github.com/owner/repo
//	ssh://git@gitlab.example.com:2222/g/r  → https://gitlab.example.com/g/r
//	https://user@github.com/owner/repo.git → https://github.com/owner/repo
func remoteToWebURL(remote string) string {
	var host, path string
	switch {
	case strings.HasPrefix(remote, "https://"), strings.HasPrefix(remote, "http://"),
		strings.HasPrefix(remote, "ssh://"), strings.HasPrefix(remote, "git://"):
		_, rest, _ := strings.Cut(remote, "://")
		host, path, _ = strings.Cut(rest, "/")
		// The SSH port is unrelated to the web port, so drop it
		if i := strings.LastIndex(host, "@"); i >= 0 {
			host = host[i+1:]
		}
		if h, _, ok := strings.Cut(host, ":"); ok {
			host = h
		}
	case strings.Contains(remote, ":") && !strings.Contains(remote, "://"):
		// scp style: git@host:owner/repo.git
		host, path, _ = strings.Cut(remote, ":")
		if i := strings.LastIndex(host, "@"); i >= 0 {
			host = host[i+1:]
		}
	default:
		return ""
	}
	path = strings.TrimSuffix(strings.Trim(path, "/"), ".git")
	if host == "" || path == "" {
		return ""
	}
	return "https://" + host + "/" + path
}
