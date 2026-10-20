package cli

import (
	"fmt"

	"github.com/RedHiwiK/jot/internal/store"
	"github.com/spf13/cobra"
)

func newConfigCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "config", Aliases: []string{"cfg"}, Short: "Configure the requirement body editor"}
	var asJSON bool
	list := &cobra.Command{
		Use: "ls", Aliases: []string{"list"}, Short: "Show the editor configuration",
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()
			if asJSON {
				return writeJSON(s.AllConfig())
			}
			fmt.Printf("editor = %s\n", s.GetConfig(store.KeyEditor))
			return nil
		},
	}
	list.Flags().BoolVar(&asJSON, "json", false, "machine-readable output")
	get := &cobra.Command{
		Use: "get <key>", Short: "Read a setting (editor)", Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if args[0] != store.KeyEditor {
				return fmt.Errorf("unknown setting %q (available: editor)", args[0])
			}
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()
			fmt.Println(s.GetConfig(args[0]))
			return nil
		},
	}
	set := &cobra.Command{
		Use: "set <key> <value>", Short: "Set the editor",
		Example: "  jot config set editor nano", Args: cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := openStore()
			if err != nil {
				return err
			}
			defer s.Close()
			if err := s.SetConfig(args[0], args[1]); err != nil {
				return err
			}
			fmt.Printf("✓ %s = %s\n", args[0], args[1])
			return nil
		},
	}
	cmd.AddCommand(list, get, set)
	return cmd
}
