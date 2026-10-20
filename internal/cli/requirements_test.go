package cli

import (
	"encoding/json"
	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func executeCaptured(t *testing.T, args ...string) (string, error) {
	t.Helper()
	output, err := os.CreateTemp(t.TempDir(), "output")
	if err != nil {
		t.Fatal(err)
	}
	previous := os.Stdout
	os.Stdout = output
	defer func() { os.Stdout = previous; output.Close() }()
	cmd := NewRootCmd()
	cmd.SetArgs(args)
	cmd.SetOut(output)
	cmd.SetErr(output)
	err = cmd.Execute()
	data, readErr := os.ReadFile(output.Name())
	if readErr != nil {
		t.Fatal(readErr)
	}
	return string(data), err
}

func TestPersonalRequirementWorkflowAndJSON(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	if _, err := executeCaptured(t, "init"); err != nil {
		t.Fatal(err)
	}
	output, err := executeCaptured(t, "add", "Personal task", "--unfiled", "--note", "Keep these notes", "--json")
	if err != nil {
		t.Fatal(err)
	}
	var added reqJSON
	if err := json.Unmarshal([]byte(output), &added); err != nil {
		t.Fatal(err)
	}
	if added.ID == 0 || added.CreatedAt == "" || added.UpdatedAt == "" || added.Project != "" {
		t.Fatalf("incomplete requirement: %s", output)
	}
	id := strconv.FormatInt(added.ID, 10)
	for _, args := range [][]string{
		{"mv", id, "in_progress"}, {"mv", id, "on_hold"},
		{"mv", id, "done"}, {"rm", id}, {"mv", id, "inbox"},
	} {
		if _, err := executeCaptured(t, args...); err != nil {
			t.Fatalf("%v: %v", args, err)
		}
	}
	output, err = executeCaptured(t, "show", id, "--json")
	if err != nil || !strings.Contains(output, "Keep these notes") {
		t.Fatalf("lost body: %s %v", output, err)
	}
	for _, key := range []string{"\"agent\"", "\"agent_session\"", "\"missing\""} {
		if strings.Contains(output, key) {
			t.Fatalf("obsolete field %s exposed", key)
		}
	}
}

func TestTriageKeepsProjectAndUnassignPreservesBody(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	s, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	a, err := s.AddProject("A", t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	b, err := s.AddProject("B", t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	r, err := s.CreateReq("Project task", "Keep me", b.RepoPath, &a.ID)
	if err != nil {
		t.Fatal(err)
	}
	t.Chdir(b.RepoPath)
	id := strconv.FormatInt(r.ID, 10)
	if _, err := executeCaptured(t, "triage", id, "--json"); err != nil {
		t.Fatal(err)
	}
	got, err := s.GetReq(r.ID)
	if err != nil || got.Project != "A" || got.State != model.StateInbox {
		t.Fatalf("%#v %v", got, err)
	}
	if _, err := executeCaptured(t, "set", id, "--project", "", "--json"); err != nil {
		t.Fatal(err)
	}
	got, err = s.GetReq(r.ID)
	if err != nil || got.ProjectID != nil {
		t.Fatalf("%#v %v", got, err)
	}
	body, err := s.ReadBody(got)
	if err != nil || !strings.Contains(body, "Keep me") {
		t.Fatalf("%s %v", body, err)
	}
	output, err := executeCaptured(t, "project", "ls", "--json")
	var projects []projectJSON
	if err != nil || json.Unmarshal([]byte(output), &projects) != nil || len(projects) != 2 {
		t.Fatalf("invalid project JSON: %s %v", output, err)
	}
}

func TestShowReportsMissingBodyAndRemovedCommandsReject(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	s, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	r, err := s.CreateReq("Missing", "", "", nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(s.ReqsDir(), r.BodyPath)); err != nil {
		t.Fatal(err)
	}
	if _, err := executeCaptured(t, "show", strconv.FormatInt(r.ID, 10), "--json"); err == nil {
		t.Fatal("missing body was reported as successful read")
	}
	for _, command := range []string{"sessions", "resume", "link", "unlink", "runs", "hook"} {
		if _, err := executeCaptured(t, command); err == nil {
			t.Fatalf("%s still callable", command)
		}
	}
}
