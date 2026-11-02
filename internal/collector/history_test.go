package collector

import (
	"os"
	"path/filepath"
	"testing"
)

// TestHistoryDirHonoursDataDirEnv guards the 2026-10-19 fix (bead
// nightforge-aaj): health snapshots must land in a directory that exists.
// The path used to be hardcoded to $HOME/Github/nightforge/data/history,
// and ~/Github does not exist on this workstation, so every snapshot was
// written into a tree that was never read back.
//
// The env var must be read per call, not at package init — resolving it once
// at init makes the override silently ineffective.
func TestHistoryDirHonoursDataDirEnv(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("NIGHTFORGE_DATA_DIR", dir)

	want := filepath.Join(dir, "history")
	if got := historyDir(); got != want {
		t.Errorf("historyDir() = %q, want %q", got, want)
	}
}

// TestHistoryDirDefaultFallback pins the fallback used when
// NIGHTFORGE_DATA_DIR is unset: $HOME/nightforge/data/history, matching the
// convention the shell scripts in scripts/harness/ already use.
func TestHistoryDirDefaultFallback(t *testing.T) {
	t.Setenv("NIGHTFORGE_DATA_DIR", "")

	home, err := os.UserHomeDir()
	if err != nil {
		t.Skipf("no home directory: %v", err)
	}
	want := filepath.Join(home, "nightforge", "data", "history")
	if got := historyDir(); got != want {
		t.Errorf("historyDir() = %q, want %q", got, want)
	}
}
