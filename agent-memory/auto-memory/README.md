# auto-memory — git-canonical harness memory (dual-write)

Claude Code's file-based harness memory (feedback / project / user / reference
facts + the `MEMORY.md` pointer index) lives at a **machine-local** path:

- Windows: `%USERPROFILE%\.claude\projects\<slug>\memory\`
- macOS / Linux: `~/.claude/projects/<slug>/memory/`

`<slug>` is the repo's absolute working-directory path with **every
non-alphanumeric character replaced by `-`** (e.g. `C:\Projects\<repo>` →
`C--Projects-<repo>`; `/Users/<you>/Projects/<repo>` →
`-Users--you--Projects-<repo>`). The slug is **computed forward from the
abspath**, never reverse-engineered from the mangled dir name (that mapping is
lossy — a `-` in the repo name is indistinguishable from a path separator).

This directory (`agent-memory/auto-memory/`) is the **git-canonical store** for
those files. The harness reads/writes them in place because the machine-local
`memory/` path above is a **junction (Windows) / symlink (POSIX) → here**. So a
harness write lands in the repo; `/closeout` commits + pushes it. This is the
dual-write architecture decided in iqc-af2
`docs/decisions/2026-05-29-harness-memory-dual-write.md` (Option 3):

- **Git is the live, canonical store** — per-change audit trail, travels with
  the clone, reaches other machines via `/kickoff`'s `git pull --ff-only`.
- **The Obsidian vault is a read mirror** — `/closeout` mirrors changed files
  into the vault via the Obsidian MCP, each stamped with a
  `DO NOT EDIT — mirrored from <repo> @ <SHA> <ts>` banner. The mirror is for
  cross-device / mobile reading; it is **not** the canonical store and must not
  be edited.

## Bootstrap manages the link — no manual copy

The link is created automatically by `iqc-skills/bootstrap.{ps1,sh}` (Step 4c).
On a freshly bootstrapped machine the junction/symlink already points the
harness memory path at this directory — **zero manual steps**. Bootstrap:

1. Discovers this repo by reading `<repo>/.harness/metadata.json`
   (`harness_memory.repo_memory_path = agent-memory/auto-memory`).
2. Computes `<slug>` by forward-mangling the repo's absolute path.
3. Creates `~/.claude/projects/<slug>/memory` →
   `<repo>/agent-memory/auto-memory` (`New-Item -ItemType Junction` on Windows,
   non-admin OK per the Windows symlink probe; `ln -s` on POSIX).
4. Is idempotent + guarded: an existing correct link is left alone; a stale link
   (wrong target) is repointed; a **real directory** with files is **backed up,
   not clobbered** (see recovery below).

The old "manually copy `*.md` into the memory path" workflow is **retired** —
copies drift silently. The link makes the repo and the harness path the same
bytes.

## Recovery — broken or wrong link

Junctions/symlinks don't travel inside a git clone and can break on OS
moves/updates. Re-run `iqc-skills` bootstrap (or `/bootstrap`) to regenerate the
link idempotently. To inspect or repair by hand (run from the repo root):

```powershell
# Windows — inspect
$slug = ($PWD.Path -replace '[^A-Za-z0-9]','-')
Get-Item "$env:USERPROFILE\.claude\projects\$slug\memory" -Force |
  Select-Object LinkType, Target
# Windows — recreate (after removing a broken link)
$link = "$env:USERPROFILE\.claude\projects\$slug\memory"
New-Item -ItemType Junction -Path $link -Target "$PWD\agent-memory\auto-memory"
```

```bash
# POSIX — inspect
slug="$(pwd | sed 's/[^A-Za-z0-9]/-/g')"
ls -la "$HOME/.claude/projects/$slug/memory"
# POSIX — recreate
link="$HOME/.claude/projects/$slug/memory"
ln -s "$(pwd)/agent-memory/auto-memory" "$link"
```

If bootstrap finds a **real directory** (not a link) at the memory path with
files in it — i.e. the harness wrote memory before the link existed — it moves
it aside to `memory.bak.<timestamp>` and warns loudly. Merge any unique facts
from the backup into this directory, commit, then re-run bootstrap.

## No secrets in memory (git-substrate rule)

The git store is **not** end-to-end encrypted (Obsidian Sync is; git is not).
Therefore memory holds **facts, lessons, preferences, and pointers only** — no
secrets, tokens, API keys, private keys, or PII. `/closeout`'s memory gate runs
a fail-closed secret scan (provider-key regexes + PEM headers + entropy +
allowlist) before committing and **refuses to commit** on a hit, marking
walk-away NOT safe. `git-crypt`/SOPS on this directory is the held escalation if
the no-secrets rule proves insufficient.

## Size cap (E039 — no silent truncation)

`MEMORY.md` is a pointer index with a hard cap: **180 lines / 22 KB warn,
200 lines / 25 KB is the truncation cliff**. Enforcement lives at two points so
a bypassed local hook can't silently reintroduce truncation:

- `/kickoff` warns when `MEMORY.md` is ≥180 lines or ≥22 KB.
- `/closeout`'s memory gate fails the commit if any memory file exceeds the cap.

Keep `MEMORY.md` to one line per memory; push detail into the per-topic files.

## Authority

iqc-af2 `docs/decisions/2026-05-29-harness-memory-dual-write.md` (the dual-write
ADR). This repo opted in by committing `.harness/metadata.json`; the store is
empty until the harness first writes memory during a Claude session in this
repo's cwd.
