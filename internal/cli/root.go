// Package cli implements the jot subcommands.
package cli

import (
	"fmt"
	"os"

	"github.com/RedHiwiK/jot/internal/store"
	"github.com/spf13/cobra"
)

var Version = "0.1.0"

func NewRootCmd() *cobra.Command {
	root := &cobra.Command{
		Use:   "jot",
		Short: "Jot — a lightweight personal requirements board",
		Long: `Jot — a lightweight personal requirements board.
Capture, triage, and query requirements from the CLI or a skill; progress is maintained by hand.`,
		SilenceUsage:  true,
		SilenceErrors: true,
		Version:       Version,
	}

	root.AddCommand(
		newInitCmd(), newAddCmd(), newLsCmd(), newShowCmd(),
		newEditCmd(), newSetCmd(), newMvCmd(),
		newRmCmd(), newPurgeCmd(), newPathCmd(), newSyncCmd(), newTriageCmd(), newProjectCmd(),
		newBodyCmd(), newConfigCmd(), newTagCmd(), newUntagCmd(),
		newLinkCmd(), newUnlinkCmd(),
	)
	return root
}

// openStore opens the database and gives clear guidance when it is not initialized.
func openStore() (*store.Store, error) {
	if !store.Exists() {
		return nil, fmt.Errorf("not initialized yet; run: jot init")
	}
	return store.Open()
}

func Execute() {
	if err := NewRootCmd().Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
