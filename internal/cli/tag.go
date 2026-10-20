package cli

import (
	"fmt"
	"os"
	"strings"

	"github.com/RedHiwiK/jot/internal/model"
	"github.com/RedHiwiK/jot/internal/store"
	"github.com/spf13/cobra"
)

// Tag operations have two semantics, deliberately exposed as different commands:
//   jot tag / untag   incremental, touches only the given tags
//   jot set --tags    replaces the whole set
//
// They are separate because an agent using the replace form as if it were incremental silently drops tags.
// With a dedicated incremental verb, a mistake costs an extra tag rather than deleting others.

func newTagCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "tag <id...> <tag...>",
		Short: "Add tags to requirements (incremental)",
		Long: `Add tags to one or more requirements, keeping the tags they already have.

Tags are free-form labels such as a version number (v2.4.4) or a theme (bug).
They are normalized to lower case; a leading # is dropped, so v2.4.4 and #V2.4.4
are the same tag. Use jot set --tags to replace a requirement's tags outright.`,
		Example: `  jot tag 42 v2.4.4
  jot tag 42 43 44 v2.4.4        # tag a batch for one release
  jot tag 42 v2.4.4,bug          # comma-separated also works
  jot tag 42 --tag 2026          # --tag takes the value literally, digits included
  jot tag 42 --clear             # drop every tag`,
		Args: cobra.MinimumNArgs(1),
		RunE: runTagAdd,
	}
	cmd.Flags().Bool("clear", false, "remove every tag from the given requirements")
	cmd.Flags().StringArray("tag", nil, "tag to add, taken literally (use for an all-digit tag)")
	cmd.Flags().Bool("json", false, "machine-readable output")

	cmd.AddCommand(newTagLsCmd(), newTagRenameCmd(), newTagRmCmd())
	return cmd
}

// splitIDsAndTags splits `42 43 v2.4.4 bug` into IDs and tags.
// Leading numbers (or #numbers) are IDs; everything from the first non-number on is a tag.
//
// Positional args can't distinguish "ID 42" from "tag 42", so numeric tags must use --tag.
// When allPositionalAreIDs is true (the caller supplied all tags via --tag), every arg is parsed as an ID,
// so `jot tag 13 --tag 2026` does not swallow 2026 as a second ID.
func splitIDsAndTags(args []string, allPositionalAreIDs bool) ([]int64, []string, error) {
	var ids []int64
	i := 0
	for ; i < len(args); i++ {
		id, err := parseID(args[i])
		if err != nil {
			if allPositionalAreIDs {
				return nil, nil, fmt.Errorf("%q is not a requirement ID; tags given with --tag cannot be mixed with positional tags", args[i])
			}
			break
		}
		ids = append(ids, id)
	}
	if len(ids) == 0 {
		return nil, nil, fmt.Errorf("first argument must be a requirement ID, got %q", args[0])
	}
	tags, err := model.ParseTags(args[i:])
	if err != nil {
		return nil, nil, err
	}
	return ids, tags, nil
}

func runTagAdd(cmd *cobra.Command, args []string) error {
	clear, _ := cmd.Flags().GetBool("clear")
	asJSON, _ := cmd.Flags().GetBool("json")
	flagTagInputs, _ := cmd.Flags().GetStringArray("tag")

	flagTags, err := model.ParseTags(flagTagInputs)
	if err != nil {
		return err
	}
	ids, tags, err := splitIDsAndTags(args, len(flagTags) > 0)
	if err != nil {
		return err
	}
	tags = mergeTags(flagTags, tags)

	if clear && len(tags) > 0 {
		return fmt.Errorf("--clear takes no tags")
	}
	if !clear && len(tags) == 0 {
		// All-numeric positional args are treated as IDs, so `jot tag 1 2026` ends up here.
		// Say so explicitly; otherwise the user only sees "no tags given" with no idea where the tag went.
		return fmt.Errorf("no tags given (example: jot tag %d v2.4.4); "+
			"an all-digit argument is read as a requirement ID, so pass such a tag as --tag 2026", ids[0])
	}

	s, err := openStore()
	if err != nil {
		return err
	}
	defer s.Close()

	apply := func(id int64) ([]string, error) {
		if clear {
			return s.SetTags(id, nil)
		}
		return s.AddTags(id, tags)
	}
	return applyTagOp(s, ids, apply, asJSON, cmd.OutOrStdout())
}

func newUntagCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "untag <id...> <tag...>",
		Short: "Remove tags from requirements",
		Args:  cobra.MinimumNArgs(1),
		Example: `  jot untag 42 v2.4.4
  jot untag 42 --tag 2026        # --tag takes the value literally`,
		RunE: func(cmd *cobra.Command, args []string) error {
			asJSON, _ := cmd.Flags().GetBool("json")
			flagTagInputs, _ := cmd.Flags().GetStringArray("tag")

			flagTags, err := model.ParseTags(flagTagInputs)
			if err != nil {
				return err
			}
			ids, tags, err := splitIDsAndTags(args, len(flagTags) > 0)
			if err != nil {
				return err
			}
			tags = mergeTags(flagTags, tags)
			if len(tags) == 0 {
				return fmt.Errorf("no tags given (example: jot untag %d v2.4.4); "+
					"an all-digit argument is read as a requirement ID, so pass such a tag as --tag 2026", ids[0])
			}
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			return applyTagOp(s, ids, func(id int64) ([]string, error) {
				return s.RemoveTags(id, tags)
			}, asJSON, cmd.OutOrStdout())
		},
	}
	cmd.Flags().StringArray("tag", nil, "tag to remove, taken literally (use for an all-digit tag)")
	cmd.Flags().Bool("json", false, "machine-readable output")
	return cmd
}

// mergeTags merges --tag values with positional tags, preserving order and removing duplicates.
func mergeTags(flagTags, positional []string) []string {
	if len(flagTags) == 0 {
		return positional
	}
	seen := make(map[string]bool, len(flagTags))
	out := make([]string, 0, len(flagTags)+len(positional))
	for _, t := range append(append([]string{}, flagTags...), positional...) {
		if !seen[t] {
			seen[t] = true
			out = append(out, t)
		}
	}
	return out
}

// applyTagOp runs a batch of tag operations and reports each result.
// Batch failures must be visible: return a failed list and exit non-zero so an agent doesn't
// mistake a partial failure for overall success.
func applyTagOp(s *store.Store, ids []int64, op func(int64) ([]string, error), asJSON bool, out interface{ Write([]byte) (int, error) }) error {
	var results []reqJSON
	var failed []string

	for _, id := range ids {
		tags, err := op(id)
		if err != nil {
			failed = append(failed, fmt.Sprintf("#%d: %v", id, err))
			continue
		}
		r, err := s.GetReq(id)
		if err != nil {
			failed = append(failed, fmt.Sprintf("#%d: %v", id, err))
			continue
		}
		// The frontmatter is a readable copy of the tags and must be updated too, or agents reading the file see stale values
		if err := s.SyncFrontmatter(r); err != nil {
			failed = append(failed, fmt.Sprintf("#%d: tags updated, but body sync failed: %v", id, err))
			continue
		}
		results = append(results, toReqJSON(r))
		if !asJSON {
			fmt.Fprintf(out, "%s #%d %s\n", green("✓"), id, formatTags(tags))
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
}

func formatTags(tags []string) string {
	if len(tags) == 0 {
		return dim("(no tags)")
	}
	return cyan(strings.Join(tags, " "))
}

func newTagLsCmd() *cobra.Command {
	var asJSON, all bool
	cmd := &cobra.Command{
		Use:     "ls",
		Aliases: []string{"list"},
		Short:   "List every tag in use, with how many requirements carry it",
		Long: `List every tag in use.

There is no tag registry: a tag exists exactly as long as some requirement
carries it, so this is a live view rather than a list you maintain.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			tags, err := s.ListTags(all)
			if err != nil {
				return err
			}
			if asJSON {
				out := make([]tagJSON, 0, len(tags))
				for _, t := range tags {
					out = append(out, tagJSON{Tag: t.Tag, Count: t.Count})
				}
				return writeJSON(map[string]any{"tags": out})
			}
			if len(tags) == 0 {
				fmt.Println(dim("No tags yet. Add one with: jot tag <id> v2.4.4"))
				return nil
			}
			for _, t := range tags {
				fmt.Printf("  %s %s\n", cyan(padRunes(t.Tag, 24)), dim(fmt.Sprintf("%d", t.Count)))
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	cmd.Flags().BoolVarP(&all, "all", "a", false, "count done / archived requirements too")
	return cmd
}

func newTagRenameCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:     "rename <old-tag> <new-tag>",
		Short:   "Rename a tag across every requirement",
		Long:    "Rename a tag everywhere it is used. Requirements already carrying the new tag simply keep one copy.",
		Args:    cobra.ExactArgs(2),
		Example: `  jot tag rename v2.4.4 v2.4.5`,
		RunE: func(cmd *cobra.Command, args []string) error {
			from, to := model.NormalizeTag(args[0]), model.NormalizeTag(args[1])
			if from == "" || to == "" {
				return fmt.Errorf("invalid tag name (use letters, digits, and . _ / -)")
			}
			if from == to {
				return fmt.Errorf("%q and %q are the same tag after normalization", args[0], args[1])
			}
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			ids, err := s.RenameTag(from, to)
			if err != nil {
				return err
			}
			if err := syncTagged(s, ids); err != nil {
				return err
			}
			if asJSON {
				return writeJSON(map[string]any{"from": from, "to": to, "reqs": ids})
			}
			fmt.Printf("%s %s → %s  %s\n", green("✓"), cyan(from), cyan(to),
				dim(fmt.Sprintf("(%d requirements)", len(ids))))
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

func newTagRmCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "rm <tag>",
		Short: "Remove a tag from every requirement that carries it",
		Long: `Remove a tag from every requirement.

Only the label is dropped: no requirement is deleted and nothing changes state.`,
		Args:    cobra.ExactArgs(1),
		Example: `  jot tag rm v2.4.4`,
		RunE: func(cmd *cobra.Command, args []string) error {
			tag := model.NormalizeTag(args[0])
			if tag == "" {
				return fmt.Errorf("invalid tag name (use letters, digits, and . _ / -)")
			}
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()

			ids, err := s.DeleteTag(tag)
			if err != nil {
				return err
			}
			if err := syncTagged(s, ids); err != nil {
				return err
			}
			if asJSON {
				return writeJSON(map[string]any{"tag": tag, "reqs": ids})
			}
			fmt.Printf("%s removed %s from %s\n", green("✓"), cyan(tag),
				dim(fmt.Sprintf("%d requirements", len(ids))))
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	return cmd
}

// syncTagged refreshes the frontmatter of a batch of requirements. The database is already updated, so file sync failures
// are reported, not rolled back; otherwise a bulk rename would be left half-done.
func syncTagged(s *store.Store, ids []int64) error {
	var failed []string
	for _, id := range ids {
		r, err := s.GetReq(id)
		if err != nil {
			failed = append(failed, fmt.Sprintf("#%d: %v", id, err))
			continue
		}
		if err := s.SyncFrontmatter(r); err != nil {
			failed = append(failed, fmt.Sprintf("#%d: %v", id, err))
		}
	}
	if len(failed) > 0 {
		return fmt.Errorf("tags updated, but body sync failed for %d requirement(s): %s",
			len(failed), strings.Join(failed, "; "))
	}
	return nil
}
