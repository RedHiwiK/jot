package store

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testStore(t *testing.T) *Store {
	t.Helper()
	t.Setenv("JOT_HOME", t.TempDir())
	s, err := Open()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func TestCreateFailureDoesNotLeaveRequirement(t *testing.T) {
	s := testStore(t)
	if err := os.WriteFile(filepath.Join(s.ReqsDir(), "_inbox"), []byte("blocked directory"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := s.CreateReq("Test", "", "", nil); err == nil {
		t.Fatal("expected file failure")
	}
	for _, table := range []string{"reqs", "state_log"} {
		var count int
		if err := s.db.QueryRow("SELECT COUNT(*) FROM " + table).Scan(&count); err != nil {
			t.Fatal(err)
		}
		if count != 0 {
			t.Fatalf("%s has %d orphan records", table, count)
		}
	}
}

func TestMoveFailureKeepsOriginalBody(t *testing.T) {
	s := testStore(t)
	r, err := s.CreateReq("Keep my notes", "", "", nil)
	if err != nil {
		t.Fatal(err)
	}
	old := s.AbsBodyPath(r)
	if err := s.SetBody(r, "original notes\n"); err != nil {
		t.Fatal(err)
	}
	if err := s.MoveBody(r, "project/copied.md"); err != nil {
		t.Fatal(err)
	}
	if err := s.UpdateReqFields(r.ID, map[string]any{"body_path": r.BodyPath, "project_id": -1}); err == nil {
		t.Fatal("expected foreign key failure")
	}
	got, err := s.GetReq(r.ID)
	if err != nil {
		t.Fatal(err)
	}
	if s.AbsBodyPath(got) != old {
		t.Fatal("database reference changed after failure")
	}
	data, err := s.ReadBody(got)
	if err != nil || !strings.Contains(data, "original notes") {
		t.Fatalf("lost original: %q %v", data, err)
	}
	if err := s.UpdateReqFields(r.ID, map[string]any{"body_path": r.BodyPath}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(old); !os.IsNotExist(err) {
		t.Fatal("old copy should be removed after successful update")
	}
}

func TestBodyPreservesProseAndQuotesMetadata(t *testing.T) {
	s := testStore(t)
	r, err := s.CreateReq("Title: \"quoted\"", "", "", nil)
	if err != nil {
		t.Fatal(err)
	}
	const prose = "Introduction\n\n---\n\nKeep this section\n---\nEnding\n"
	if err := os.WriteFile(s.AbsBodyPath(r), []byte(prose), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(s.AbsBodyPath(r), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := s.SyncFrontmatter(r); err != nil {
		t.Fatal(err)
	}
	got, err := s.ReadBody(r)
	if err != nil || !strings.HasSuffix(got, prose) {
		t.Fatalf("prose changed: %q %v", got, err)
	}
	if err := s.SetBody(r, prose); err != nil {
		t.Fatal(err)
	}
	got, _ = s.ReadBody(r)
	if !strings.HasSuffix(got, prose) || !strings.Contains(got, `title: "Title: \"quoted\""`) {
		t.Fatalf("unexpected body: %q", got)
	}
	info, _ := os.Stat(s.AbsBodyPath(r))
	if info.Mode().Perm() != 0o600 {
		t.Fatal("file permissions changed")
	}
}
