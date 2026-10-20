package cli

import (
	"fmt"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
	"github.com/spf13/cobra"
)

// Links record which PRs/MRs implement a requirement. Like tags they use incremental verbs:
// an agent links once per PR it opens without dropping earlier links.

func newLinkCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "link <id> <url...>",
		Short: "Bind pull/merge request URLs to a requirement",
		Long: `Bind one or more URLs, typically the pull or merge requests that implement
the requirement. Already bound URLs are ignored. The GUI lists them on the
requirement's detail page.`,
		Example: `  jot link 42 https://github.com/owner/repo/pull/12
  jot link 42 https://gitlab.example.com/group/repo/-/merge_requests/34 --json`,
		Args: cobra.MinimumNArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			id, err := parseID(args[0])
			if err != nil {
				return err
			}
			urls, err := parseLinks(args[1:])
			if err != nil {
				return err
			}
			return applyLinkOp(id, func(s *store.Store) ([]string, error) { return s.AddLinks(id, urls) }, asJSON)
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

func newUnlinkCmd() *cobra.Command {
	var asJSON, all bool
	cmd := &cobra.Command{
		Use:   "unlink <id> <url...>",
		Short: "Remove bound URLs from a requirement",
		Example: `  jot unlink 42 https://github.com/owner/repo/pull/12
  jot unlink 42 --all`,
		Args: cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			id, err := parseID(args[0])
			if err != nil {
				return err
			}
			if all == (len(args) > 1) {
				return fmt.Errorf("pass either URLs or --all")
			}
			urls, err := parseLinks(args[1:])
			if err != nil {
				return err
			}
			return applyLinkOp(id, func(s *store.Store) ([]string, error) { return s.RemoveLinks(id, urls, all) }, asJSON)
		},
	}
	cmd.Flags().BoolVar(&all, "all", false, "remove every bound URL")
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

func parseLinks(args []string) ([]string, error) {
	out := make([]string, 0, len(args))
	for _, a := range args {
		u, err := model.ParseLink(a)
		if err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, nil
}

func applyLinkOp(id int64, op func(*store.Store) ([]string, error), asJSON bool) error {
	s, err := openStore()
	if err != nil {
		return err
	}
	defer s.Close()

	links, err := op(s)
	if err != nil {
		return err
	}
	r, err := s.GetReq(id)
	if err != nil {
		return err
	}
	// The frontmatter is a readable copy of the links and must be updated too, or agents reading the file see stale values
	if err := s.SyncFrontmatter(r); err != nil {
		return fmt.Errorf("links updated, but body sync failed: %w", err)
	}
	if asJSON {
		return writeJSON(toReqJSON(r))
	}
	if len(links) == 0 {
		fmt.Printf("%s #%d %s\n", green("✓"), id, dim("no links"))
		return nil
	}
	fmt.Printf("%s #%d\n  %s\n", green("✓"), id, strings.Join(links, "\n  "))
	return nil
}
