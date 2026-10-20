package store

import (
	"os"
	"strings"
	"testing"

	"github.com/RedHiwiK/jot/internal/model"
)

func mustReq(t *testing.T, s *Store, title string) *model.Req {
	t.Helper()
	r, err := s.CreateReq(title, "", "", nil)
	if err != nil {
		t.Fatal(err)
	}
	return r
}

func TestNormalizeTag(t *testing.T) {
	cases := map[string]string{
		"v2.4.4":    "v2.4.4",
		"  V2.4.4 ": "v2.4.4",
		"#v2.4.4":   "v2.4.4",
		"UI/Board":  "ui/board",
		"a b":       "ab", // space is a separator, not part of the tag
		"!!!":       "",
		"-x-":       "x",
		"版本2":       "版本2", // non-ASCII letters and digits are kept
	}
	for in, want := range cases {
		if got := model.NormalizeTag(in); got != want {
			t.Errorf("NormalizeTag(%q) = %q, want %q", in, got, want)
		}
	}
	// Truncating an overlong tag must not leave a trailing separator
	long := model.NormalizeTag(strings.Repeat("a", model.MaxTagLen) + "-tail")
	if len(long) > model.MaxTagLen || strings.HasSuffix(long, "-") {
		t.Errorf("truncation left %q", long)
	}
}

func TestParseTagsDedupesAndSplits(t *testing.T) {
	got, err := model.ParseTags([]string{"v2.4.4,BUG", "bug", " ui "})
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"v2.4.4", "bug", "ui"}
	if strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("got %v, want %v", got, want)
	}
	if _, err := model.ParseTags([]string{"!!!"}); err == nil {
		t.Fatal("expected an error for an all-invalid tag")
	}
}

func TestTagAddRemoveSet(t *testing.T) {
	s := testStore(t)
	r := mustReq(t, s, "Tagged")

	if _, err := s.AddTags(r.ID, []string{"v2.4.4", "bug"}); err != nil {
		t.Fatal(err)
	}
	// Adding a duplicate must neither fail nor create a duplicate row
	tags, err := s.AddTags(r.ID, []string{"bug"})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(tags, ",") != "bug,v2.4.4" {
		t.Fatalf("after re-add: %v", tags)
	}

	if tags, err = s.RemoveTags(r.ID, []string{"bug", "never-set"}); err != nil {
		t.Fatal(err)
	}
	if strings.Join(tags, ",") != "v2.4.4" {
		t.Fatalf("after remove: %v", tags)
	}

	if tags, err = s.SetTags(r.ID, []string{"only"}); err != nil {
		t.Fatal(err)
	}
	if strings.Join(tags, ",") != "only" {
		t.Fatalf("after set: %v", tags)
	}
	if tags, err = s.SetTags(r.ID, nil); err != nil {
		t.Fatal(err)
	}
	if len(tags) != 0 {
		t.Fatalf("after clear: %v", tags)
	}
}

func TestTagOpsRejectMissingRequirement(t *testing.T) {
	s := testStore(t)
	if _, err := s.AddTags(9999, []string{"x"}); err != ErrNotFound {
		t.Fatalf("got %v, want ErrNotFound", err)
	}
}

func TestListReqsTagFilters(t *testing.T) {
	s := testStore(t)
	a := mustReq(t, s, "A")
	b := mustReq(t, s, "B")
	mustReq(t, s, "C") // untagged

	if _, err := s.AddTags(a.ID, []string{"v2.4.4", "bug"}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.AddTags(b.ID, []string{"v2.4.4"}); err != nil {
		t.Fatal(err)
	}

	ids := func(f ListFilter) []int64 {
		t.Helper()
		reqs, err := s.ListReqs(f)
		if err != nil {
			t.Fatal(err)
		}
		var out []int64
		for _, r := range reqs {
			out = append(out, r.ID)
		}
		return out
	}

	// AND: both tags required
	if got := ids(ListFilter{Tags: []string{"v2.4.4", "bug"}}); len(got) != 1 || got[0] != a.ID {
		t.Fatalf("AND filter returned %v", got)
	}
	// OR: either tag matches
	if got := ids(ListFilter{TagsAny: []string{"bug", "v2.4.4"}}); len(got) != 2 {
		t.Fatalf("OR filter returned %v", got)
	}
	// Untagged
	if got := ids(ListFilter{Untagged: true}); len(got) != 1 {
		t.Fatalf("untagged filter returned %v", got)
	}
	// List queries must return tags too, or the display layer would have to fetch them one by one
	reqs, err := s.ListReqs(ListFilter{Tags: []string{"bug"}})
	if err != nil {
		t.Fatal(err)
	}
	if len(reqs) != 1 || strings.Join(reqs[0].Tags, ",") != "bug,v2.4.4" {
		t.Fatalf("tags were not loaded: %+v", reqs)
	}
}

func TestRenameTagMergesInsteadOfDuplicating(t *testing.T) {
	s := testStore(t)
	r := mustReq(t, s, "Both")
	if _, err := s.AddTags(r.ID, []string{"v2.4.4", "v2.4.5"}); err != nil {
		t.Fatal(err)
	}
	// Renaming onto an existing tag merges them instead of violating the primary key
	if _, err := s.RenameTag("v2.4.4", "v2.4.5"); err != nil {
		t.Fatal(err)
	}
	tags, err := s.ReqTags(r.ID)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(tags, ",") != "v2.4.5" {
		t.Fatalf("after rename: %v", tags)
	}
	if _, err := s.RenameTag("gone", "x"); err == nil {
		t.Fatal("expected an error renaming an unused tag")
	}
}

func TestDeleteTagLeavesRequirements(t *testing.T) {
	s := testStore(t)
	r := mustReq(t, s, "Keep me")
	if _, err := s.AddTags(r.ID, []string{"drop", "keep"}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeleteTag("drop"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetReq(r.ID); err != nil {
		t.Fatalf("requirement was removed along with the tag: %v", err)
	}
	tags, _ := s.ReqTags(r.ID)
	if strings.Join(tags, ",") != "keep" {
		t.Fatalf("after delete: %v", tags)
	}
}

func TestListTagsCountsOpenOnly(t *testing.T) {
	s := testStore(t)
	open := mustReq(t, s, "Open")
	closed := mustReq(t, s, "Closed")
	for _, r := range []*model.Req{open, closed} {
		if _, err := s.AddTags(r.ID, []string{"shared"}); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.SetState(closed, model.StateDone, "cli"); err != nil {
		t.Fatal(err)
	}

	tags, err := s.ListTags(false)
	if err != nil {
		t.Fatal(err)
	}
	if len(tags) != 1 || tags[0].Count != 1 {
		t.Fatalf("open-only count = %+v, want shared:1", tags)
	}
	if tags, err = s.ListTags(true); err != nil || tags[0].Count != 2 {
		t.Fatalf("include-done count = %+v (err %v), want shared:2", tags, err)
	}
}

func TestFrontmatterCarriesTags(t *testing.T) {
	s := testStore(t)
	r := mustReq(t, s, "Front")

	body, err := s.ReadBody(r)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(body, "tags:") {
		t.Fatal("an untagged requirement should not get a tags line")
	}

	if r.Tags, err = s.AddTags(r.ID, []string{"v2.4.4", "bug"}); err != nil {
		t.Fatal(err)
	}
	if err := s.SyncFrontmatter(r); err != nil {
		t.Fatal(err)
	}
	if body, err = s.ReadBody(r); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(body, "tags: [bug, v2.4.4]") {
		t.Fatalf("frontmatter missing tags:\n%s", body)
	}
	// Sync must not stack duplicate frontmatter blocks
	if strings.Count(body, "---") != 2 {
		t.Fatalf("frontmatter delimiters duplicated:\n%s", body)
	}
}

func TestPurgeRemovesTagRows(t *testing.T) {
	s := testStore(t)
	r := mustReq(t, s, "Doomed")
	if _, err := s.AddTags(r.ID, []string{"x"}); err != nil {
		t.Fatal(err)
	}
	if err := s.SetState(r, model.StateArchived, "cli"); err != nil {
		t.Fatal(err)
	}
	if err := s.PurgeReq(r.ID); err != nil {
		t.Fatal(err)
	}
	var n int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM req_tags WHERE req_id = ?`, r.ID).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatalf("%d orphan tag rows remain", n)
	}
	if _, err := os.Stat(s.AbsBodyPath(r)); !os.IsNotExist(err) {
		t.Fatal("body file survived the purge")
	}
}
