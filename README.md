# Aristar Codex GUI

Aristar Codex GUI is a macOS SwiftUI application that acts as a graphical orchestration layer for the Codex CLI. It lets you launch multiple Codex agents simultaneously while isolating each one in its own Git worktree, enabling parallel experimentation without conflicting with your main repository or other agents.

## Key Features

- **Worktree Isolation:** Agents run in dedicated Git worktrees located at `~/.aristar-codex-gui/worktrees/`, leaving your main folder untouched.
- **Automated Branch Management:** Disposable `aristar-wt-<safeBranch>-<id>` branches prevent collisions and are cleaned up when the agent is deleted.
- **Full Terminal Experience:** SwiftTerm provides a fully functional TUI; Codex runs inside a real PTY with raw escape sequences and interactivity.
- **Working Set Workflow:** Pin active worktrees to the Working Set tab to monitor status, start/stop agents, and access them quickly.
- **Project Hub:** Browse favorite projects, view branches, and manage worktrees via Branch Panes.
- **Seamless Auth:** Inherits CLI authentication (`~/.codex`); no separate login is required in the app.

## Prerequisites

- **macOS:** Required for SwiftUI and AppKit support.
- **Codex CLI:** Must be installed and accessible in your `$PATH` (e.g. `/opt/homebrew/bin/codex`).
- **Git:** Required for worktree and branch operations.

## Build & Run

_No Xcode install is strictly required; Swift Package Manager builds the app directly._

### 1. Build

```sh
swift build
```

### 2. Run

```sh
swift run AristarCodexGUI
```

The binary lives at `./.build/debug/AristarCodexGUI` (or the release folder if built with release configuration).

## Usage Guide

### Navigation

- `Cmd+1`: Switch to Hubs (Projects & Branch Panes).
- `Cmd+2`: Switch to Working Set (Active Agents).

### The Hubs Tab

- **Favorites & Recents:** Manage the projects you use most.
- **Branch Panes:** Select a project, click a branch, and open a pane that lists all worktrees managed for that branch.
- **Create Agent:** From a branch pane, spawn an isolated worktree, which creates a new folder and unique branch.

### The Working Set

- **Focus Mode:** Pin worktrees from the Hub to the Working Set to track them across projects.
- **Controls:** Start, stop, or open the folder for any agent.
- **Removal:** Removing an entry from the Working Set only unpins it; the worktree remains on disk.

## Deletion & Cleanup

- **Delete Worktree:** Triggered via Branch Panes.
  - Stops the agent session (if running).
  - Removes the worktree directory.
  - Deletes the associated `aristar-wt-...` Git branch.

## Documentation Discipline

This project adheres to a strict “Knowledge Base” discipline. If you alter core behaviors, storage paths, or UI flows, update the Knowledge Base (or this README) so future contributors—human or AI—have one reliable source of truth for the codebase’s operational logic.
