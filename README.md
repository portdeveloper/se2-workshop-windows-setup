# Scaffold-ETH 2 Workshop — Windows Setup

This guide gets a Windows machine ready for a Scaffold-ETH 2 (Foundry flavor) workshop. It uses **WSL2 + Ubuntu** because SE-2's toolchain (Foundry, Yarn workspaces, shell scripts) was built for Unix and is much more reliable there than on native Windows.

**Time budget: ~30 min**, most of which is unattended downloads.

---

## Requirements

- Windows 10 build 19041+ (version 2004) or Windows 11
- Administrator access on the machine
- ~10 GB free disk space
- Hardware virtualization enabled in BIOS (Intel VT-x or AMD-V)
- A GitHub account

---

## Step 1 — Install WSL2 + Ubuntu (Windows side)

1. Open **PowerShell as Administrator** (right-click Start → "Terminal (Admin)").
2. Run:

   ```powershell
   irm https://raw.githubusercontent.com/portdeveloper/se2-workshop-windows-setup/main/windows-bootstrap.ps1 | iex
   ```

   Or, if this repo is already cloned locally:

   ```powershell
   .\windows-bootstrap.ps1
   ```

3. **Reboot** when prompted.
4. After reboot, the Ubuntu app launches automatically. Create a Linux username + password (independent of your Windows login — keep it simple).

If the one-liner ever fails, the fallback is `wsl --install -d Ubuntu` run as Admin.

---

## Step 2 — Install dev toolchain (inside Ubuntu)

1. Open **Ubuntu** from the Start menu.
2. Run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/portdeveloper/se2-workshop-windows-setup/main/wsl-bootstrap.sh | bash
   ```

   This installs:

   - Build tools, `curl`, `git`, `unzip`
   - `nvm` + Node.js LTS
   - Yarn via Corepack
   - Foundry (`forge`, `cast`, `anvil`, `chisel`)
   - GitHub CLI (`gh`)

3. **Close and reopen Ubuntu** so PATH changes take effect.

---

## Step 3 — Configure Git + GitHub (manual)

Inside Ubuntu:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
gh auth login
```

For `gh auth login` choose **GitHub.com → HTTPS → Login with a web browser**, then paste the one-time code in the browser window that opens. This sets up Git credentials automatically.

---

## Step 4 — Scaffold a SE-2 project pre-wired for Monad Testnet

```bash
cd ~
npx create-eth@latest -e portdeveloper/se2-monad-extension my-monad-dapp
cd my-monad-dapp
yarn install
```

This uses the [`se2-monad-extension`](https://github.com/portdeveloper/se2-monad-extension), which adds Monad Testnet (chain ID `10143`) to `foundry.toml` and `scaffold.config.ts` out of the box. You'll still have local Anvil available for dev.

---

## Step 5 — Verify

```bash
curl -fsSL https://raw.githubusercontent.com/portdeveloper/se2-workshop-windows-setup/main/verify.sh | bash
```

Every check should print `OK`. If anything fails, see Troubleshooting.

---

## Step 6 — Smoke test the stack

Open three Ubuntu terminals (Windows Terminal: `Ctrl+Shift+5` to split, or just open three windows). From inside `~/my-monad-dapp`:

```bash
yarn chain      # terminal 1 — local Anvil node
yarn deploy     # terminal 2 — deploys contracts
yarn start      # terminal 3 — Next.js dev server
```

Open <http://localhost:3000> in your **Windows** browser (Edge/Chrome/Firefox). The SE-2 frontend should load. WSL2 forwards `localhost` automatically, so no extra config needed.

---

## Recommended editor: VS Code + WSL

1. Install VS Code on **Windows**: <https://code.visualstudio.com/>
2. In VS Code, install the **WSL** extension from the marketplace.
3. From an Ubuntu terminal: `cd ~/my-monad-dapp && code .`

VS Code launches with the project mounted inside WSL — full IntelliSense, terminal, and extensions all run Linux-side.

---

## Troubleshooting

**`wsl --install` says "feature not enabled"** — virtualization is disabled in BIOS. Reboot into BIOS/UEFI settings and enable Intel VT-x or AMD-V (sometimes labeled "SVM").

**`forge: command not found` after step 2** — close and reopen Ubuntu. The Foundry installer adds itself to `~/.bashrc`, which only applies to new shells.

**`yarn install` fails with native build errors** — run `sudo apt install -y build-essential python3` and retry.

**`localhost:3000` won't load in the Windows browser** — make sure `yarn start` is actually running. If it is, run `wsl --shutdown` from PowerShell, reopen Ubuntu, and try again. Windows Firewall can occasionally interfere on first run.

**Files feel slow** — keep your project under `~/` inside WSL (e.g. `/home/you/my-dapp`), **not** under `/mnt/c/...`. Cross-filesystem I/O is the #1 WSL performance pitfall.

**Out of disk space** — WSL stores its virtual disk under `%USERPROFILE%\AppData\Local\Packages\...`. Free up space on `C:` or move the WSL distro with `wsl --export` / `wsl --import`.

---

## For workshop hosts: testing the flow end-to-end

Before the workshop, validate the whole attendee flow with **one command**:

```bash
make test-e2e
```

This spins up a clean Ubuntu 24.04 container and runs every step an attendee runs after WSL2 is up:

| Step | Action |
| ---- | ------ |
| 1    | `bash wsl-bootstrap.sh` — installs Node LTS, Yarn, Foundry, GitHub CLI |
| 2    | `bash verify.sh --ci` — confirms toolchain + network reachability |
| 3    | Configures `git user.name` / `user.email` (create-eth requires these) |
| 4    | `npx create-eth@latest my-monad-dapp -e portdeveloper/se2-monad-extension --solidity-framework foundry --skip-install` |
| 5    | `yarn install` |
| 6    | Greps the generated `foundry.toml`, `scaffold.config.ts`, and `utils/monadTestnet.ts` to confirm Monad wiring landed |
| 7    | `yarn compile` — Forge build |
| 8    | `yarn chain` (background) + `yarn deploy` — verifies contracts deploy to a local Anvil and `deployedContracts.ts` is regenerated with a real address |

**Runtime:** ~8 min on a fast connection. Requires Docker (`sudo apt install docker.io` on Ubuntu).

If `make test-e2e` passes, every command in Steps 1–6 of the attendee README is known-working — including the create-eth extension, the Monad RPC config, and the Forge deploy. If it fails, the failing step is the same step an attendee would have failed on.

The fast feedback loop is `make lint` (instant) → `make test-container` (~3 min, runs the bootstrap + verify only) → `make test-e2e` (full flow, slower). All three also run on GitHub Actions for every push.
