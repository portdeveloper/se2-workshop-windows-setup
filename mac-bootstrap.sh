#!/usr/bin/env bash
# Bootstraps macOS for a Scaffold-ETH 2 (Foundry) + Monad workshop.
# Mirrors wsl-bootstrap.sh: install nvm + Node LTS + Yarn + Foundry, verify,
# prompt for git identity, scaffold the project.
#
# Safe to re-run.
set -euo pipefail

echo ""
echo "==> Scaffold-ETH 2 Workshop: macOS bootstrap"
echo ""

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: this is the macOS bootstrap. On Linux/WSL, use wsl-bootstrap.sh." >&2
  exit 1
fi

NON_INTERACTIVE="${WORKSHOP_NONINTERACTIVE:-0}"
DEFAULT_GIT_NAME="${WORKSHOP_GIT_NAME:-workshop}"
DEFAULT_GIT_EMAIL="${WORKSHOP_GIT_EMAIL:-workshop@example.com}"
DEFAULT_PROJECT_NAME="${WORKSHOP_PROJECT_NAME:-my-monad-dapp}"
EXTENSION="${WORKSHOP_EXTENSION:-portdeveloper/se2-monad-extension}"

# --- Command Line Tools ----------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  echo "==> Installing Apple Command Line Tools"
  echo "    A dialog will appear. Click 'Install' and wait for it to finish,"
  echo "    then re-run this script."
  xcode-select --install || true
  exit 1
fi

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

# --- Verify (lightweight: skip gh which we don't install on macOS) ---------
echo ""
echo "==> Verifying toolchain"
fail=0
for cmd in git node yarn forge cast anvil; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  [OK]   %s\n" "$cmd"
  else
    printf "  [FAIL] %s\n" "$cmd"
    fail=$((fail+1))
  fi
done
if [[ $fail -gt 0 ]]; then
  echo "$fail toolchain checks failed. See setup.devnads.com for troubleshooting." >&2
  exit 1
fi

# --- Git identity ----------------------------------------------------------
if [[ -z "$(git config --global user.name 2>/dev/null)" ]] || \
   [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
  echo ""
  echo "==> Set your Git identity (used for commit history)"
  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    GIT_NAME="$DEFAULT_GIT_NAME"
    GIT_EMAIL="$DEFAULT_GIT_EMAIL"
    echo "   (non-interactive: $GIT_NAME <$GIT_EMAIL>)"
  else
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

cat <<EOF

==> Ready to dev.

Three terminals from ~/$PROJECT_NAME:
   yarn chain      # terminal 1 (local Anvil)
   yarn deploy     # terminal 2
   yarn start      # terminal 3 (http://localhost:3000)

Open http://localhost:3000 in your browser.

To deploy to Monad Testnet: get MON from the faucet linked in docs.monad.xyz,
then yarn deploy --network monadTestnet.

EOF
