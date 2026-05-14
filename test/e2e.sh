#!/usr/bin/env bash
# End-to-end simulation of the workshop attendee flow inside an Ubuntu
# container. Mirrors exactly what a Windows attendee does after WSL2 is up:
#
#   1. install the dev toolchain (wsl-bootstrap.sh)
#   2. verify the toolchain (verify.sh --ci)
#   3. configure git identity (create-eth requires it)
#   4. scaffold a SE-2 project with the Monad extension
#   5. yarn install
#   6. confirm Monad config landed in foundry.toml / scaffold.config.ts
#   7. compile contracts (forge)
#   8. start local Anvil + deploy contracts to it
#
# Designed to run from inside the container built by test/Dockerfile, with the
# repo mounted read-only at /work.
set -euo pipefail

EXTENSION="${EXTENSION:-portdeveloper/se2-monad-extension}"
PROJECT_NAME="${PROJECT_NAME:-my-monad-dapp}"

step() { echo ""; echo "==> $*"; }

step "[1/8] Install dev toolchain"
bash /work/wsl-bootstrap.sh

# nvm + Foundry add themselves to ~/.bashrc but this shell hasn't reloaded.
export PATH="$HOME/.foundry/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

step "[2/8] Verify toolchain"
bash /work/verify.sh --ci

step "[3/8] Configure git identity"
git config --global user.name  "workshop"
git config --global user.email "workshop@example.com"

step "[4/8] Scaffold project with the Monad extension"
cd "$HOME"
rm -rf "$PROJECT_NAME"
npx -y create-eth@latest "$PROJECT_NAME" \
  --extension "$EXTENSION" \
  --solidity-framework foundry \
  --skip-install

cd "$PROJECT_NAME"

step "[5/8] yarn install"
# CI=true is set by GitHub Actions runners and auto-enables Yarn's immutable
# mode. A freshly scaffolded lockfile has minor peer-dep drift, so we opt out
# here. Attendees don't hit this — they aren't in a CI env.
yarn install --no-immutable

step "[6/8] Verify Monad config landed in generated files"
grep -q '^monadTestnet = "https://testnet-rpc.monad.xyz"' packages/foundry/foundry.toml
grep -q 'from "./utils/monadTestnet"' packages/nextjs/scaffold.config.ts
grep -q 'monadTestnet' packages/nextjs/scaffold.config.ts
test -f packages/nextjs/utils/monadTestnet.ts
grep -q '10143' packages/nextjs/utils/monadTestnet.ts
echo "  foundry.toml, scaffold.config.ts, monadTestnet.ts all have Monad wiring"

step "[7/8] Compile contracts with Forge"
yarn compile

step "[8/8] Start Anvil + deploy contracts"
yarn chain >/tmp/anvil.log 2>&1 &
CHAIN_PID=$!
trap 'kill "$CHAIN_PID" 2>/dev/null || true' EXIT

# Wait up to 60s for Anvil to start accepting RPC
ready=0
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null -X POST -H 'content-type: application/json' \
       --data '{"jsonrpc":"2.0","method":"eth_blockNumber","id":1}' \
       http://127.0.0.1:8545 2>/dev/null; then
    echo "  Anvil ready after ${i}s"
    ready=1
    break
  fi
  sleep 1
done
if [[ $ready -eq 0 ]]; then
  echo "  Anvil never became ready. Tail of anvil.log:"
  tail -30 /tmp/anvil.log
  exit 1
fi

yarn deploy

# deployedContracts.ts is regenerated on every yarn deploy; verify it has a
# real on-chain address (a hex 0x... 40-char string).
test -f packages/nextjs/contracts/deployedContracts.ts
grep -Eq '0x[a-fA-F0-9]{40}' packages/nextjs/contracts/deployedContracts.ts
echo "  Deploy succeeded — deployedContracts.ts has a real address"

echo ""
echo "==> END-TO-END FLOW PASSED."
echo "    Attendee command works: npx create-eth@latest -e $EXTENSION $PROJECT_NAME"
