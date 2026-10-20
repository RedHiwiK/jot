package cli

import (
	"fmt"
	"os"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
	"github.com/spf13/cobra"
)

func newLsCmd() *cobra.Command {
	var stateFlag, project string
	var tagFlags, tagAnyFlags []string
	var all, asJSON, untagged bool

	cmd := &cobra.Command{
		Use:     "ls",
		Aliases: []string{"list"},
		Short:   "List requirements, grouped by state",
		Example: `  jot ls
  jot ls --state inbox
  jot ls --project myapp
  jot ls --tag v1.2.0
  jot ls --tag v1.2.0 --tag bug     # both tags (AND)
  jot ls --tag-any v1.2.0,v1.3.0    # either tag (OR)
  jot ls --all`,
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			tags, err := model.ParseTags(tagFlags)
			if err != nil {
				return err
			}
			tagsAny, err := model.ParseTags(tagAnyFlags)
			if err != nil {
				return err
			}
			f := store.ListFilter{
				Project: project, IncludeDone: all,
				Tags: tags, TagsAny: tagsAny, Untagged: untagged,
			}
			if stateFlag != "" {
				st, err := model.ParseState(stateFlag)
				if err != nil {
					return err
				}
				f.States = []model.State{st}
			}

			reqs, err := s.ListReqs(f)
			if err != nil {
				return err
			}

			if asJSON {
				projects, err := projectsJSON(s)
				if err != nil {
					return err
				}
				allTags, err := s.ListTags(all)
				if err != nil {
					return err
				}
				out := lsJSON{Reqs: make([]reqJSON, 0, len(reqs)), Projects: projects}
				for _, t := range allTags {
					out.Tags = append(out.Tags, tagJSON{Tag: t.Tag, Count: t.Count})
				}
				for _, r := range reqs {
					out.Reqs = append(out.Reqs, toReqJSON(r))
				}
				// cwd is the strongest triage signal: requirements usually belong to the repo the agent runs in
				if cwd, err := os.Getwd(); err == nil {
					out.Cwd = cwd
					if p, ok := s.DetectProject(cwd); ok {
						out.DetectedProject = p.Name
					}
				}
				return writeJSON(out)
			}

			if len(reqs) == 0 {
				fmt.Println(dim("Empty. Capture your first requirement with: jot add \"...\""))
				return nil
			}

			printGrouped(reqs, all)
			return nil
		},
	}

	cmd.Flags().StringVarP(&stateFlag, "state", "s", "", "filter by state")
	cmd.Flags().StringVarP(&project, "project", "p", "", "filter by project")
	cmd.Flags().StringArrayVar(&tagFlags, "tag", nil, "filter by tag; repeat to require all of them")
	cmd.Flags().StringArrayVar(&tagAnyFlags, "tag-any", nil, "filter by tag, matching any one of them")
	cmd.Flags().BoolVar(&untagged, "untagged", false, "only requirements with no tags")
	cmd.Flags().BoolVarP(&all, "all", "a", false, "include done / archived")
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output, for skill use")
	return cmd
}

// printGrouped prints requirements grouped by state, in board order.
func printGrouped(reqs []*model.Req, all bool) {
	byState := map[model.State][]*model.Req{}
	for _, r := range reqs {
		byState[r.State] = append(byState[r.State], r)
	}

	order := model.BoardStates
	if all {
		order = model.AllStates
	} else {
		// With an explicit --state archived / done, those states are not in the board order,
		// so their groups would be skipped and the output left blank. Append the states that actually occur.
		for _, st := range model.AllStates {
			if len(byState[st]) == 0 {
				continue
			}
			found := false
			for _, o := range order {
				if o == st {
					found = true
					break
				}
			}
			if !found {
				order = append(order, st)
			}
		}
	}

	first := true
	for _, st := range order {
		group := byState[st]
		if len(group) == 0 {
			continue
		}
		if !first {
			fmt.Println()
		}
		first = false

		fmt.Printf("%s %s\n", stateLabel(st), dim(fmt.Sprintf("(%d)", len(group))))
		for _, r := range group {
			printReqLine(r)
		}
	}
}

func printReqLine(r *model.Req) {
	proj := r.Project
	if proj == "" {
		proj = "—"
	}

	// Pad the plain text first, then colorize: ANSI codes take no display width but break length calculations
	fmt.Printf("  %s %s  %s %s%s\n",
		dim(fmt.Sprintf("#%-4d", r.ID)),
		padRunes(truncateDisplay(r.Title, 44), 44),
		colorPad(proj, 12, cyan),
		dim(humanAge(r.UpdatedAt)),
		tagSuffix(r.Tags))
}

// colorPad pads to the display width before colorizing so ANSI codes don't break alignment
func colorPad(s string, width int, fn func(string) string) string {
	if s == "" {
		return spaces(width)
	}
	return fn(padRunes(truncateDisplay(s, width), width))
}

// tagSuffix appends tags to the end of the row. Tags are optional, so they get no fixed column;
// rows without tags should not carry trailing blank space.
func tagSuffix(tags []string) string {
	if len(tags) == 0 {
		return ""
	}
	return "  " + blue(strings.Join(tags, " "))
}

func stateLabel(st model.State) string {
	l := bold(st.Display())
	switch st {
	case model.StateInbox:
		return dim(st.Display())
	case model.StateInProgress:
		return green(l)
	case model.StateOnHold:
		return yellow(l)
	case model.StateDone:
		return dim(st.Display())
	case model.StateArchived:
		return dim(st.Display())
	}
	return l
}
