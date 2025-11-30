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

## Release automation
- `scripts/release.sh vX.Y.Z "Notes"` builds the release binary, zips it to `AristarCodexGUI-vX.Y.Z-macOS-arm64.zip`, and uses `gh release create` to create the GitHub release (tag is created on GitHub as part of the release).
- `gh` CLI is required; the script exits early with a warning if it is missing or not authenticated (`gh auth status`).

## Key flows
1) Auth: `CodexAuthManager` wraps `codex login/status`. Status drives the “Codex: Connected” banner. No tokens handled in-app.
2) Project hub: macOS UI now splits into tabs. The Hubs tab shows favorites and recents (multi-project), lets you select a project to view its branches, and opens branch panes (toggled by clicking branches) for managed worktrees on that branch. Only app-managed worktrees are listed; panes show lists with actions and confirmation on delete (no inline detail/terminal).
3) Favorites/recents: favorites are user-pinned projects (persisted via `ProjectListStore`), recents track the most recently selected projects. Both are shown in the Project column.
4) Branch panes: each pane belongs to a project/branch and lists managed worktrees with launch/stop/delete and “Add to working set” actions. Items already in the working set are visually distinguished.
5) Working Set tab: split layout with a left sidebar list (running status dot, project/branch badges, inline remove) and a right detail pane for the selected worktree. Items include status and quick actions (start/stop/open path). Removal from the working set does not delete the worktree.
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
- `PreviewServiceSession.swift`, `PreviewTerminalContainer.swift` – per-service preview processes + SwiftTerm bridges for Starting Script.
- `BrandStyle.swift` – design tokens (colors, radii, typography helpers, button styles) shared across views.
- `ProjectStateStore.swift` – per-project persistence for base branch + selected worktree.
- `RecentProjectStore.swift` – persistence helper for last opened project path.
- `HubModels.swift` – data models for projects, branch panes, working-set items, tab selection.
- `ProjectListStore.swift` – persistence for favorites/recents.
- `WorkingSetStore.swift` – persistence for working worktrees.
- `PreviewServiceSession.swift`, `PreviewTerminalContainer.swift` – per-service preview processes + SwiftTerm bridges for Starting Script.

## Behavioral details
- Worktree root per project: `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/…`.
- Managed worktree/branch name: `aristar-wt-<safeBranch>-<shortid>`; created from selected base branch/start point. Deleted when the worktree is removed. Legacy `agent-*` worktrees/branches are still recognized for cleanup. Worktree deletion will retry with `git worktree remove -f` when the worktree is dirty.
- Worktree metadata: stored outside the worktree at `~/.aristar-codex-gui/metadata/<project-key>/<worktree>.json` (base branch, agent branch, created date, display name/alias). Display names are a UI-only alias; the worktree folder/agent branch names remain unchanged.
- Recent projects: `ProjectListStore` keeps an ordered list of recent project paths; favorites are stored separately and pinned. Legacy `RecentProjectStore` is still present for backward compatibility but the UI now relies on the favorites/recents lists.
- Branch panes: only app-managed worktrees are listed for a project/branch. Worktree creation is blocked if the selected project is itself a managed worktree (nested worktree guard).
- Cleanup: deleting a worktree removes its directory (if under the managed root) and deletes the agent branch; stopping an agent no longer removes the worktree.
- Nested worktrees are blocked: if the opened folder lives under the managed worktrees root, creating additional worktrees is disabled (depth capped at 1).
- Session updates: `AppModel` observes `CodexSessionManager` so session start/stop state (including the Working Set terminal) stays in sync across views.
- Session persistence: removed; “Resume” runs `codex resume` in the worktree without storing session history.
- Terminal: SwiftTerm connected to PTY master; TERM set to `xterm-256color`; raw escape sequences are passed through to SwiftTerm; session start is deferred until the view has a real size so the PTY is created with the correct cols/rows (also exported via `COLUMNS`/`LINES`), and subsequent resizes update the PTY size with SIGWINCH; a 1-row safety margin is applied (report rows-1 to the PTY) to avoid bottom-edge clipping; sessions launch a login `zsh` that runs the Codex command then execs into an interactive shell.
- Selection: Hubs tab shows project lists and branch panes; each pane lists managed worktrees for a branch with per-row actions and delete confirmation. Working Set tab uses a sidebar list + detail pane to manage pinned worktrees across projects.
- Navigation: Cmd+1 switches to Hubs; Cmd+2 switches to Working Set.
- Error surfacing: worktree creation errors and missing persisted worktrees surface inline; codex binary missing errors surfaced via auth status.
- Visual language: dark “Ink” base with “Midnight” panels, “Ion” accents/CTAs, rounded pills/cards, and a custom SwiftTerm theme (Ink background, Flour text, Ion cursor, Icing selection). Shared button styles (primary/ghost/danger) and pills live in `BrandStyle.swift`; current styling uses minimal/no glow and softer borders/fills for selection states.
- Hubs sidebar matches the Working Set “inbox” list: project rows show a status dot, project name/path, star toggle (favorites), and delete action; selected rows highlight with a leading Ion bar. Project count is shown as a pill in the header.
- Favorites are removed from recents; removing a favorite re-adds it to recents. A “Remove project” action deletes all Aristar-managed worktrees/branches for that project and clears it from favorites/recents, branch panes, and working set.
- Starting Script previews live in the Working Set detail’s “Preview” tab (Cmd+4; Agent tab Cmd+3): per-worktree services store name, root (relative to worktree; empty means worktree root), command, optional env text, and enabled toggle. Services can be started/stopped individually or via a single Start Preview/Stop All toggle; each service runs in its own SwiftTerm terminal. Optional env text writes a temporary `.env` into the service root (backing up any existing `.env`), then removes/restores on stop/exit. Only one preview run per service/worktree is allowed at a time.
- Starting Script previews live in the Working Set detail’s “Preview” tab: per-worktree services (name, root dir, command, optional env text, enabled toggle) are stored in worktree metadata; “Start preview” launches all enabled services, and each service can be started/stopped individually. Each service runs in its own SwiftTerm terminal (split grid), and only one instance per service/worktree runs at a time. Optional env text is written to a `.env` file in the service root (backing up any existing `.env`), then removed/restored on stop/exit.

## Known gaps / TODOs
- ANSI/OSC passthrough is delegated to SwiftTerm.
- No settings UI for Codex binary path or profile; binary auto-resolve only.
- Custom font files are not bundled; UI uses rounded system fonts tuned to the brand until fonts are added.
- SwiftTerm warning about README resource is harmless; could be excluded if desired.

## Validation
- Favorites/recents load on launch; selecting a project lists its branches when it is a git repo.
- Opening a branch pane lists managed worktrees for that branch; creation respects nested-worktree blocking.
- Adding a worktree to the Working Set reflects immediately; removal updates persistence.
- Launch/stop from branch panes and Working Set act on the correct project/branch and reflect running status.
- Starting Script: services persist per worktree, “Start preview” starts all enabled services, per-service start/stop works, and `.env` files are cleaned up/restored after stop.
- Deleting a worktree stops its agent (if running), removes the worktree directory, and deletes the agent branch; missing worktree paths surface an inline warning.
- Brand theme renders correctly (Ink/Midnight surfaces, Ion accents, custom SwiftTerm colors).
- Worktrees can be renamed inline from branch-pane rows, the Working Set sidebar, and the Working Set detail header. Renames trim whitespace, reject empty names, and persist the alias to metadata/working-set storage without changing the folder or agent branch names.
- `swift test` runs unit + integration coverage:
  - Preview path resolver (empty/relative/absolute root cases).
  - Worktree integration in a temp git repo (create/delete managed worktree).

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
