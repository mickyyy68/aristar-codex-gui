# Aristar Codex GUI – Knowledge Base

## What this app does
- macOS SwiftUI app that launches multiple Codex CLI agents, each isolated to its own Git worktree (or plain directory).
- Worktrees live under `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/agent-<n>-<branch>-<id>`.
- Per-agent branches are created from the chosen branch to avoid Git worktree collisions; they are deleted on agent removal.
- Auth is reused from `codex login` (CLI stores creds in `~/.codex`). App checks status and launches Codex with inherited env.
- Terminal UI uses SwiftTerm; Codex runs inside a PTY for full TUI behavior.

## Build & run (no Xcode required)
- `swift build`
- `swift run AristarCodexGUI`
- Binary lives at `./.build/debug/AristarCodexGUI` (or `./.build/release/AristarCodexGUI`).
- Requires Codex CLI installed (`/opt/homebrew/bin/codex` etc.). App auto-resolves path via `$PATH` and common locations.

## Key flows
1) Auth: `CodexAuthManager` wraps `codex login/status`. Status drives the “Codex: Connected” banner. No tokens handled in-app.
2) Project open: choose folder via `NSOpenPanel`. `GitService.detectRepo` stores git info; branches are listed for the picker. Last opened folder path is persisted in `UserDefaults` for auto-restore.
3) Recent project restore: `RecentProjectStore` loads the saved path on launch; `AppModel` auto-opens it when the folder still exists. A “Reopen Last Project” button sits next to the folder picker when a stored path is available.
4) Branch-first workflow: pick a base branch, then view managed worktrees for that branch (only those created by the app under the project’s worktrees root). Worktree selection and base-branch choice are persisted per project.
5) Worktree + agent creation:
   - New worktree: creates a unique worktree + agent branch (e.g., `agent-main-<id>`) under the worktrees root using the selected base branch; metadata is stored alongside.
   - Agent launch: select a worktree, then launch/stop an agent bound to that worktree. Sessions run in the worktree directory using the agent branch.
6) Agent UI: left list shows the base-branch picker and the worktree list with status dots; detail pane shows metadata (path, agent branch, created date) plus controls to launch/stop/delete the worktree. SwiftTerm renders Codex TUI in the detail view when running.
   - Branch picker now lives in the header as a small toolbar chip (separate from the worktree list); the sidebar hosts only the worktree panel with toolbar buttons (Reload/New/Delete) plus card rows showing running/stopped pills, branch badges, and copy-path control. Nested-worktree blocking still surfaces in the worktree panel banner.
7) Deletion: deleting a worktree removes its session (if running), the worktree folder, and the agent branch.

## Source map
- `Package.swift` – SwiftPM config; pulls SwiftTerm.
- `Sources/AristarCodexGUI/AristarCodexGUIApp.swift` – app entry; activates NSApp for CLI launch.
- `CodexAuthManager.swift` – auth status/login, binary resolution.
- `GitService.swift` – git helpers (detect repo, list branches, add/remove worktrees, delete branch).
- `CodexSession.swift` – per-agent process + PTY plumbing; tracks original/agent branch.
- `CodexSessionManager.swift` – orchestrates sessions, worktree roots, cleanup, selected session, managed worktrees.
- `AppModel.swift` – top-level state (project, branches, auth, recent project restore, base branch/worktree selection).
- `ContentView.swift` – layout, branch/worktree workflow UI, worktree metadata/controls, auto-restore task + reopen button.
- `TerminalContainer.swift` – SwiftTerm bridge (`NSViewRepresentable`).
- `CodexSessionView.swift` – session detail with terminal.
- `FolderPickerButton.swift`, `BranchCreationView.swift` – UI components.
- `ManagedWorktree.swift` – models worktree metadata for UI.
- `ProjectStateStore.swift` – per-project persistence for base branch + selected worktree.
- `RecentProjectStore.swift` – persistence helper for last opened project path.

## Behavioral details
- Worktree root per project: `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/…`.
- Managed worktree/branch name: `aristar-wt-<safeBranch>-<shortid>`; created from selected base branch/start point. Deleted when the worktree is removed. Legacy `agent-*` worktrees/branches are still recognized for cleanup. Worktree deletion will retry with `git worktree remove -f` when the worktree is dirty.
- Worktree metadata: `.codex-worktree.json` stores base branch, agent branch, and created date; used to rebuild the worktree list. Legacy worktrees fall back to name-based inference.
- Recent project: last opened folder path is saved to `UserDefaults` (`RecentProjectStore`). On launch, `AppModel` attempts to reopen it; failures clear the stored path and surface a banner so the user can pick manually.
- Base branch + worktree persistence: per-project `ProjectStateStore` keeps the last base branch and selected worktree path. Missing worktrees are detected and surfaced.
- Cleanup: deleting a worktree removes its directory (if under the managed root) and deletes the agent branch; stopping an agent no longer removes the worktree.
- Nested worktrees are blocked: if the opened folder lives under the managed worktrees root, creating additional worktrees is disabled (depth capped at 1).
- Terminal: SwiftTerm connected to PTY master; TERM set to `xterm-256color`; raw escape sequences are passed through to SwiftTerm.
- Selection: `NavigationSplitView` with base-branch picker and worktree list; detail pane shows metadata and session.
- Error surfacing: worktree creation errors and missing persisted worktrees surface inline; codex binary missing errors surfaced via auth status.

## Known gaps / TODOs
- ANSI/OSC passthrough is delegated to SwiftTerm; no custom color theme yet.
- No settings UI for Codex binary path or profile; binary auto-resolve only.
- No resize/cols-rows sync back to Codex; SwiftTerm handles display internally.
- SwiftTerm warning about README resource is harmless; could be excluded if desired.

## Validation
- Fresh launch with a previously opened project reopens it automatically (sessions list populated).
- If the saved folder is missing/unreadable, the app surfaces a banner, clears the stored path, and stays on the empty state.
- “Reopen Last Project” button next to the folder picker launches the stored project when present.
- Base-branch selection persists per project; reopening restores the last branch and selected worktree when present.
- Creating a new worktree from a base branch writes metadata, shows up in the worktree list, and allows launching/stopping an agent.
- Deleting a worktree stops its agent (if running), removes the worktree directory, and deletes the agent branch; missing worktree paths surface an inline warning.

## Safe changes & guidelines
- Preserve cleanup semantics: when removing an agent with a worktree, delete both worktree dir and agent branch.
- Keep worktree root under `~/.aristar-codex-gui/worktrees` unless intentionally changing storage.
- Avoid stripping terminal output; SwiftTerm expects raw PTY data.
- If switching to structured Codex output, prefer `codex exec --json` and new views rather than hacking the PTY stream.

## Documentation discipline
- Treat this file as the single source of truth for the codebase. After any meaningful change (features, bug fixes, behavior shifts, paths, commands, UI affordances), update this document to reflect:
  - What changed and where (relevant types/files).
  - Any new behavior, defaults, or storage locations.
  - New limitations or TODOs added/removed.
- Do this before concluding the work to keep future contributors (human or AI) aligned.
