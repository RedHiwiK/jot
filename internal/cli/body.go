package cli

import (
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/spf13/cobra"
)

// body lets the GUI read and write the markdown body directly, without an external editor.
func newBodyCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "body <id>",
		Short: "Print a requirement body (frontmatter stripped)",
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
			body, err := s.ReadBody(r)
			if err != nil {
				return err
			}
			fmt.Print(stripFrontmatter(body))
			return nil
		},
	}
	cmd.AddCommand(newBodySetCmd())
	return cmd
}

func newBodySetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "set <id>",
		Short: "Replace a requirement body from stdin (frontmatter is preserved)",
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

			newBody, err := io.ReadAll(os.Stdin)
			if err != nil {
				return err
			}

			return s.SetBody(r, string(newBody))
		},
	}
}

func extractFrontmatter(s string) string {
	if !strings.HasPrefix(s, "---\n") {
		return ""
	}
	if i := strings.Index(s[4:], "\n---\n"); i >= 0 {
		return s[:4+i+5]
	}
	return ""
}
