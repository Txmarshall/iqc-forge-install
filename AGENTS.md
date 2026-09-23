# AGENTS.md - iqc-forge-install

## Shared agent runtime doctrine (2026-09-23)

Applies to Claude Code and Codex sessions in this repo.

### Concurrency
- Cap **≤5 concurrent** agents/subagents in **flat sequential stacks** (as many waves as needed; **no nested cascades**).
- Ceiling may rise to **10** after a planned RAM upgrade; **only the operator** edits this cap — agents must not self-raise it.

### Context hygiene (token burn)
- Keep the **live context window thin**. Push bulk provenance to compiled reports and/or wiki / agent-memory (sources, dates, findings, open questions, paths, hashes). Session chat holds pointers + next action, not the archive.
- Prefer a **thin** `CLAUDE.md` / `AGENTS.md` and a **thin SessionStart** pointer over duplicating protocol into hook `additionalContext`.
- **Checkpoint + hand off to a new session between 200k and 400k tokens** used in context (hard ceiling 400k). Write durable handoff before the next turn; receiver must read handoff and resume next action.

### Hooks (Claude Code)
- Prefer **SessionStart / PostToolUse / Stop only** when project hooks are used.
- **Do not** install or enable a **PreToolUse readiness / journal gate** (known hang risk).
- **PreToolUse compressor experiment** (narrow Bash/Read rewrite to cut mid-session tool-result tokens): **DEFERRED**. Open-session burn is cut first via thin docs + thin SessionStart. A later compressor must never be a readiness gate. PreToolUse does **not** reduce SessionStart / first-prompt instruction load (wrong lifecycle event).
