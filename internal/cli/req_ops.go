package cli

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
	"github.com/spf13/cobra"
)

func parseID(s string) (int64, error) {
	id, err := strconv.ParseInt(strings.TrimPrefix(s, "#"), 10, 64)
	if err != nil {
		return 0, fmt.Errorf("requirement ID must be a number, got %q", s)
	}
	return id, nil
}

func newShowCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "show <id>",
		Short: "Show a requirement, including its markdown body",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			id, err := parseID(args[0])
			if err != nil {
				return err
			}
			r, err := s.GetReq(id)
			if err != nil {
				return err
			}

			if asJSON {
				j := toReqJSON(r)
				body, err := s.ReadBody(r)
				if err != nil {
					return fmt.Errorf("read body: %w", err)
				}
				j.Note = stripFrontmatter(body)
				return writeJSON(j)
			}

			fmt.Printf("%s %s\n", bold(fmt.Sprintf("#%d", r.ID)), bold(r.Title))
			fmt.Printf("%s  %s\n", stateLabel(r.State), dim(humanAgo(r.CreatedAt)))

			kv := func(k, v string) {
				if v != "" {
					fmt.Printf("  %s %s\n", dim(padRunes(k, 8)), v)
				}
			}
			fmt.Println()
			kv("Project", r.Project)
			kv("Tags", strings.Join(r.Tags, " "))
			kv("Links", strings.Join(r.Links, "\n           "))
			kv("Source", r.OriginCwd)
			kv("File", s.AbsBodyPath(r))

			body, err := s.ReadBody(r)
			if err != nil {
				return fmt.Errorf("read body: %w", err)
			}
			{
				fmt.Printf("\n%s\n", dim(strings.Repeat("─", 50)))
				fmt.Println(stripFrontmatter(body))
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

func stripFrontmatter(s string) string {
	if !strings.HasPrefix(s, "---\n") {
		return s
	}
	if i := strings.Index(s[4:], "\n---\n"); i >= 0 {
		return strings.TrimLeft(s[4+i+5:], "\n")
	}
	return s
}

func newEditCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "edit <id>",
		Short: "Open the markdown body in $EDITOR",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			id, err := parseID(args[0])
			if err != nil {
				return err
			}
			r, err := s.GetReq(id)
			if err != nil {
				return err
			}

			editor := s.GetConfig(store.KeyEditor)
			if editor == "" {
				editor = os.Getenv("EDITOR")
			}
			if editor == "" {
				editor = "vi"
			}
			c := exec.Command(editor, s.AbsBodyPath(r))
			c.Stdin, c.Stdout, c.Stderr = os.Stdin, os.Stdout, os.Stderr
			return c.Run()
		},
	}
}

func newSetCmd() *cobra.Command {
	var project, title string
	var tagFlags []string
	var priority int
	var asJSON bool

	cmd := &cobra.Command{
		Use:   "set <id>",
		Short: "Set a requirement's project or title",
		Long:  "Fill in requirement metadata. Changing the project moves the markdown file to the matching directory.",
		Args:  cobra.ExactArgs(1),
		Example: `  jot set 42 --project myapp
  jot set 42 --title "Search page is slow on first paint"`,
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			id, err := parseID(args[0])
			if err != nil {
				return err
			}
			r, err := s.GetReq(id)
			if err != nil {
				return err
			}

			fields := map[string]any{}

			if cmd.Flags().Changed("project") {
				var projectID *int64
				projectName := ""
				if project != "" {
					p, err := s.GetProjectByName(project)
					if err != nil {
						return fmt.Errorf("project %q is not registered", project)
					}
					projectID, projectName = &p.ID, p.Name
				}
				fields["project_id"] = projectID
				// The project changed, so move the markdown to the new directory (_inbox/ → myapp/)
				newTitle := r.Title
				if title != "" {
					newTitle = title
				}
				newPath := model.BodyPath(projectName, r.ID, newTitle, r.CreatedAt)
				if err := s.MoveBody(r, newPath); err != nil {
					return err
				}
				fields["body_path"] = newPath
				r.Project, r.ProjectID = projectName, projectID
			}
			if title != "" {
				fields["title"] = title
				r.Title = title
			}
			if cmd.Flags().Changed("priority") {
				fields["priority"] = priority
			}

			// --tags replaces the whole set; use jot tag / jot untag for incremental changes
			tagsChanged := cmd.Flags().Changed("tags")
			if len(fields) == 0 && !tagsChanged {
				return fmt.Errorf("nothing to change (use --project / --title / --priority / --tags)")
			}
			if err := s.UpdateReqFields(id, fields); err != nil {
				return err
			}
			if tagsChanged {
				tags, err := model.ParseTags(tagFlags)
				if err != nil {
					return err
				}
				if r.Tags, err = s.SetTags(id, tags); err != nil {
					return err
				}
			}
			if err := s.SyncFrontmatter(r); err != nil {
				return err
			}

			if asJSON {
				r2, _ := s.GetReq(id)
				return writeJSON(toReqJSON(r2))
			}
			fmt.Printf("%s #%d updated\n", green("✓"), id)
			return nil
		},
	}

	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	cmd.Flags().StringVarP(&project, "project", "p", "", "owning project")
	cmd.Flags().StringVarP(&title, "title", "t", "", "new title")
	cmd.Flags().IntVar(&priority, "priority", 0, "priority (0 normal / 1 high)")
	cmd.Flags().StringArrayVar(&tagFlags, "tags", nil, "replace all tags (comma-separated; empty clears)")
	return cmd
}

func newMvCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "mv <id> <state>",
		Short: "Change state manually",
		Long:  "States are moved manually: inbox / in_progress / on_hold / done / archived",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			id, err := parseID(args[0])
			if err != nil {
				return err
			}
			st, err := model.ParseState(args[1])
			if err != nil {
				return err
			}
			r, err := s.GetReq(id)
			if err != nil {
				return err
			}
			if r.State == st {
				if asJSON {
					return writeJSON(toReqJSON(r))
				}
				fmt.Printf("#%d is already %s\n", id, st.Display())
				return nil
			}

			if err := s.SetState(r, st, "human"); err != nil {
				return err
			}
			if err := s.SyncFrontmatter(r); err != nil {
				return err
			}
			if asJSON {
				return writeJSON(toReqJSON(r))
			}
			fmt.Printf("%s #%d → %s\n", green("✓"), id, stateLabel(st))
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

func newRmCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "rm <id>",
		Short: "Archive a requirement (recoverable; the markdown file is kept)",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			id, err := parseID(args[0])
			if err != nil {
				return err
			}
			r, err := s.GetReq(id)
			if err != nil {
				return err
			}
			if err := s.SetState(r, model.StateArchived, "human"); err != nil {
				return err
			}
			if err := s.SyncFrontmatter(r); err != nil {
				return err
			}
			fmt.Printf("%s #%d archived %s\n", green("✓"), id, dim("(file kept at "+r.BodyPath+")"))
			return nil
		},
	}
}

func newPurgeCmd() *cobra.Command {
	var yes bool
	cmd := &cobra.Command{
		Use:   "purge <id>...",
		Short: "Permanently delete archived requirements (database rows + markdown files)",
		Long: `Really delete archived requirements: neither the database row nor the markdown file survives.

How this differs from rm: rm is a soft delete (moved to the archive, recoverable any time), while purge is a hard delete and cannot be undone.
Only archived requirements can be purged — to drop one still in flight, archive it with jot rm first.

Several at once is fine: jot purge 3 5 8`,
		Args: cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			// Look everything up and show what will be deleted before asking; never delete while still prompting
			type victim struct {
				id    int64
				title string
			}
			var list []victim
			for _, a := range args {
				id, err := parseID(a)
				if err != nil {
					return err
				}
				r, err := s.GetReq(id)
				if err != nil {
					return err
				}
				if r.State != model.StateArchived {
					return fmt.Errorf("#%d %q is not archived; run jot rm %d first", id, r.Title, id)
				}
				list = append(list, victim{id, r.Title})
			}

			if !yes {
				fmt.Printf("%s About to permanently delete %d requirement(s). This cannot be undone:\n", yellow("!"), len(list))
				for _, v := range list {
					fmt.Printf("  #%d %s\n", v.id, v.title)
				}
				fmt.Print("Type yes to confirm: ")
				var answer string
				fmt.Scanln(&answer)
				if strings.TrimSpace(answer) != "yes" {
					fmt.Println(dim("Cancelled"))
					return nil
				}
			}

			for _, v := range list {
				if err := s.PurgeReq(v.id); err != nil {
					return err
				}
				fmt.Printf("%s #%d permanently deleted\n", green("✓"), v.id)
			}
			return nil
		},
	}
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "skip confirmation")
	return cmd
}

func newPathCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "path <id>",
		Short: "Print the absolute markdown path (for use with other commands)",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			id, err := parseID(args[0])
			if err != nil {
				return err
			}
			r, err := s.GetReq(id)
			if err != nil {
				return err
			}
			fmt.Println(s.AbsBodyPath(r))
			return nil
		},
	}
}

func newSyncCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "sync",
		Short: "Rewrite every markdown frontmatter from the SQLite values",
		Long:  "Frontmatter is a redundant readable copy; SQLite is authoritative. Use this to repair drift.",
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			reqs, err := s.ListReqs(store.ListFilter{IncludeDone: true})
			if err != nil {
				return err
			}
			var fixed, missing int
			for _, r := range reqs {
				if _, err := os.Stat(s.AbsBodyPath(r)); os.IsNotExist(err) {
					if err := s.WriteBody(r, ""); err == nil {
						missing++
					}
					continue
				}
				if err := s.SyncFrontmatter(r); err == nil {
					fixed++
				}
			}
			fmt.Printf("%s synced %d file(s)", green("✓"), fixed)
			if missing > 0 {
				fmt.Printf(", rebuilt %d missing", missing)
			}
			fmt.Println()
			return nil
		},
	}
}
