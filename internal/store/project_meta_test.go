package store

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSetProjectRepoURL(t *testing.T) {
	s := testStore(t)
	if _, err := s.AddProject("Example", t.TempDir()); err != nil {
		t.Fatal(err)
	}
	p, err := s.SetProjectRepoURL("Example", "https://github.com/owner/repo/")
	if err != nil || p.RepoURL != "https://github.com/owner/repo" {
		t.Fatalf("unexpected project %+v %v", p, err)
	}
	if _, err = s.SetProjectRepoURL("Example", "github.com/owner/repo"); err == nil {
		t.Fatal("expected URL without scheme to fail")
	}
	if _, err = s.SetProjectRepoURL("Example", ""); err != nil {
		t.Fatal(err)
	}
	if got, _ := s.GetProjectByName("Example"); got.RepoURL != "" {
		t.Fatalf("not cleared: %+v", got)
	}
}

func TestSetProjectColor(t *testing.T) {
	s := testStore(t)
	if _, err := s.AddProject("Example", t.TempDir()); err != nil {
		t.Fatal(err)
	}
	if p, err := s.SetProjectColor("Example", "Blue"); err != nil || p.Color != "blue" {
		t.Fatalf("unexpected %+v %v", p, err)
	}
	if _, err := s.SetProjectColor("Example", "chartreuse"); err == nil {
		t.Fatal("expected unknown color to fail")
	}
	if _, err := s.SetProjectColor("Example", ""); err != nil {
		t.Fatal(err)
	}
	if got, _ := s.GetProjectByName("Example"); got.Color != "" {
		t.Fatalf("not cleared: %+v", got)
	}
}

func TestRenameProjectRejectsInvalidNames(t *testing.T) {
	s := testStore(t)
	if _, err := s.AddProject("Example", t.TempDir()); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"", "  ", "a/b", "..", "_inbox"} {
		if err := s.RenameProject("Example", name); err == nil {
			t.Fatalf("expected %q to be rejected", name)
		}
	}
	if err := s.RenameProject("Example", " Short "); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetProjectByName("Short"); err != nil {
		t.Fatal(err)
	}
}

func TestProjectRepoURL(t *testing.T) {
	cases := map[string]string{
		"git@github.com:owner/repo.git":                 "https://github.com/owner/repo",
		"https://github.com/owner/repo.git":             "https://github.com/owner/repo",
		"https://user:token@github.com/owner/repo":      "https://github.com/owner/repo",
		"ssh://git@gitlab.example.com:2222/group/sub/r": "https://gitlab.example.com/group/sub/r",
		"/local/path/repo":                              "",
	}
	for remote, want := range cases {
		if got := remoteToWebURL(remote); got != want {
			t.Errorf("remoteToWebURL(%q) = %q, want %q", remote, got, want)
		}
	}

	repo := t.TempDir()
	os.MkdirAll(filepath.Join(repo, ".git"), 0o755)
	config := "[core]\n\tbare = false\n[remote \"upstream\"]\n\turl = git@github.com:other/repo.git\n" +
		"[remote \"origin\"]\n\turl = git@github.com:owner/repo.git\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n"
	os.WriteFile(filepath.Join(repo, ".git", "config"), []byte(config), 0o644)

	s := testStore(t)
	p, _ := s.AddProject("Example", repo)
	if url, inferred := ProjectRepoURL(p); url != "https://github.com/owner/repo" || !inferred {
		t.Fatalf("inferred = %q %v", url, inferred)
	}
	override := "https://gitlab.example.com/team/repo"
	p, _ = s.SetProjectRepoURL("Example", override)
	if url, inferred := ProjectRepoURL(p); url != override || inferred {
		t.Fatalf("override = %q %v", url, inferred)
	}
}
