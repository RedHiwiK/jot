package store

import (
	"github.com/RedHiwiK/jot/internal/model"
	"os"
	"strings"
	"testing"
)

func TestRemoveProjectPreservesAllRequirements(t *testing.T) {
	s := testStore(t)
	p, err := s.AddProject("Example", t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	for _, st := range model.AllStates {
		r, e := s.CreateReq(string(st), "Keep this body", "", &p.ID)
		if e != nil {
			t.Fatal(e)
		}
		if e = s.SetState(r, st, "test"); e != nil {
			t.Fatal(e)
		}
	}
	if err = s.RemoveProject(p.Name); err != nil {
		t.Fatal(err)
	}
	for i, st := range model.AllStates {
		r, e := s.GetReq(int64(i + 1))
		if e != nil {
			t.Fatal(e)
		}
		if r.ProjectID != nil || r.Project != "" || r.State != st {
			t.Fatalf("unexpected requirement %+v", r)
		}
		body, e := s.ReadBody(r)
		if e != nil || !strings.Contains(body, "Keep this body") || !strings.Contains(body, "project: \"\"") {
			t.Fatalf("body not preserved: %s %v", body, e)
		}
	}
	if err = s.RemoveProject(p.Name); err != ErrProjectNotFound {
		t.Fatalf("missing project: %v", err)
	}
}
func TestRemoveProjectMissingBodyKeepsAssociation(t *testing.T) {
	s := testStore(t)
	p, _ := s.AddProject("Example", t.TempDir())
	r, _ := s.CreateReq("Keep", "Body", "", &p.ID)
	if err := os.Remove(s.AbsBodyPath(r)); err != nil {
		t.Fatal(err)
	}
	if err := s.RemoveProject(p.Name); err == nil {
		t.Fatal("expected error")
	}
	got, err := s.GetReq(r.ID)
	if err != nil || got.ProjectID == nil {
		t.Fatal("association lost")
	}
	if _, err = s.GetProjectByName(p.Name); err != nil {
		t.Fatal(err)
	}
}
