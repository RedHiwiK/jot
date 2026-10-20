package cli

import (
	"fmt"
	"os"
	"time"

	"golang.org/x/term"
)

// Color output: honors NO_COLOR and is disabled when stdout is not a TTY
var useColor = func() bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}
	return isTTY(os.Stdout)
}()

func isTTY(f *os.File) bool { return term.IsTerminal(int(f.Fd())) }

func color(code, s string) string {
	if !useColor {
		return s
	}
	return "\x1b[" + code + "m" + s + "\x1b[0m"
}

func dim(s string) string    { return color("2", s) }
func bold(s string) string   { return color("1", s) }
func red(s string) string    { return color("31", s) }
func green(s string) string  { return color("32", s) }
func yellow(s string) string { return color("33", s) }
func blue(s string) string   { return color("34", s) }
func cyan(s string) string   { return color("36", s) }

// humanAgo renders an elapsed duration as a phrase, e.g. "2h ago".
// "just now" already reads as a phrase, so it takes no suffix.
func humanAgo(t time.Time) string {
	s := humanAge(t)
	if s == "just now" {
		return s
	}
	return s + " ago"
}

// humanAge renders an elapsed duration compactly, e.g. "2h".
func humanAge(t time.Time) string {
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh", int(d.Hours()))
	case d < 30*24*time.Hour:
		return fmt.Sprintf("%dd", int(d.Hours()/24))
	default:
		return t.Format("01-02")
	}
}

// padRunes pads to a display width (CJK characters count as 2 columns)
func padRunes(s string, width int) string {
	w := displayWidth(s)
	if w >= width {
		return s
	}
	return s + spaces(width-w)
}

func displayWidth(s string) int {
	w := 0
	for _, r := range s {
		if r >= 0x1100 && (r <= 0x115F || r == 0x2329 || r == 0x232A ||
			(r >= 0x2E80 && r <= 0xA4CF && r != 0x303F) ||
			(r >= 0xAC00 && r <= 0xD7A3) || (r >= 0xF900 && r <= 0xFAFF) ||
			(r >= 0xFE30 && r <= 0xFE6F) || (r >= 0xFF00 && r <= 0xFF60) ||
			(r >= 0xFFE0 && r <= 0xFFE6) || (r >= 0x20000 && r <= 0x3FFFD)) {
			w += 2
		} else {
			w++
		}
	}
	return w
}

func spaces(n int) string {
	if n <= 0 {
		return ""
	}
	b := make([]byte, n)
	for i := range b {
		b[i] = ' '
	}
	return string(b)
}

// truncateDisplay truncates by display width without splitting wide characters
func truncateDisplay(s string, max int) string {
	if displayWidth(s) <= max {
		return s
	}
	w := 0
	for i, r := range s {
		rw := 1
		if displayWidth(string(r)) == 2 {
			rw = 2
		}
		if w+rw > max-1 {
			return s[:i] + "…"
		}
		w += rw
	}
	return s
}
