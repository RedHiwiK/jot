package cli

import (
	"strconv"
	"strings"
	"testing"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
)

func TestArchiveSynchronizesBodyAndRestorePreservesNotes(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	s, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	r, err := s.CreateReq("Archive regression", "", "", nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.SetBody(r, "Notes that must survive\n"); err != nil {
		t.Fatal(err)
	}
	for _, step := range []struct {
		args  []string
		state model.State
	}{
		{[]string{"rm", strconv.FormatInt(r.ID, 10)}, model.StateArchived},
		{[]string{"mv", strconv.FormatInt(r.ID, 10), "inbox"}, model.StateInbox},
	} {
		cmd := NewRootCmd()
		cmd.SetArgs(step.args)
		if err := cmd.Execute(); err != nil {
			t.Fatal(err)
		}
		current, err := s.GetReq(r.ID)
		if err != nil {
			t.Fatal(err)
		}
		body, err := s.ReadBody(current)
		if err != nil || current.State != step.state || !strings.Contains(body, "state: "+string(step.state)+"\n") || !strings.Contains(body, "Notes that must survive") {
			t.Fatalf("inconsistent requirement: %#v %q %v", current, body, err)
		}
	}
}
