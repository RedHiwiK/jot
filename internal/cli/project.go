package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
	"github.com/spf13/cobra"
)

func newProjectCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "project",
		Aliases: []string{"proj"},
		Short:   "Manage the project registry",
	}
	cmd.AddCommand(newProjectAddCmd(), newProjectLsCmd(), newProjectRmCmd(),
		newProjectRenameCmd(), newProjectSetCmd())
	return cmd
}

func newProjectAddCmd() *cobra.Command {

	cmd := &cobra.Command{
		Use:   "add <name> <repo-path>",
		Short: "Register a project manually (rarely needed: capture discovers them automatically)",
		Long: `Register a project by hand.

You rarely need this: capturing a requirement inside a git repository discovers and registers it automatically.
An ordinary directory can be registered too, as a category for personal requirements.`,
		Args: cobra.ExactArgs(2),
		Example: `  jot project add myapp ~/code/myapp
  jot project add api ~/code/api`,
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			name, path := args[0], args[1]
			p, err := s.AddProject(name, path)
			if err != nil {
				return err
			}

			// A missing repo path is not an error: it may not be cloned yet but can still be registered
			if _, err := os.Stat(p.RepoPath); os.IsNotExist(err) {
				fmt.Printf("%s path does not exist: %s\n", yellow("!"), p.RepoPath)
			} else if _, err := os.Stat(filepath.Join(p.RepoPath, ".git")); os.IsNotExist(err) {
				fmt.Printf("%s not a git repository: %s\n", yellow("!"), p.RepoPath)
			}

			fmt.Printf("%s %s → %s\n", green("✓"), cyan(p.Name), dim(p.RepoPath))
			return nil
		},
	}

	return cmd
}

func newProjectLsCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:     "ls",
		Aliases: []string{"list"},
		Short:   "List registered projects",
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			if asJSON {
				projects, err := projectsJSON(s)
				if err != nil {
					return err
				}
				return writeJSON(projects)
			}
			ps, err := s.ListProjects()
			if err != nil {
				return err
			}
			if len(ps) == 0 {
				fmt.Println(dim("No projects registered yet. Try: jot project add myapp ~/code/myapp"))
				return nil
			}

			for _, p := range ps {
				var open int
				s.DB().QueryRow(`SELECT COUNT(*) FROM reqs WHERE project_id = ? AND state NOT IN ('done','archived')`, p.ID).Scan(&open)

				cnt := dim("—")
				if open > 0 {
					cnt = fmt.Sprintf("%d open", open)
				}
				fmt.Printf("  %s %s %s\n",
					cyan(padRunes(p.Name, 14)),
					padRunes(cnt, 12),
					dim(p.RepoPath))

			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

func orDash(s string) string {
	if s == "" {
		return "—"
	}
	return s
}

func newProjectRmCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "rm <name>",
		Short: "Remove a project category, keeping every requirement and unlinking them",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			if err := s.RemoveProject(args[0]); err != nil {
				return err
			}
			if asJSON {
				return writeJSON(map[string]any{"removed": args[0], "requirements_preserved": true})
			}
			fmt.Printf("%s removed %s %s\n", green("✓"), args[0], dim("(markdown files kept)"))
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

func newProjectRenameCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "rename <old-name> <new-name>",
		Short: "Rename a project (its markdown directory moves too)",
		Long: `Change a project's display name.

Auto-discovery uses the repository directory name (myapp-monorepo); use this when you want a short one (myapp).`,
		Args:    cobra.ExactArgs(2),
		Example: `  jot project rename myapp-monorepo myapp`,
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			if err := s.RenameProject(args[0], args[1]); err != nil {
				return err
			}
			if asJSON {
				p, err := s.GetProjectByName(strings.TrimSpace(args[1]))
				if err != nil {
					return err
				}
				j, err := projectJSONFor(s, p)
				if err != nil {
					return err
				}
				return writeJSON(j)
			}
			fmt.Printf("%s %s → %s\n", green("✓"), dim(args[0]), cyan(args[1]))
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

func newProjectSetCmd() *cobra.Command {
	var color, repoURL string
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "set <name>",
		Short: "Change a project's color or repository URL",
		Long: `Change a project's display properties.

--color picks a named color (` + strings.Join(model.ProjectColors, ", ") + `), used to tint the
project's icon in the GUI sidebar; the GUI theme decides the actual shade.
--repo-url overrides the web address inferred from the origin remote.
Pass an empty string to clear either one.`,
		Args: cobra.ExactArgs(1),
		Example: `  jot project set myapp --color blue
  jot project set myapp --repo-url https://gitlab.example.com/team/myapp
  jot project set myapp --repo-url ""`,
		RunE: func(cmd *cobra.Command, args []string) error {
			colorChanged, urlChanged := cmd.Flags().Changed("color"), cmd.Flags().Changed("repo-url")
			if !colorChanged && !urlChanged {
				return fmt.Errorf("nothing to change; pass --color or --repo-url")
			}
			if colorChanged {
				// Validate before writing: when both fields change, an invalid color must not leave the URL already updated
				if _, err := model.ParseProjectColor(color); err != nil {
					return err
				}
			}
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			var p *model.Project
			if urlChanged {
				if p, err = s.SetProjectRepoURL(args[0], repoURL); err != nil {
					return err
				}
			}
			if colorChanged {
				if p, err = s.SetProjectColor(args[0], color); err != nil {
					return err
				}
			}
			if asJSON {
				j, err := projectJSONFor(s, p)
				if err != nil {
					return err
				}
				return writeJSON(j)
			}
			url, inferred := store.ProjectRepoURL(p)
			if inferred {
				url += dim(" (from git remote)")
			}
			fmt.Printf("%s %s  color: %s  repo: %s\n", green("✓"), cyan(p.Name), orDash(p.Color), orDash(url))
			return nil
		},
	}
	cmd.Flags().StringVar(&color, "color", "", "named color, or \"\" to clear")
	cmd.Flags().StringVar(&repoURL, "repo-url", "", "repository web URL, or \"\" to use the git remote")
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}
