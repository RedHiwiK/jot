package model

import (
	"fmt"
	"regexp"
	"strings"
	"time"
)

// State is a requirement's lifecycle state. Each state answers "whose court is the ball in now".
type State string

const (
	StateInbox      State = "inbox"       // on me: a rough capture, not yet triaged
	StateInProgress State = "in_progress" // set manually: being worked on; does not mean a process is running
	StateOnHold     State = "on_hold"     // deferred or waiting on something external
	StateDone       State = "done"        // completed
	StateArchived   State = "archived"    // dropped
)

var AllStates = []State{StateInbox, StateInProgress, StateOnHold, StateDone, StateArchived}

// Display order on the board (archived/done are hidden by default)
var BoardStates = []State{StateInbox, StateInProgress, StateOnHold}

func ParseState(s string) (State, error) {
	st := State(strings.ToLower(strings.TrimSpace(s)))
	for _, v := range AllStates {
		if v == st {
			return st, nil
		}
	}
	return "", fmt.Errorf("unknown state %q (available: inbox/in_progress/on_hold/done/archived)", s)
}

func (s State) Display() string {
	return strings.ToUpper(string(s))
}

// Req is a single requirement.
type Req struct {
	ID       int64
	Title    string
	BodyPath string // path relative to reqs/, e.g. myapp/0042-2026-08-26-slow-search.md
	State    State

	ProjectID *int64
	Project   string // denormalized project name from a join, for display
	Priority  int

	Tags []string // free-form tags such as v2.4.4 / bug, normalized to lowercase

	Links []string // linked PRs/MRs and other external URLs, in the order added

	// capture origin, for tracing where a requirement came from
	OriginCwd  string
	OriginNote string

	CreatedAt  time.Time
	UpdatedAt  time.Time
	StartedAt  *time.Time
	FinishedAt *time.Time
	DoneAt     *time.Time
}

// Project is a registered code repository.
type Project struct {
	ID        int64
	Name      string
	RepoPath  string
	Color     string // a color name from ProjectColors; empty means no color
	RepoURL   string // manually configured repo web URL; empty means infer from the git remote
	CreatedAt time.Time
}

// ProjectColors are the colors available for a project's icon in the GUI sidebar. Names are stored, not values:
// the GUI theme decides the actual color, so project colors follow theme changes instead of being fixed hex values.
var ProjectColors = []string{"red", "orange", "yellow", "green", "teal", "blue", "purple", "gray"}

// ParseProjectColor validates a color name. An empty string clears the color.
func ParseProjectColor(s string) (string, error) {
	c := strings.ToLower(strings.TrimSpace(s))
	if c == "" {
		return "", nil
	}
	for _, v := range ProjectColors {
		if v == c {
			return c, nil
		}
	}
	return "", fmt.Errorf("unknown color %q (available: %s)", s, strings.Join(ProjectColors, "/"))
}

// StateLog records state transitions, to answer "why has this been stuck for three days".
type StateLog struct {
	ID        int64
	ReqID     int64
	FromState State
	ToState   State
	Actor     string // human | cli
	CreatedAt time.Time
}

const InboxDir = "_inbox"

// Characters not allowed in file names
var illegalFilenameChars = regexp.MustCompile(`[/\\:*?"<>|]`)
var whitespaceRun = regexp.MustCompile(`\s+`)

// FileName builds a requirement's markdown file name.
//
// Format: 0042-2026-08-26-search-page-loads-slowly.md
//
// The date is part of the name so sorting by name is chronological. Non-ASCII titles are kept
// as-is: the files only live on the local filesystem, so there is no portability issue.
// The requirement ID stays stable while the title may change.
func FileName(id int64, title string, created time.Time) string {
	t := illegalFilenameChars.ReplaceAllString(title, "")
	t = whitespaceRun.ReplaceAllString(strings.TrimSpace(t), "-")
	t = strings.Trim(t, "-.")
	t = truncateRunes(t, 40)
	if t == "" {
		t = "untitled"
	}
	return fmt.Sprintf("%04d-%s-%s.md", id, created.Format("2006-01-02"), t)
}

// BodyPath builds the full path relative to reqs/. An empty project goes to _inbox/.
func BodyPath(project string, id int64, title string, created time.Time) string {
	dir := project
	if dir == "" {
		dir = InboxDir
	}
	return dir + "/" + FileName(id, title, created)
}

// truncateRunes truncates by rune so multi-byte characters are not split.
func truncateRunes(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return strings.TrimRight(string(r[:n]), "-.")
}

// Tags are free text but must be normalized, or V2.4.4 and v2.4.4 would become two tags.
// Letters, digits and . _ / - are allowed (covers v2.4.4, p0, ui/board); spaces and commas are CLI
// separators and cannot appear in tags.
var illegalTagChars = regexp.MustCompile(`[^\p{L}\p{N}._/-]`)

const MaxTagLen = 32

// NormalizeTag cleans user input into a canonical tag. An empty result means the input had no valid characters.
func NormalizeTag(s string) string {
	t := strings.ToLower(strings.TrimSpace(s))
	t = strings.TrimPrefix(t, "#") // allow the #v2.4.4 form
	t = illegalTagChars.ReplaceAllString(t, "")
	t = strings.Trim(t, "-._/")
	// Truncation may leave a trailing separator (v2.4.4-long… → …-), so trim again
	return strings.Trim(truncateRunes(t, MaxTagLen), "-._/")
}

// ParseTags parses tag input: comma-separated or repeated flags, deduplicated in order of appearance.
// Invalid inputs (empty after cleaning) are reported so tags are never dropped silently.
func ParseTags(inputs []string) ([]string, error) {
	var out []string
	seen := map[string]bool{}
	for _, raw := range inputs {
		for _, part := range strings.Split(raw, ",") {
			if strings.TrimSpace(part) == "" {
				continue
			}
			t := NormalizeTag(part)
			if t == "" {
				return nil, fmt.Errorf("invalid tag %q (use letters, digits, and . _ / -)", strings.TrimSpace(part))
			}
			if !seen[t] {
				seen[t] = true
				out = append(out, t)
			}
		}
	}
	return out, nil
}

// ParseLink validates and normalizes an external link (a PR/MR URL).
func ParseLink(raw string) (string, error) {
	u := strings.TrimRight(strings.TrimSpace(raw), "/")
	if !strings.HasPrefix(u, "https://") && !strings.HasPrefix(u, "http://") {
		return "", fmt.Errorf("link must start with http:// or https://: %q", raw)
	}
	if strings.ContainsAny(u, " \t\n") {
		return "", fmt.Errorf("link must not contain whitespace: %q", raw)
	}
	return u, nil
}
