package cli

import (
	"fmt"
	"os"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/spf13/cobra"
)

// triage sets the project for a batch of INBOX requirements in one call.
//
// It returns a result per requirement; failures are reported explicitly so they can be retried individually.
func newTriageCmd() *cobra.Command {
	var project string
	var asJSON bool

	cmd := &cobra.Command{
		Use:   "triage <id...>",
		Short: "Triage requirements: set the project, keep the current state",
		Long: `Triage requirements in INBOX: set the project, keep the current state.

Without --project, an existing project is kept; otherwise the capture directory is tried first, then the current directory.
When no project can be inferred the requirement stays in INBOX — a personal task need not belong to a repository.`,
		Args: cobra.MinimumNArgs(1),
		Example: `  jot triage 42                          # infer everything
  jot triage 42 43 44 --project myapp    # set one project for several`,
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			var results []reqJSON
			var failed []string

			for _, arg := range args {
				id, err := parseID(arg)
				if err != nil {
					return err
				}
				r, err := s.GetReq(id)
				if err != nil {
					failed = append(failed, fmt.Sprintf("#%s: %v", arg, err))
					continue
				}

				fields := map[string]any{}
				targetProject := project

				// Keep an existing value unless explicitly overridden
				if targetProject == "" {
					targetProject = r.Project
				}
				if targetProject == "" && r.OriginCwd != "" {
					if p, ok := s.ResolveProject(r.OriginCwd); ok {
						targetProject = p.Name
					}
				}
				if targetProject == "" {
					if cwd, err := os.Getwd(); err == nil {
						if p, ok := s.ResolveProject(cwd); ok {
							targetProject = p.Name
						}
					}
				}

				if targetProject != "" {
					p, err := s.GetProjectByName(targetProject)
					if err != nil {
						failed = append(failed, fmt.Sprintf("#%d: project %q is not registered", id, targetProject))
						continue
					}
					// Move the body only when the project changed.
					if targetProject != r.Project {
						fields["project_id"] = p.ID
						newPath := model.BodyPath(p.Name, r.ID, r.Title, r.CreatedAt)
						if err := s.MoveBody(r, newPath); err != nil {
							failed = append(failed, fmt.Sprintf("#%d: %v", id, err))
							continue
						}
						fields["body_path"] = newPath
						r.Project = p.Name
						r.ProjectID = &p.ID
					}
				}
				if len(fields) > 0 {
					if err := s.UpdateReqFields(id, fields); err != nil {
						failed = append(failed, fmt.Sprintf("#%d: %v", id, err))
						continue
					}
				}

				if err := s.SyncFrontmatter(r); err != nil {
					failed = append(failed, fmt.Sprintf("#%d: metadata updated, but body sync failed: %v", id, err))
					continue
				}
				results = append(results, toReqJSON(r))

				if !asJSON {
					fmt.Printf("%s #%d %s  %s\n", green("✓"), id,
						truncateDisplay(r.Title, 30), cyan(r.Project))
				}
			}

			if asJSON {
				if err := writeJSON(map[string]any{"reqs": results, "failed": failed}); err != nil {
					return err
				}
			} else {
				for _, f := range failed {
					fmt.Fprintf(os.Stderr, "%s %s\n", red("✗"), f)
				}
			}
			if len(failed) > 0 {
				return fmt.Errorf("%d requirement(s) failed", len(failed))
			}
			return nil
		},
	}

	cmd.Flags().StringVarP(&project, "project", "p", "", "owning project (inferred from cwd when omitted)")
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}
