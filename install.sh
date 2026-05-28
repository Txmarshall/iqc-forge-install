#!/usr/bin/env bash
# iqc-forge-install -- PUBLIC macOS/Linux entrypoint for IQC machine bootstrap.
# Contains NO personal data: no paths, no repo lists, no keys.
#
# Fresh-machine usage (one line, in Terminal):
#   curl -fsSL https://raw.githubusercontent.com/Txmarshall/iqc-forge-install/main/install.sh | bash
#
# What it does:
#   1. Ensures Homebrew is installed.
#   2. Installs git + GitHub CLI if missing.
#   3. Ensures GitHub auth (interactive browser login).
#   4. Clones (or ff-updates) the PRIVATE iqc-forge-bootstrap repo.
#   5. Hands off to forge-bootstrap.sh, the real re-runnable setup.

set -uo pipefail

OWNER="Txmarshall"
BOOTSTRAP_REPO="iqc-forge-bootstrap"   # private repo holding forge-bootstrap.sh
DEST="$HOME/.forge/$BOOTSTRAP_REPO"

# Reconnect stdin to the terminal when piped via `curl | bash`, so interactive
# prompts (gh auth login, the age-key paste) actually receive keystrokes.
if [ ! -t 0 ] && [ -e /dev/tty ]; then exec < /dev/tty; fi

have() { command -v "$1" >/dev/null 2>&1; }
info() { printf '  \033[36m%s\033[0m\n' "$1"; }
die()  { printf '  \033[31m%s\033[0m\n' "$1" >&2; exit 1; }
brew_env() { for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && return 0; done; return 1; }

printf '\n\033[36miqc-forge-install -- fetching the IQC machine bootstrap\033[0m\n\n'

# 1) Homebrew
have brew || brew_env || true
if ! have brew; then
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die "Homebrew install failed."
    brew_env || true
fi
have brew || die "Homebrew still not on PATH. Open a new Terminal and re-run."

# 2) git + gh
for t in git gh; do
    have "$t" || { info "Installing $t..."; brew install "$t" || die "$t install failed."; }
done

# 3) GitHub auth (interactive; skipped if already authenticated)
if ! gh auth status >/dev/null 2>&1; then
    info "GitHub authentication needed -- launching browser login..."
    gh auth login --hostname github.com --git-protocol https --web || die "GitHub auth did not complete."
fi
info "GitHub authenticated"

# 4) Clone or update the private bootstrap repo
if [ -d "$DEST/.git" ]; then
    info "Updating existing bootstrap clone at $DEST"
    git -C "$DEST" pull --ff-only || true
else
    mkdir -p "$(dirname "$DEST")"
    info "Cloning $OWNER/$BOOTSTRAP_REPO -> $DEST"
    gh repo clone "$OWNER/$BOOTSTRAP_REPO" "$DEST" || die "Clone failed -- do you have access to the private $BOOTSTRAP_REPO repo?"
fi

# 5) Hand off
bs="$DEST/forge-bootstrap.sh"
[ -f "$bs" ] || die "forge-bootstrap.sh not found at $bs"
chmod +x "$bs" 2>/dev/null || true
info "Launching forge-bootstrap..."
printf '\n'
exec bash "$bs"
