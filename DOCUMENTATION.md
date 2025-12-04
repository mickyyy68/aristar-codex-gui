# Aristar Codex GUI – Knowledge Base

## What this app does
- macOS SwiftUI app that launches multiple Codex CLI agents, each isolated to its own Git worktree (or plain directory).
- Worktrees live under `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/aristar-wt-<branch>-<id>`.
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

## UI architecture: Single-Project Split View

The app uses a **focused single-project layout** with a split view design:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  [📁 project-name ▾]  /path/to/project              [+ New Worktree] [⚙️]          │
├──────────────────────────────────┬──────────────────────────────────────────────────┤
│  WORKTREE LIST                   │  TERMINAL PANEL (with tabs)                      │
│  ─────────────────────────────   │  ────────────────────────────────────────────── │
│  🟢 feature-auth (main)          │  [🟢 feature-auth] [🟢 experiment]    [×] [⛶]   │
│  🟢 experiment (main)            │                                                  │
│  ⚫ bugfix-login (develop)       │  $ codex                                         │
│  ⚫ refactor-api (feature-v2)    │  > Working on feature...                         │
│                                  │  > █                                             │
├──────────────────────────────────┴──────────────────────────────────────────────────┤
│  Codex: Connected ✓                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Layout components
- **Project Header**: Current project name + path, dropdown switcher, "+ New Worktree" button
- **Worktree List Panel** (left): All worktrees for the current project with status, branch, and inline actions
- **Resizable Divider**: Drag to resize panels; cursor changes on hover, width persisted to UserDefaults
- **Terminal Panel** (right): Tabbed terminal view for running agents; appears when terminals are open
- **Status Footer**: Codex connection status

## Key flows
1) **Auth**: `CodexAuthManager` wraps `codex login/status`. Status drives the "Codex: Connected" footer. No tokens handled in-app.
2) **Welcome state**: When no project is open, shows a welcome view with "Open folder" button and recent projects list.
3) **Project switching**: Click the project name dropdown to access favorites, recents, and "Open folder" option. One project is open at a time.
4) **Favorites/recents**: Favorites are user-starred projects; recents track the last 5 opened projects. Both are shown in the project switcher dropdown.
5) **Worktree list**: Shows all managed worktrees for the current project in a flat list. Each row displays status (running/idle), worktree name, source branch, and inline action buttons.
6) **Worktree creation**: Click "+ New Worktree" in the header. Creates a managed worktree (`aristar-wt-<safeBranch>-<shortid>`) from the selected branch.
7) **Agent start/stop**: Click "Start" on an idle worktree to launch an agent; its terminal opens in the right panel. Click "Stop" to terminate.
8) **Terminal tabs**: Running agents appear as tabs in the terminal panel. Click a tab to switch; click × to close (agent keeps running). Click ⛶ for fullscreen terminal.
9) **Deletion**: Deleting a worktree stops its agent (if running), removes the worktree folder, and deletes the agent branch.
10) **Preview services**: Per-worktree services (name, root dir, command, optional env text) are stored in metadata. Each service runs in its own SwiftTerm terminal within the services sheet. Services have a 5-second minimum uptime so users can see error output before the session closes.
11) **App termination**: All running agents and preview services are cleanly stopped when the app quits.

## Source map
- `Package.swift` – SwiftPM config; pulls SwiftTerm.
- `Sources/AristarCodexGUI/AristarCodexGUIApp.swift` – app entry; activates NSApp for CLI launch.
- `CodexAuthManager.swift` – auth status/login, binary resolution.
- `GitService.swift` – git helpers (detect repo, list branches, add/remove worktrees, delete branch).
- `CodexSession.swift` – per-agent process + PTY plumbing; tracks original/agent branch.
- `CodexSessionManager.swift` – orchestrates sessions, worktree roots, cleanup, selected session, managed worktrees.
- `AppModel.swift` – top-level state (current project, open terminals, favorites/recents, auth, preview sessions).
- `ContentView.swift` – main layout orchestration (welcome view vs resizable split view).
- `ProjectHeader.swift` – project name/path display with switcher dropdown.
- `ProjectSwitcher.swift` – dropdown menu for switching between projects.
- `WorktreeListPanel.swift` – left panel showing all worktrees for current project; icon-only action buttons with tooltips.
- `WorktreeRow.swift` – individual worktree row with status, branch, actions.
- `TerminalPanel.swift` – right panel with tabbed terminals for running agents.
- `WelcomeView.swift` – empty state when no project is open.
- `TerminalContainer.swift` – SwiftTerm bridge (`NSViewRepresentable`).
- `CodexSessionView.swift` – session detail with terminal.
- `FolderPickerButton.swift`, `BranchCreationView.swift` – UI components.
- `ManagedWorktree.swift` – models worktree metadata for UI.
- `PreviewServiceSession.swift`, `PreviewTerminalContainer.swift` – per-service preview processes + SwiftTerm bridges.
- `BrandStyle.swift` – design tokens (colors, radii, typography helpers, button styles) shared across views.
- `ProjectListStore.swift` – persistence for favorites/recents.
- `TerminalPanelStore.swift` – persistence for terminal tabs, panel width, and current project (tabs are saved during a run but not auto-restored on launch).
- `PreviewServicesSheet.swift` – sheet UI for configuring and running preview services per-worktree.

## Behavioral details
- Worktree root per project: `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/…`.
- Managed worktree/branch name: `aristar-wt-<safeBranch>-<shortid>`; created from selected base branch/start point. Deleted when the worktree is removed. Legacy `agent-*` worktrees/branches are still recognized for cleanup. Worktree deletion will retry with `git worktree remove -f` when the worktree is dirty.
- Worktree metadata: stored outside the worktree at `~/.aristar-codex-gui/metadata/<project-key>/<worktree>.json` (base branch, agent branch, created date, display name/alias). Display names are a UI-only alias; the worktree folder/agent branch names remain unchanged.
- Recent projects: `ProjectListStore` keeps an ordered list of recent project paths (max 5); favorites are stored separately and starred. Recents exclude favorited projects.
- Cleanup: deleting a worktree removes its directory (if under the managed root) and deletes the agent branch; stopping an agent no longer removes the worktree.
- Nested worktrees are blocked: if the opened folder lives under the managed worktrees root, creating additional worktrees is disabled (depth capped at 1).
- Session updates: `AppModel` observes `CodexSessionManager` so session start/stop state stays in sync across views.
- Session persistence: removed; "Resume" runs `codex resume` in the worktree without storing session history.
- Startup: the last project is reopened, but terminal tabs start closed; previously open tabs are not restored on launch.
- Terminal: SwiftTerm connected to PTY master; TERM set to `xterm-256color`; raw escape sequences are passed through to SwiftTerm; session start is deferred until the view has a real size so the PTY is created with the correct cols/rows (also exported via `COLUMNS`/`LINES`), and subsequent resizes update the PTY size with SIGWINCH; a 1-row safety margin is applied (report rows-1 to the PTY) to avoid bottom-edge clipping; sessions launch a login `zsh` that runs the Codex command then execs into an interactive shell. Switching terminal tabs restores the session's output buffer and auto-focuses the terminal for immediate input.
- Error surfacing: worktree creation errors and missing projects surface inline; codex binary missing errors surfaced via auth status.
- Visual language: dark "Ink" base with "Midnight" panels, "Ion" accents/CTAs, rounded pills/cards, and a custom SwiftTerm theme (Ink background, Flour text, Ion cursor, Icing selection). Shared button styles (primary/ghost/danger) and pills live in `BrandStyle.swift`.
- Preview services: terminal auto-shows when starting a service; 5-second minimum uptime ensures error messages are visible before session closes; split view in services sheet shows service list on left and terminal output on right.
- Action buttons in worktree rows are icon-only with tooltips to prevent text wrapping in narrow sidebars.

## Navigation & keyboard shortcuts
| Shortcut | Action |
|----------|--------|
| `Cmd+O` | Open project folder |
| `Cmd+N` | Create new worktree |
| `Cmd+1` | Focus worktree list |
| `Cmd+2` | Focus terminal panel |
| `Cmd+[` / `Cmd+]` | Switch terminal tabs |
| `Cmd+Enter` | Toggle terminal fullscreen |
| `Cmd+W` | Close current terminal tab |
| `Cmd+K` | Clear terminal |

## Known gaps / TODOs
- ANSI/OSC passthrough is delegated to SwiftTerm.
- No settings UI for Codex binary path or profile; binary auto-resolve only.
- Custom font files are not bundled; UI uses rounded system fonts tuned to the brand until fonts are added.
- SwiftTerm warning about README resource is harmless; could be excluded if desired.

## Validation
- Welcome view displays when no project is open; recent projects are clickable.
- Project switcher dropdown shows favorites (starred) and recents.
- Selecting a project from dropdown or "Open folder" loads its worktrees.
- Worktree list shows all managed worktrees for the current project.
- Starting an agent opens its terminal in the right panel with a new tab.
- Multiple running agents show as tabs; clicking switches the active terminal.
- Closing the terminal panel (×) hides it but agents keep running.
- Stop button terminates the agent and closes its tab.
- Deleting a worktree stops its agent (if running), removes the worktree directory, and deletes the agent branch.
- Brand theme renders correctly (Ink/Midnight surfaces, Ion accents, custom SwiftTerm colors).
- Worktrees can be renamed inline. Renames trim whitespace, reject empty names, and persist the alias to metadata without changing the folder or agent branch names.
- Resizable split view divider can be dragged to resize panels; width persists across sessions.
- Preview services can be configured and run per-worktree via the Services button; terminal output shows in real-time.
- App termination cleanly stops all running agents and preview services.
- `swift test` runs unit + integration coverage.

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
