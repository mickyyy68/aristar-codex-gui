# Plan

1) Auth layer
- Add `CodexAuthManager` that wraps `codex login status` / `codex login` and exposes states.  
- Surface a configurable codex binary path and clear errors for missing binary or failed login.  
- Wire a “Connect Codex” action that kicks off login and re-checks status afterward.

2) Git + worktree services
- Implement `GitService` helpers: detect repo (`rev-parse`), list branches, add/remove worktrees.  
- Define worktree storage under `.agent-worktrees/<agent>-<branch>`, ensuring dirs are created.  
- Handle failures gracefully (fall back to plain session when worktree creation fails).

3) Session engine
- Build `CodexSession` to spawn the Codex CLI TUI with `--cd <worktree>`, streaming stdout/stderr.  
- Track running state, keep an input buffer, and expose send/stop controls.  
- Ensure process cleanup on stop/deinit.

4) Project/session manager
- Create `CodexSessionManager` to open a project and cache git info.  
- Provide APIs to add plain sessions or worktree-backed sessions for a branch (optional start point).  
- On session close, clean up associated worktrees and maintain selected session.

5) SwiftUI UI
- Folder picker (NSOpenPanel) to choose project root and load branches.  
- Auth banner showing connection status with a connect button.  
- Branch picker to spawn an agent for a selected branch.  
- Session list with selection + delete; detail view with live output and input field.  
- App entry point wiring the model and views together.

6) Follow-ups / polish
- Strip ANSI or switch to `codex exec --json` for richer rendering.  
- Add settings pane for codex path and default profile (`--profile`).  
- Improve non-git handling, empty-branch UX, and error toasts/logging.
