package store

import (
	"strings"
	"testing"
)

func TestLinksBindInOrderAndSyncFrontmatter(t *testing.T) {
	s := testStore(t)
	r, err := s.CreateReq("Linked", "Body", "", nil)
	if err != nil {
		t.Fatal(err)
	}
	a, b := "https://github.com/o/r/pull/2", "https://github.com/o/r/pull/1"
	if _, err = s.AddLinks(r.ID, []string{a}); err != nil {
		t.Fatal(err)
	}
	links, err := s.AddLinks(r.ID, []string{b, a}) // duplicate is ignored
	if err != nil {
		t.Fatal(err)
	}
	if len(links) != 2 || links[0] != a || links[1] != b {
		t.Fatalf("links = %v", links)
	}

	got, _ := s.GetReq(r.ID)
	if err = s.SyncFrontmatter(got); err != nil {
		t.Fatal(err)
	}
	body, _ := s.ReadBody(got)
	if !strings.Contains(body, "links:\n  - "+a+"\n  - "+b+"\n") || !strings.Contains(body, "Body") {
		t.Fatalf("frontmatter missing links:\n%s", body)
	}

	listed, _ := s.ListReqs(ListFilter{})
	if len(listed) != 1 || len(listed[0].Links) != 2 {
		t.Fatalf("list did not load links: %+v", listed)
	}

	if links, _ = s.RemoveLinks(r.ID, []string{a}, false); len(links) != 1 || links[0] != b {
		t.Fatalf("after unlink = %v", links)
	}
	if links, _ = s.RemoveLinks(r.ID, nil, true); len(links) != 0 {
		t.Fatalf("after unlink --all = %v", links)
	}
	if _, err = s.AddLinks(999, []string{a}); err != ErrNotFound {
		t.Fatalf("missing requirement: %v", err)
	}
}
