package state

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// ReadOrchestratorState reads and parses orchestrator.json from the given directory.
func ReadOrchestratorState(orchDir string) (*OrchestratorState, error) {
	path := filepath.Join(orchDir, "orchestrator.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading orchestrator.json: %w", err)
	}
	var s OrchestratorState
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, fmt.Errorf("parsing orchestrator.json: %w", err)
	}
	return &s, nil
}

// ReadSliceStatus reads a slice-<name>.status file and returns its content as a string.
func ReadSliceStatus(orchDir, sliceName string) (string, error) {
	path := filepath.Join(orchDir, fmt.Sprintf("slice-%s.status", sliceName))
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("reading slice status for %s: %w", sliceName, err)
	}
	return strings.TrimSpace(string(data)), nil
}

// ReadPipelineCheckpoint reads checkpoint.json from a worktree's .harness/state/pipeline/ directory.
func ReadPipelineCheckpoint(worktreeBase, sliceName string) (*PipelineCheckpoint, error) {
	path := filepath.Join(worktreeBase, sliceName, ".harness", "state", "pipeline", "checkpoint.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading checkpoint for %s: %w", sliceName, err)
	}
	var c PipelineCheckpoint
	if err := json.Unmarshal(data, &c); err != nil {
		return nil, fmt.Errorf("parsing checkpoint for %s: %w", sliceName, err)
	}
	return &c, nil
}

// depsLineRe matches lines like "slice-1 (foundation) ──→ slice-2 (watcher)"
// or "slice-2, slice-4, slice-5 ──→ slice-6 (integration)"
var depsLineRe = regexp.MustCompile(`^(.+?)\s*──→\s*(.+)$`)

// sliceNameRe extracts the slice number from patterns like "slice-1 (foundation)" or "slice-1"
var sliceNameRe = regexp.MustCompile(`(slice-\d+)`)

// ReadSliceDependencies parses the dependency graph from a manifest file.
// It looks for lines matching "slice-X ──→ slice-Y" in the ## Dependency graph section.
func ReadSliceDependencies(planDir string) ([]SliceDependency, error) {
	manifestPath := filepath.Join(planDir, "_manifest.md")
	f, err := os.Open(manifestPath)
	if err != nil {
		return nil, fmt.Errorf("opening manifest: %w", err)
	}
	defer func() { _ = f.Close() }()

	var deps []SliceDependency
	inDepsSection := false
	scanner := bufio.NewScanner(f)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		// Detect section boundaries
		if strings.HasPrefix(line, "## Dependency graph") {
			inDepsSection = true
			continue
		}
		if inDepsSection && strings.HasPrefix(line, "## ") {
			break
		}
		if !inDepsSection {
			continue
		}

		// Skip empty lines and code fences
		if line == "" || line == "```" {
			continue
		}

		matches := depsLineRe.FindStringSubmatch(line)
		if matches == nil {
			continue
		}

		leftPart := matches[1]
		rightPart := matches[2]

		// Extract target slice(s) from right side
		toSlices := sliceNameRe.FindAllString(rightPart, -1)
		if len(toSlices) == 0 {
			continue
		}

		// Extract source slice(s) from left side
		fromSlices := sliceNameRe.FindAllString(leftPart, -1)
		if len(fromSlices) == 0 {
			continue
		}

		// Each "from" connects to each "to"
		for _, from := range fromSlices {
			for _, to := range toSlices {
				deps = append(deps, SliceDependency{From: from, To: to})
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scanning manifest: %w", err)
	}

	return deps, nil
}

// ListSliceNames returns the slice names found from slice-*.status files in orchDir.
func ListSliceNames(orchDir string) ([]string, error) {
	pattern := filepath.Join(orchDir, "slice-*.status")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return nil, fmt.Errorf("globbing slice status files: %w", err)
	}
	var names []string
	for _, m := range matches {
		base := filepath.Base(m)
		name := strings.TrimPrefix(base, "slice-")
		name = strings.TrimSuffix(name, ".status")
		names = append(names, name)
	}
	return names, nil
}

// ReadFullStatus reads all state files and assembles a FullStatus.
func ReadFullStatus(orchDir, worktreeBase, planDir string) (*FullStatus, error) {
	orch, err := ReadOrchestratorState(orchDir)
	if err != nil {
		return nil, err
	}

	sliceNames, err := ListSliceNames(orchDir)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	var slices []SliceState
	completed := 0

	for _, name := range sliceNames {
		status, err := ReadSliceStatus(orchDir, name)
		if err != nil {
			status = "unknown"
		}

		ss := SliceState{
			Name:   name,
			Status: status,
			Phase:  "unknown",
		}

		checkpoint, err := ReadPipelineCheckpoint(worktreeBase, name)
		if err == nil {
			ss.Checkpoint = checkpoint
			ss.Phase = checkpoint.Phase
			ss.InnerCycle = checkpoint.InnerCycle
			if checkpoint.LastTestResult != nil {
				ss.TestResult = *checkpoint.LastTestResult
			}
			if checkpoint.PRUrl != nil {
				ss.PRUrl = *checkpoint.PRUrl
			}

			if t, err := checkpoint.FirstTransitionTime(); err == nil && !t.IsZero() {
				ss.ElapsedSecs = int64(now.Sub(t).Seconds())
			}
		} else {
			// No checkpoint — derive phase from status
			if status == "pending" {
				ss.Phase = "waiting"
			}
		}

		if status == "complete" {
			completed++
		}

		slices = append(slices, ss)
	}

	deps, _ := ReadSliceDependencies(planDir) // non-fatal if missing

	total := len(slices)
	pct := 0
	if total > 0 {
		pct = (completed * 100) / total
	}

	return &FullStatus{
		Orchestrator: orch,
		Slices:       slices,
		Dependencies: deps,
		Progress: Progress{
			Completed: completed,
			Total:     total,
			Percent:   pct,
		},
	}, nil
}
