package cli

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
	"github.com/spf13/cobra"
)

func newInitCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "init",
		Short: "Initialize ~/.jot/",
		RunE: func(cmd *cobra.Command, args []string) error {
			existed := store.Exists()
			s, err := store.Open()
			if err != nil {
				return err
			}
			defer s.Close()
			if existed {
				fmt.Printf("already exists: %s\n", s.Root())
				return nil
			}
			fmt.Printf("✓ initialized: %s\n\n", s.Root())
			fmt.Println("Next, register a project:")
			fmt.Println("  jot project add myapp ~/code/myapp")
			return nil
		},
	}
}

func newAddCmd() *cobra.Command {
	var note, project string
	var tagFlags []string
	var asJSON, fromStdin, unfiled bool

	cmd := &cobra.Command{
		Use:   "add [title]",
		Short: "Capture a requirement into INBOX",
		Long: `Capture a requirement into INBOX.

This is the entry point of the whole tool, designed to cost less effort than not writing it down.
Capture asks nothing: the project is an optional category you can fill in later.`,
		Example: `  jot add "Search page is slow"
  jot add "Search is slow" --note "Traced to a direct DB query inside onChange"
  jot add "Ship the new board" --tag v2.4.4
  jot add --stdin  < ideas.txt`,
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			titles, err := collectTitles(args, fromStdin)
			if err != nil {
				return err
			}
			if len(titles) == 0 {
				return fmt.Errorf("nothing to capture")
			}

			if unfiled && project != "" {
				return fmt.Errorf("--unfiled and --project cannot be used together")
			}
			tags, err := model.ParseTags(tagFlags)
			if err != nil {
				return err
			}
			cwd, _ := os.Getwd()

			// Project resolution: explicit flag > inferred from cwd > empty (goes to _inbox)
			var projectID *int64
			if project != "" {
				p, err := s.GetProjectByName(project)
				if err != nil {
					return fmt.Errorf("project %q is not registered", project)
				}
				projectID = &p.ID
			} else if !unfiled {
				if p, ok := s.ResolveProject(cwd); ok {
					// Auto-discovery: a cwd inside a git repo is registered on the fly; no prior project add required
					projectID = &p.ID
				}
			}

			var created []*model.Req
			for _, t := range titles {
				r, err := s.CreateReq(t, note, cwd, projectID)
				if err != nil {
					return err
				}
				if len(tags) > 0 {
					if r.Tags, err = s.SetTags(r.ID, tags); err != nil {
						return err
					}
					// Tags are written after the row is created, so the frontmatter needs another sync
					if err := s.SyncFrontmatter(r); err != nil {
						return err
					}
				}
				created = append(created, r)
			}

			if asJSON {
				return emitJSON(created)
			}
			return emitHuman(created)
		},
	}

	cmd.Flags().StringVar(&note, "note", "", "context summary, written into the markdown notes section")
	cmd.Flags().StringArrayVar(&tagFlags, "tag", nil, "tag to attach (repeatable, or comma-separated)")
	cmd.Flags().StringVarP(&project, "project", "p", "", "explicit project (inferred from the current directory when omitted)")
	cmd.Flags().BoolVar(&unfiled, "unfiled", false, "skip project inference; capture as a personal task")
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output, for skill use")
	cmd.Flags().BoolVar(&fromStdin, "stdin", false, "read from stdin, one requirement per line")
	return cmd
}

// collectTitles accepts three inputs: arguments, stdin, and a pipe
func collectTitles(args []string, fromStdin bool) ([]string, error) {
	if fromStdin || (len(args) == 0 && !isTTY(os.Stdin)) {
		var out []string
		sc := bufio.NewScanner(os.Stdin)
		for sc.Scan() {
			if line := strings.TrimSpace(sc.Text()); line != "" {
				out = append(out, line)
			}
		}
		return out, sc.Err()
	}
	if len(args) > 0 {
		// Split multi-line arguments too (a skill may pass a whole paragraph at once)
		var out []string
		for _, a := range args {
			for _, line := range strings.Split(a, "\n") {
				if line = strings.TrimSpace(line); line != "" {
					out = append(out, line)
				}
			}
		}
		return out, nil
	}
	return nil, nil
}

func emitJSON(reqs []*model.Req) error {
	items := make([]reqJSON, len(reqs))
	for i, r := range reqs {
		items[i] = toReqJSON(r)
	}
	if len(items) == 1 {
		return writeJSON(items[0])
	}
	return writeJSON(items)
}

// emitHuman prints a one-line receipt, not the full card, so the user can get back to their task.
func emitHuman(reqs []*model.Req) error {
	ids := make([]string, len(reqs))
	for i, r := range reqs {
		ids[i] = fmt.Sprintf("#%d", r.ID)
	}
	proj := reqs[0].Project
	if proj == "" {
		proj = "_inbox"
	}
	fmt.Printf("%s %s captured into INBOX  %s\n", green("✓"), strings.Join(ids, " "), dim(proj))
	return nil
}
