#!/usr/bin/env bash
# Pre-workshop verification: confirms the toolchain installed by wsl-bootstrap.sh
# is present and working. Exits non-zero if any check fails.
#
# Usage: verify.sh [--ci]
#   --ci   Skip checks that require human setup (WSL detection, git identity,
#          gh auth). Used by CI to validate the toolchain only.
set -uo pipefail

ci_mode=0
case "${1:-}" in
  --ci|--skip-auth) ci_mode=1 ;;
  -h|--help) echo "Usage: $0 [--ci]"; exit 0 ;;
  "") ;;
  *) echo "Unknown argument: $1" >&2; exit 2 ;;
esac

pass=0
fail=0

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf "  [OK]   %s\n" "$label"
    pass=$((pass+1))
  else
    printf "  [FAIL] %s\n" "$label"
    fail=$((fail+1))
  fi
}

# Make sure tools installed by wsl-bootstrap.sh are on PATH even if the user
# hasn't reopened their shell yet.
export PATH="$HOME/.foundry/bin:$PATH"
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
fi

echo ""
echo "==> Verifying SE-2 workshop setup"
echo ""

echo "Environment:"
check "running on Linux"     bash -c '[[ "$(uname -s)" == "Linux" ]]'
if [[ $ci_mode -eq 0 ]]; then
  check "running under WSL"  bash -c 'grep -qi microsoft /proc/version'
fi
echo ""

echo "Toolchain:"
check "git"                  git --version
check "node >= 20"           bash -c 'v=$(node -v 2>/dev/null | sed "s/v//;s/\..*//"); [[ -n "$v" && "$v" -ge 20 ]]'
check "yarn"                 yarn --version
check "forge"                forge --version
check "cast"                 cast --version
check "anvil"                anvil --version
check "gh"                   gh --version
echo ""

if [[ $ci_mode -eq 0 ]]; then
  echo "Git identity:"
  check "user.name set"      bash -c '[[ -n "$(git config --global user.name)" ]]'
  check "user.email set"     bash -c '[[ -n "$(git config --global user.email)" ]]'
  echo ""

  echo "GitHub auth:"
  check "gh authenticated"   gh auth status
  echo ""
fi

echo "Network:"
check "github.com reachable"        curl -fsS --max-time 5 -o /dev/null https://api.github.com/zen
check "public Ethereum RPC reachable" \
  bash -c 'curl -fsS --max-time 5 -X POST -H "content-type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"web3_clientVersion\",\"id\":1}" \
    https://ethereum-rpc.publicnode.com | grep -q result'
echo ""

if [[ $fail -eq 0 ]]; then
  echo "All $pass checks passed. You're ready for the workshop."
  exit 0
else
  echo "$fail check(s) failed, $pass passed. See README → Troubleshooting."
  exit 1
fi
