package cli

import (
	"encoding/json"
	"strconv"
	"strings"
	"testing"
)

func addForTagging(t *testing.T, title string) int64 {
	t.Helper()
	out, err := executeCaptured(t, "add", title, "--unfiled", "--json")
	if err != nil {
		t.Fatal(err)
	}
	var r reqJSON
	if err := json.Unmarshal([]byte(out), &r); err != nil {
		t.Fatal(err)
	}
	return r.ID
}

func tagsOf(t *testing.T, id int64) []string {
	t.Helper()
	out, err := executeCaptured(t, "show", itoa(id), "--json")
	if err != nil {
		t.Fatal(err)
	}
	var r reqJSON
	if err := json.Unmarshal([]byte(out), &r); err != nil {
		t.Fatal(err)
	}
	return r.Tags
}

func itoa(id int64) string { return strconv.FormatInt(id, 10) }

func TestTagAddCaptureAndNormalization(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	if _, err := executeCaptured(t, "init"); err != nil {
		t.Fatal(err)
	}
	// Tags given at capture time are normalized for case, # prefix and comma separation
	out, err := executeCaptured(t, "add", "Tagged capture", "--unfiled", "--tag", "#V1.2.0,BUG", "--json")
	if err != nil {
		t.Fatal(err)
	}
	var r reqJSON
	if err := json.Unmarshal([]byte(out), &r); err != nil {
		t.Fatal(err)
	}
	if strings.Join(r.Tags, ",") != "bug,v1.2.0" {
		t.Fatalf("tags = %v, want [bug v1.2.0]", r.Tags)
	}
}

func TestTagIncrementalVersusReplace(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	if _, err := executeCaptured(t, "init"); err != nil {
		t.Fatal(err)
	}
	id := addForTagging(t, "Incremental")

	if _, err := executeCaptured(t, "tag", itoa(id), "v1.2.0"); err != nil {
		t.Fatal(err)
	}
	// tag is incremental: a second call must not wipe the first
	if _, err := executeCaptured(t, "tag", itoa(id), "bug"); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(tagsOf(t, id), ","); got != "bug,v1.2.0" {
		t.Fatalf("after incremental tagging: %s", got)
	}

	// set --tags replaces the whole set
	if _, err := executeCaptured(t, "set", itoa(id), "--tags", "only"); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(tagsOf(t, id), ","); got != "only" {
		t.Fatalf("after replace: %s", got)
	}

	if _, err := executeCaptured(t, "untag", itoa(id), "only"); err != nil {
		t.Fatal(err)
	}
	if got := tagsOf(t, id); len(got) != 0 {
		t.Fatalf("after untag: %v", got)
	}
}

func TestTagBatchReportsPartialFailure(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	if _, err := executeCaptured(t, "init"); err != nil {
		t.Fatal(err)
	}
	id := addForTagging(t, "Real one")

	// A partial failure must exit non-zero, or an agent will treat it as full success
	out, err := executeCaptured(t, "tag", itoa(id), "999", "v1.2.0", "--json")
	if err == nil {
		t.Fatal("expected a nonzero exit for the missing requirement")
	}
	var result struct {
		Reqs   []reqJSON `json:"reqs"`
		Failed []string  `json:"failed"`
	}
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("unparsable output %q: %v", out, err)
	}
	if len(result.Reqs) != 1 || len(result.Failed) != 1 {
		t.Fatalf("got %d ok / %d failed, want 1/1", len(result.Reqs), len(result.Failed))
	}
	// The successful item still gets its tag; a failed item must not roll back the batch
	if got := strings.Join(tagsOf(t, id), ","); got != "v1.2.0" {
		t.Fatalf("successful item lost its tag: %s", got)
	}
}

func TestLsTagFiltersAndTagListing(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	if _, err := executeCaptured(t, "init"); err != nil {
		t.Fatal(err)
	}
	a := addForTagging(t, "A")
	b := addForTagging(t, "B")
	addForTagging(t, "C")
	if _, err := executeCaptured(t, "tag", itoa(a), "v1.2.0", "bug"); err != nil {
		t.Fatal(err)
	}
	if _, err := executeCaptured(t, "tag", itoa(b), "v1.2.0"); err != nil {
		t.Fatal(err)
	}

	list := func(args ...string) lsJSON {
		t.Helper()
		out, err := executeCaptured(t, append([]string{"ls", "--json"}, args...)...)
		if err != nil {
			t.Fatal(err)
		}
		var res lsJSON
		if err := json.Unmarshal([]byte(out), &res); err != nil {
			t.Fatal(err)
		}
		return res
	}

	if got := list("--tag", "v1.2.0", "--tag", "bug"); len(got.Reqs) != 1 || got.Reqs[0].ID != a {
		t.Fatalf("AND filter returned %d results", len(got.Reqs))
	}
	if got := list("--tag-any", "v1.2.0,none"); len(got.Reqs) != 2 {
		t.Fatalf("OR filter returned %d results", len(got.Reqs))
	}
	if got := list("--untagged"); len(got.Reqs) != 1 {
		t.Fatalf("untagged filter returned %d results", len(got.Reqs))
	}
	// ls --json includes the tag summary so an agent needn't call tag ls
	if got := list(); len(got.Tags) != 2 {
		t.Fatalf("ls did not return the tag summary: %+v", got.Tags)
	}
}

func TestTagRenameAndRemove(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	if _, err := executeCaptured(t, "init"); err != nil {
		t.Fatal(err)
	}
	id := addForTagging(t, "Renamed")
	if _, err := executeCaptured(t, "tag", itoa(id), "v1.2.0"); err != nil {
		t.Fatal(err)
	}
	if _, err := executeCaptured(t, "tag", "rename", "v1.2.0", "v1.3.0"); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(tagsOf(t, id), ","); got != "v1.3.0" {
		t.Fatalf("after rename: %s", got)
	}

	if _, err := executeCaptured(t, "tag", "rm", "v1.3.0"); err != nil {
		t.Fatal(err)
	}
	if got := tagsOf(t, id); len(got) != 0 {
		t.Fatalf("after tag rm: %v", got)
	}
	// tag rm only removes the tag; the requirement itself must remain
	if _, err := executeCaptured(t, "show", itoa(id), "--json"); err != nil {
		t.Fatalf("requirement disappeared with its tag: %v", err)
	}
	if _, err := executeCaptured(t, "tag", "rename", "gone", "x"); err == nil {
		t.Fatal("expected an error renaming an unused tag")
	}
}

func TestSetRejectsEmptyChangeButAcceptsTags(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	if _, err := executeCaptured(t, "init"); err != nil {
		t.Fatal(err)
	}
	id := addForTagging(t, "Set")
	if _, err := executeCaptured(t, "set", itoa(id)); err == nil {
		t.Fatal("expected an error when nothing is changed")
	}
	// --tags "" is a valid request to clear, not "nothing changed"
	if _, err := executeCaptured(t, "set", itoa(id), "--tags", ""); err != nil {
		t.Fatalf("clearing tags failed: %v", err)
	}
}

func TestAllDigitTagRequiresExplicitFlag(t *testing.T) {
	t.Setenv("JOT_HOME", t.TempDir())
	if _, err := executeCaptured(t, "init"); err != nil {
		t.Fatal(err)
	}
	id := addForTagging(t, "Numeric")

	// Numeric positional args are taken as IDs, an ambiguity the CLI can't resolve, so the error must explain it
	if _, err := executeCaptured(t, "tag", itoa(id), "2026"); err == nil {
		t.Fatal("expected an error for an all-digit positional tag")
	}
	// --tag is taken literally; this is the path the GUI uses
	if _, err := executeCaptured(t, "tag", itoa(id), "--tag", "2026"); err != nil {
		t.Fatalf("--tag rejected an all-digit tag: %v", err)
	}
	if got := strings.Join(tagsOf(t, id), ","); got != "2026" {
		t.Fatalf("after --tag: %s", got)
	}
	if _, err := executeCaptured(t, "untag", itoa(id), "--tag", "2026"); err != nil {
		t.Fatalf("untag --tag failed: %v", err)
	}
	if got := tagsOf(t, id); len(got) != 0 {
		t.Fatalf("after untag --tag: %v", got)
	}
	// Mixing them makes ID parsing ambiguous, so reject it
	if _, err := executeCaptured(t, "tag", itoa(id), "v9", "--tag", "2026"); err == nil {
		t.Fatal("expected an error when mixing --tag with a positional tag")
	}
}
