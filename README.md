# Aristar Codex GUI

Aristar Codex GUI is a macOS SwiftUI app for developers who juggle multiple Codex agents at once. It makes “spin up another agent” safe and repeatable: every agent gets its own Git worktree and disposable branch so you can trial changes side by side without touching the mainline. Auth comes from `codex login` (`~/.codex`) and status is shown in-app so you know when you are ready to launch.

## Why developers use it

- Experiment freely: each agent lives in a managed worktree/branch under `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/` named `aristar-wt-<safeBranch>-<shortid>` (legacy `agent-*` still recognized).
- Keep your repo tidy: deleting a managed worktree stops the session, removes the directory (retries with `git worktree remove -f` if dirty), and deletes the agent branch. Nested managed worktrees are blocked.
- Visible guardrails: branch panes only show app-managed worktrees; missing repos/worktrees surface inline warnings instead of surprising errors.
- Real terminal behavior: SwiftTerm PTY (login `zsh`, `TERM=xterm-256color`, `COLUMNS`/`LINES` synced, 1-row safety margin) keeps raw escape sequences intact so Codex output looks right.
- Metadata out of the way: base branch/agent branch/timestamps/display name live at `~/.aristar-codex-gui/metadata/<project-key>/<worktree>.json`, not in your repo.

## UI & workflow (developer-focused)

- **Hubs tab (Cmd+1):** Favorites/recents list with star/remove. Opening a branch pane lists managed worktrees with launch/stop/delete, inline rename (alias only), and “Add to working set.” Delete confirmations prevent accidental cleanup. Open panes persist via `UserDefaults`; missing/non-git projects are skipped with a banner. Removing a project deletes its managed worktrees/branches and clears it from favorites/recents, branch panes, and the working set.
- **Working Set tab (Cmd+2):** Sidebar with status dots plus project/branch badges; detail pane exposes quick actions. Items can be renamed inline (alias-only; folder/agent branch stay the same). Removing an item only unpins it (worktree stays on disk).
- **Starting Script previews (Cmd+4 for Preview tab, Cmd+3 for Agent tab):** Per-worktree services (name, root, command, optional env text, enabled toggle) run in individual SwiftTerm terminals. Optional env text writes/restores a temporary `.env`; only one preview run per service/worktree at a time.
- macOS-style shortcuts and synchronized session start/stop keep UI state aligned with running agents.

## Prerequisites

- macOS for SwiftUI/AppKit.
- Codex CLI in your `$PATH` (e.g. `/opt/homebrew/bin/codex`).
- Git for worktree and branch operations.

## Build & run (SwiftPM; Xcode not required)

```sh
swift build
swift run AristarCodexGUI
```

Binary is at `./.build/debug/AristarCodexGUI` (or release via `-c release`).

## Release automation

```sh
scripts/release.sh vX.Y.Z "Notes"
```

Builds the release binary, zips it to `AristarCodexGUI-vX.Y.Z-macOS-arm64.zip`, and creates the GitHub release via `gh release create`. Requires the `gh` CLI installed and authenticated.

## Testing

`swift test` covers unit + integration scenarios, including preview path resolution and managed worktree lifecycle in a temp git repo.

## Known gaps

- No settings UI for Codex binary path/profile; binary is auto-resolved.
- Custom fonts not bundled; rounded system fonts are used until fonts are added.
- SwiftTerm README warning is harmless but still appears.

## Documentation discipline

DOCUMENTATION.md is the single source of truth for behaviors, storage paths, and UI flows. Update it (and this README) when core behavior changes so future contributors have one reliable reference.
