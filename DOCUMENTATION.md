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
2) Project open: choose folder via `NSOpenPanel`. `GitService.detectRepo` stores git info; branches are listed for the picker.
3) Agent creation:
   - Plain session: runs Codex in the project root (non-git or fallback).
   - Branch session: creates unique worktree + branch (e.g., `agent-1-main-<id>`) under the worktrees root, then launches Codex in that worktree.
4) Agent UI: left list shows branch (headline) and agent title; select to see terminal. SwiftTerm renders Codex TUI; input goes straight to PTY.
5) Deletion:
   - Toolbar trash or row context menu: if branch-backed, removes worktree folder and deletes the agent branch (`git branch -D`), then drops session. Plain sessions just stop/close.

## Source map
- `Package.swift` – SwiftPM config; pulls SwiftTerm.
- `Sources/AristarCodexGUI/AristarCodexGUIApp.swift` – app entry; activates NSApp for CLI launch.
- `CodexAuthManager.swift` – auth status/login, binary resolution.
- `GitService.swift` – git helpers (detect repo, list branches, add/remove worktrees, delete branch).
- `CodexSession.swift` – per-agent process + PTY plumbing; tracks original/agent branch.
- `CodexSessionManager.swift` – orchestrates sessions, worktree roots, cleanup, selected session.
- `AppModel.swift` – top-level state (project, branches, auth).
- `ContentView.swift` – layout, lists, toolbars, branch picker, deletion hooks.
- `TerminalContainer.swift` – SwiftTerm bridge (`NSViewRepresentable`).
- `CodexSessionView.swift` – session detail with terminal.
- `FolderPickerButton.swift`, `BranchCreationView.swift` – UI components.

## Behavioral details
- Worktree root per project: `~/.aristar-codex-gui/worktrees/<project-name>-<hash>/…`.
- Agent branch name: `agent-<n>-<safeBranch>-<shortid>`; created from selected branch/start point. Deleted on cleanup.
- Cleanup on close: stops process; if under worktrees root, removes worktree and deletes agent branch.
- Terminal: SwiftTerm connected to PTY master; TERM set to `xterm-256color`; raw escape sequences are passed through to SwiftTerm.
- Selection: `NavigationSplitView` with list selection binding; toolbar trash acts on selected session.
- Error surfacing: worktree creation errors shown under branch picker; codex binary missing errors surfaced via auth status.

## Known gaps / TODOs
- ANSI/OSC passthrough is delegated to SwiftTerm; no custom color theme yet.
- No settings UI for Codex binary path or profile; binary auto-resolve only.
- No persistence of recent projects/agents; state resets on relaunch.
- No resize/cols-rows sync back to Codex; SwiftTerm handles display internally.
- SwiftTerm warning about README resource is harmless; could be excluded if desired.

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
