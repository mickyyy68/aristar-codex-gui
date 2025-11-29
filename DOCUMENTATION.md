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
2) Project hub: macOS UI now splits into tabs. The Hubs tab shows favorites and recents (multi-project), lets you select a project to view its branches, and opens branch panes (toggled by clicking branches) for managed worktrees on that branch. Only app-managed worktrees are listed; panes show lists with actions and confirmation on delete (no inline detail/terminal).
3) Favorites/recents: favorites are user-pinned projects (persisted via `ProjectListStore`), recents track the most recently selected projects. Both are shown in the Project column.
4) Branch panes: each pane belongs to a project/branch and lists managed worktrees with launch/stop/delete and “Add to working set” actions. Items already in the working set are visually distinguished.
5) Working Set tab: split layout with a left sidebar list (running status dot, project/branch badges, inline remove) and a right detail pane for the selected worktree. Items include status and quick actions (launch/stop/delete/open path) and persist via `WorkingSetStore`. Removal from the working set does not delete the worktree.
6) Worktree + agent creation: still uses the managed worktree pattern (`aristar-wt-<safeBranch>-<shortid>` from the selected branch); metadata is stored alongside. Agent launch/stop uses branch-pane and working-set controls.
7) Deletion: deleting a worktree removes its session (if running), the worktree folder, and the agent branch.
8) Branch pane persistence: open branch panes (project + branch + selected worktree) persist to `UserDefaults` and restore on launch. Missing/non-git projects are skipped and surfaced via a banner.

## Source map
- `Package.swift` – SwiftPM config; pulls SwiftTerm.
- `Sources/AristarCodexGUI/AristarCodexGUIApp.swift` – app entry; activates NSApp for CLI launch.
- `CodexAuthManager.swift` – auth status/login, binary resolution.
- `GitService.swift` – git helpers (detect repo, list branches, add/remove worktrees, delete branch).
- `CodexSession.swift` – per-agent process + PTY plumbing; tracks original/agent branch.
- `CodexSessionManager.swift` – orchestrates sessions, worktree roots, cleanup, selected session, managed worktrees.
- `AppModel.swift` – top-level state (projects hub, branch panes, working set, auth).
- `ContentView.swift` – layout with Hubs/Working Set tabs, project favorites/recents, branch panes, working-set view.
- `TerminalContainer.swift` – SwiftTerm bridge (`NSViewRepresentable`).
- `CodexSessionView.swift` – session detail with terminal.
- `FolderPickerButton.swift`, `BranchCreationView.swift` – UI components.
- `ManagedWorktree.swift` – models worktree metadata for UI.
- `ProjectStateStore.swift` – per-project persistence for base branch + selected worktree.
- `RecentProjectStore.swift` – persistence helper for last opened project path.
- `HubModels.swift` – data models for projects, branch panes, working-set items, tab selection.
- `ProjectListStore.swift` – persistence for favorites/recents.
- `WorkingSetStore.swift` – persistence for working worktrees.

## Behavioral details
- Worktree root per project: `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/…`.
- Managed worktree/branch name: `aristar-wt-<safeBranch>-<shortid>`; created from selected base branch/start point. Deleted when the worktree is removed. Legacy `agent-*` worktrees/branches are still recognized for cleanup. Worktree deletion will retry with `git worktree remove -f` when the worktree is dirty.
- Worktree metadata: `.codex-worktree.json` stores base branch, agent branch, and created date; used to rebuild the worktree list. Legacy worktrees fall back to name-based inference.
- Recent projects: `ProjectListStore` keeps an ordered list of recent project paths; favorites are stored separately and pinned. Legacy `RecentProjectStore` is still present for backward compatibility but the UI now relies on the favorites/recents lists.
- Branch panes: only app-managed worktrees are listed for a project/branch. Worktree creation is blocked if the selected project is itself a managed worktree (nested worktree guard).
- Cleanup: deleting a worktree removes its directory (if under the managed root) and deletes the agent branch; stopping an agent no longer removes the worktree.
- Nested worktrees are blocked: if the opened folder lives under the managed worktrees root, creating additional worktrees is disabled (depth capped at 1).
- Session updates: `AppModel` observes `CodexSessionManager` so session start/stop state (including the Working Set terminal) stays in sync across views.
- Terminal: SwiftTerm connected to PTY master; TERM set to `xterm-256color`; raw escape sequences are passed through to SwiftTerm.
- Selection: Hubs tab shows project lists and branch panes; each pane lists managed worktrees for a branch with per-row actions and delete confirmation. Working Set tab uses a sidebar list + detail pane to manage pinned worktrees across projects.
- Navigation: Cmd+1 switches to Hubs; Cmd+2 switches to Working Set.
- Error surfacing: worktree creation errors and missing persisted worktrees surface inline; codex binary missing errors surfaced via auth status.

## Known gaps / TODOs
- ANSI/OSC passthrough is delegated to SwiftTerm; no custom color theme yet.
- No settings UI for Codex binary path or profile; binary auto-resolve only.
- No resize/cols-rows sync back to Codex; SwiftTerm handles display internally.
- SwiftTerm warning about README resource is harmless; could be excluded if desired.

## Validation
- Favorites/recents load on launch; selecting a project lists its branches when it is a git repo.
- Opening a branch pane lists managed worktrees for that branch; creation respects nested-worktree blocking.
- Adding a worktree to the Working Set reflects immediately; removal updates persistence.
- Launch/stop from branch panes and Working Set act on the correct project/branch and reflect running status.
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
