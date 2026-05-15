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
  echo "Note: this doesn't look like WSL. Continuing anyway. The script works on any Ubuntu."
fi

# Non-interactive mode for CI / Docker tests: skip /dev/tty prompts and use
# env defaults. Attendees run this normally and get prompted.
NON_INTERACTIVE="${WORKSHOP_NONINTERACTIVE:-0}"
DEFAULT_GIT_NAME="${WORKSHOP_GIT_NAME:-workshop}"
DEFAULT_GIT_EMAIL="${WORKSHOP_GIT_EMAIL:-workshop@example.com}"
DEFAULT_PROJECT_NAME="${WORKSHOP_PROJECT_NAME:-my-monad-dapp}"
EXTENSION="${WORKSHOP_EXTENSION:-portdeveloper/se2-monad-extension}"

# Stops debconf from reading our STDIN (which is the curl pipe when invoked
# as `curl ... | bash`). Without this, apt-get silently consumes script bytes
# past its own point and the script exits early with no error message.
export DEBIAN_FRONTEND=noninteractive

# --- System packages -------------------------------------------------------
echo "==> Installing apt packages (sudo password may be requested)"
sudo -E apt-get update -y </dev/null
# python3 is needed by node-gyp at install time (e.g. bufferutil, utf-8-validate
# native addons pulled in transitively by ws). Without it, yarn install fails
# part-way through the link step.
sudo -E apt-get install -y --no-install-recommends \
  build-essential curl git unzip ca-certificates jq python3 </dev/null

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
  sudo -E apt-get update -y </dev/null
  sudo -E apt-get install -y gh </dev/null
fi

echo ""
echo "==> Verifying toolchain"
VERIFY_URL="${VERIFY_URL:-https://raw.githubusercontent.com/portdeveloper/se2-workshop-windows-setup/main/verify.sh}"
if ! curl -fsSL "$VERIFY_URL" | bash -s -- --ci; then
  echo ""
  echo "Some toolchain checks failed. See setup.devnads.com for troubleshooting." >&2
  exit 1
fi

# --- Git identity ----------------------------------------------------------
# create-eth refuses to scaffold without one, so we set it before invoking.
if [[ -z "$(git config --global user.name 2>/dev/null)" ]] || \
   [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
  echo ""
  echo "==> Set your Git identity (used for commit history)"
  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    GIT_NAME="$DEFAULT_GIT_NAME"
    GIT_EMAIL="$DEFAULT_GIT_EMAIL"
    echo "   (non-interactive: $GIT_NAME <$GIT_EMAIL>)"
  else
    # Read from the user's terminal even though the script is piped from curl.
    read -r -p "   Name: " GIT_NAME </dev/tty
    read -r -p "   Email: " GIT_EMAIL </dev/tty
  fi
  git config --global user.name  "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
fi

# --- Project name ----------------------------------------------------------
echo ""
if [[ "$NON_INTERACTIVE" == "1" ]]; then
  PROJECT_NAME="$DEFAULT_PROJECT_NAME"
  echo "==> Project name: $PROJECT_NAME  (non-interactive)"
else
  read -r -p "==> Project name [$DEFAULT_PROJECT_NAME]: " PROJECT_NAME </dev/tty
  PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"
fi

# --- Scaffold --------------------------------------------------------------
cd "$HOME"
if [[ -d "$PROJECT_NAME" ]]; then
  echo ""
  echo "$HOME/$PROJECT_NAME already exists. Skipping scaffold."
  echo "Delete it first if you want a fresh project."
else
  echo ""
  echo "==> Scaffolding $PROJECT_NAME (Scaffold-ETH 2 + Monad Testnet)"
  npx -y create-eth@latest "$PROJECT_NAME" \
    --extension "$EXTENSION" \
    --solidity-framework foundry
fi

# --- Open in VSCode --------------------------------------------------------
# VSCode's WSL extension puts `code` on PATH; if it isn't there (no VSCode,
# no WSL extension, headless run), just skip silently.
if [[ "$NON_INTERACTIVE" != "1" ]] && command -v code >/dev/null 2>&1; then
  echo ""
  echo "==> Opening $PROJECT_NAME in VSCode"
  code "$PROJECT_NAME" || true
fi

cat <<EOF

==> Ready to dev.

Three terminals from ~/$PROJECT_NAME:
   yarn chain      # terminal 1 (local Anvil)
   yarn deploy     # terminal 2
   yarn start      # terminal 3 (http://localhost:3000)

Open http://localhost:3000 in your browser.

Optional, when you want to push code or deploy to Monad Testnet:
   gh auth login
   yarn deploy --network monadTestnet

EOF
