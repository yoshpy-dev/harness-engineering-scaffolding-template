// Package deps ensures go.mod retains all dependencies needed by other slices.
// This file is imported by no one; it exists only to prevent `go mod tidy`
// from removing dependencies that downstream slices (2-6) will use.
// Remove this file once all slices are integrated.
package deps

import (
	_ "charm.land/bubbles/v2/viewport"
	_ "charm.land/bubbletea/v2"
	_ "charm.land/lipgloss/v2"
	_ "github.com/fsnotify/fsnotify"
)
