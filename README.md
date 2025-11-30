# Aristar Codex GUI

Aristar Codex GUI is a macOS SwiftUI app that orchestrates multiple Codex CLI agents side by side. Each agent runs in its own Git worktree plus disposable branch so you can experiment in parallel without touching your main repo. Auth is inherited from `codex login` (`~/.codex`) and status is surfaced in-app.

## Core Behaviors

- Managed worktrees live under `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/` with names like `aristar-wt-<safeBranch>-<shortid>` (legacy `agent-*` worktrees are still recognized). Each worktree gets its own agent branch created from the selected base branch and deleted when the worktree is removed.
- Managed metadata (base branch, agent branch, timestamps) is stored outside repos at `~/.aristar-codex-gui/metadata/<project-key>/<worktree>.json`.
- Deleting a managed worktree stops the session, removes the directory (retrying with `git worktree remove -f` if dirty), and deletes the agent branch. Nested managed worktrees are blocked.
- SwiftTerm provides the terminal experience over a real PTY (login `zsh`, `TERM=xterm-256color`, `COLUMNS`/`LINES` synced with resize and a 1-row safety margin). Raw escape sequences are preserved.
- App-managed worktrees only: branch panes list and act on managed worktrees; creation is blocked if the selected folder is itself a managed worktree. Missing repos or worktrees surface inline warnings.

## UI & Workflow

- **Hubs tab (Cmd+1):** Favorites/recents list with star/remove actions; selecting a project shows branches. Opening a branch pane lists managed worktrees with launch/stop/delete and “Add to working set” actions plus delete confirmation. Open panes persist via `UserDefaults`; missing/non-git projects are skipped with a banner. Removing a project deletes its managed worktrees/branches and clears it from favorites/recents, branch panes, and the working set.
- **Working Set tab (Cmd+2):** Sidebar list with status dots, project/branch badges, and inline remove; detail pane shows the selected worktree with quick actions. Removal here only unpins; the worktree stays on disk.
- **Starting Script previews (Cmd+4 for Preview tab, Cmd+3 for Agent tab):** Per-worktree services (name, root, command, optional env text, enabled toggle) run in individual SwiftTerm terminals. A temporary `.env` is written/restored for optional env text, and only one preview run per service/worktree is allowed at a time.
- Navigation uses macOS-style shortcuts; session start/stop state stays in sync across tabs and panes.

## Prerequisites

- macOS for SwiftUI/AppKit.
- Codex CLI in your `$PATH` (e.g. `/opt/homebrew/bin/codex`).
- Git for worktree and branch operations.

## Build & Run (SwiftPM; Xcode not required)

```sh
swift build
swift run AristarCodexGUI
```

The binary lives at `./.build/debug/AristarCodexGUI` (or the release folder when built with `-c release`).

## Release Automation

```sh
scripts/release.sh vX.Y.Z "Notes"
```

Builds the release binary, zips it to `AristarCodexGUI-vX.Y.Z-macOS-arm64.zip`, and creates the GitHub release via `gh release create`. Requires the `gh` CLI to be installed and authenticated.

## Testing

`swift test` runs unit and integration coverage, including the preview path resolver and managed worktree lifecycle in a temporary git repo.

## Known Gaps

- No settings UI for Codex binary path/profile; binary is auto-resolved.
- Custom fonts are not bundled; rounded system fonts are used until fonts are added.
- SwiftTerm README warning is harmless but still appears.

## Documentation Discipline

DOCUMENTATION.md is the single source of truth for behaviors, storage paths, and UI flows. Update it (and this README) when core behavior changes so future contributors have one reliable reference.
