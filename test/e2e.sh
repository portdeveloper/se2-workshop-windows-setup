#!/usr/bin/env bash
# End-to-end simulation of the workshop attendee flow inside an Ubuntu
# container. wsl-bootstrap.sh now handles install + verify + git identity +
# scaffold in one shot, so the e2e test mostly just runs it and then
# confirms the resulting project compiles + deploys.
set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-my-monad-dapp}"

step() { echo ""; echo "==> $*"; }

step "[1/6] Run wsl-bootstrap.sh (install + verify + scaffold)"
# Hand the bootstrap its env so /dev/tty prompts are skipped inside the container.
WORKSHOP_NONINTERACTIVE=1 \
WORKSHOP_GIT_NAME=workshop \
WORKSHOP_GIT_EMAIL=workshop@example.com \
WORKSHOP_PROJECT_NAME="$PROJECT_NAME" \
  bash /work/wsl-bootstrap.sh

# nvm + Foundry put themselves on PATH via ~/.bashrc; the current shell hasn't
# reloaded, so re-export for the rest of this script.
export PATH="$HOME/.foundry/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

cd "$HOME/$PROJECT_NAME"

step "[2/6] Confirm Monad config landed in generated files"
grep -q '^monadTestnet = "https://testnet-rpc.monad.xyz"' packages/foundry/foundry.toml
grep -q 'from "./utils/monadTestnet"' packages/nextjs/scaffold.config.ts
grep -q 'monadTestnet' packages/nextjs/scaffold.config.ts
test -f packages/nextjs/utils/monadTestnet.ts
grep -q '10143' packages/nextjs/utils/monadTestnet.ts
echo "  foundry.toml, scaffold.config.ts, monadTestnet.ts all have Monad wiring"

step "[3/6] yarn install (deps may have been skipped if create-eth aborted early)"
yarn install --no-immutable

step "[4/6] Compile contracts with Forge"
yarn compile

step "[5/6] Start Anvil + deploy contracts"
yarn chain >/tmp/anvil.log 2>&1 &
CHAIN_PID=$!
trap 'kill "$CHAIN_PID" 2>/dev/null || true' EXIT

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

step "[6/6] Verify deployedContracts.ts has a real address"
test -f packages/nextjs/contracts/deployedContracts.ts
grep -Eq '0x[a-fA-F0-9]{40}' packages/nextjs/contracts/deployedContracts.ts
echo "  Deploy succeeded."

echo ""
echo "==> END-TO-END FLOW PASSED."
echo "    The single one-liner produces a ready-to-dev Monad project."
