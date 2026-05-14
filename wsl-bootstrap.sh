#!/usr/bin/env bash
# Bootstraps Ubuntu (inside WSL2) with the toolchain for a Scaffold-ETH 2
# Foundry workshop. Safe to re-run.
set -euo pipefail

echo ""
echo "==> Scaffold-ETH 2 Workshop: WSL/Ubuntu bootstrap"
echo ""

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: run this inside WSL/Ubuntu, not on Windows." >&2
  exit 1
fi

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "Note: this doesn't look like WSL. Continuing anyway — the script works on any Ubuntu."
fi

# --- System packages -------------------------------------------------------
echo "==> Installing apt packages (sudo password may be requested)"
sudo apt-get update -y
# python3 is needed by node-gyp at install time (e.g. bufferutil, utf-8-validate
# native addons pulled in transitively by ws). Without it, yarn install fails
# part-way through the link step.
sudo apt-get install -y --no-install-recommends \
  build-essential curl git unzip ca-certificates jq python3

# --- nvm + Node LTS --------------------------------------------------------
if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  echo "==> Installing nvm"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

echo "==> Installing Node.js LTS"
nvm install --lts
nvm alias default 'lts/*'
nvm use default

# --- Yarn via Corepack -----------------------------------------------------
echo "==> Enabling Corepack + Yarn"
corepack enable
corepack prepare yarn@stable --activate

# --- Foundry ---------------------------------------------------------------
if ! command -v forge >/dev/null 2>&1; then
  echo "==> Installing Foundry"
  curl -L https://foundry.paradigm.xyz | bash
fi
export PATH="$HOME/.foundry/bin:$PATH"
foundryup

# --- GitHub CLI ------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "==> Installing GitHub CLI"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y gh
fi

echo ""
echo "==> Verifying install"
VERIFY_URL="${VERIFY_URL:-https://raw.githubusercontent.com/portdeveloper/se2-workshop-windows-setup/main/verify.sh}"
if curl -fsSL "$VERIFY_URL" | bash -s -- --ci; then
  echo ""
  echo "==> Done. You're ready for the workshop."
else
  echo ""
  echo "Some toolchain checks failed. See setup.devnads.com for troubleshooting." >&2
  exit 1
fi
echo ""
echo "Next, close this window, reopen Ubuntu, then run:"
echo "  git config --global user.name  \"Your Name\""
echo "  git config --global user.email \"you@example.com\""
echo "  gh auth login"
echo "  npx create-eth@latest -e portdeveloper/se2-monad-extension my-monad-dapp"
echo ""
