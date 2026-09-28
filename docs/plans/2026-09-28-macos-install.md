# macOS Install Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`
> (recommended) or `superpowers:executing-plans` to implement this plan
> task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One command (`./install`) sets up a fresh Mac from this repo; the
Ubuntu/WSL path keeps working.

**Architecture:** A Brewfile owns every Mac package. A small `install` script
bootstraps Homebrew + Ansible + stow, then runs `setup.yml`. The playbook gates
Linux-only roles/tasks on `ansible_os_family == 'Debian'`, adds a `macos` role
that runs `brew bundle`, and keeps the cross-OS roles (stow, claude, ssh, gpg,
mise, tmux TPM, oh-my-zsh) shared.

**Tech Stack:** Homebrew `brew bundle`, Ansible (brew `ansible` formula, ships
`ansible.posix`), GNU stow, zsh.

**Spec:** Option 1 ("Hybrid") from the 2026-09-28 session; no separate spec doc.

## Global Constraints

- No JIRA for this repo. Commits follow repo history: `<type>(<scope>): <msg>`,
  e.g. `feat(macos): add Brewfile`.
- The repo has ~15 unrelated modified/untracked files. Every commit stages only
  its own named paths. Never `git add -A`.
- Linux behavior is unchanged except where a task says so. Gate with
  `when: ansible_os_family == 'Debian'` / `'Darwin'`, never by deleting tasks.
- Apple Silicon only: Homebrew prefix is `/opt/homebrew` (already assumed by `.zshrc`).
- `.stow-local-ignore` already ignores `^/install` — the bootstrap script is named `install`.

## Facts established during research (verify before relying on them)

- `setup.yml:10-14` `pre_tasks` runs `apt` → playbook dies on macOS at task 1.
- This Mac: 41 brew leaves, 25 casks, 10 taps. `ansible` and `stow` NOT installed.
- Home already has stow-style links (`~/.zshrc`, `~/.config/nvim`, per-file
  links in `~/.claude/hooks/`), so stow was run by hand at some point.
- `~/.gnupg/gpg-agent.conf` is a real file with `pinentry-mac`; repo's
  `.gnupg/gpg-agent.conf` points at `/home/tbaur/...` (Linux). Stow would conflict.
- `.zshrc` sources zsh plugins from `$HOMEBREW_PREFIX/share/...`, not from
  `~/.oh-my-zsh/custom/plugins` → on Mac the zsh role's plugin git clones are unused.
- `.zshrc:134` expects mise at `/opt/homebrew/bin/mise`; `roles/mise` installs to `~/.local/bin/mise`.

## Review Focus

1. **Fresh `$HOME` with no `~/.claude` or `~/.config`** — stow must link files
   individually, not fold the whole dir into one symlink (otherwise Claude Code
   and every app write their state into the repo). Pinned by Task 3 Step 4.
2. **Stow conflicts with real files already in `$HOME`** (e.g. `~/.gnupg/gpg-agent.conf`,
   `~/.config/aerospace`) — run must fail loudly, not half-apply. Pinned by Task 3 Step 1.
3. **Re-running `./install` on an already set-up Mac** — idempotent: no reinstall,
   `brew bundle` reports satisfied, second playbook run reports 0 failed. Pinned by Task 5 Step 3.
4. **Homebrew missing or not on `PATH` in a fresh shell** — `install` must
   `eval "$(/opt/homebrew/bin/brew shellenv)"` itself after installing. Pinned by Task 4 Step 2.
5. **Linux regression** — Debian path still lists the same tasks. Pinned by Task 5 Step 4.

---

### Task 1: Brewfile

**Files:**
- Create: `Brewfile`
- Modify: `.stow-local-ignore` (add `^/Brewfile.*`)

- [ ] **Step 1:** `brew bundle dump --file=Brewfile --describe`
- [ ] **Step 2:** Human prunes: remove anything not wanted on every Mac. Ensure
  `stow`, `ansible`, `gnupg`, `pinentry-mac` are present (add `brew "stow"`,
  `brew "ansible"` — not currently installed).
- [ ] **Step 3:** Add `^/Brewfile.*` under the `^/README.md` line in `.stow-local-ignore`.
- [ ] **Step 4:** `brew bundle check --file=Brewfile --verbose` → lists only
  `stow` and `ansible` as missing. Then `brew bundle --file=Brewfile` →
  `brew bundle check` prints "The Brewfile's dependencies are satisfied."
- [ ] **Step 5:** Commit `Brewfile .stow-local-ignore` — `feat(macos): add Brewfile`

### Task 2: Gate Linux-only work, add `macos` role

**Files:**
- Create: `roles/macos/tasks/main.yml`
- Modify: `setup.yml`, `roles/stow/tasks/main.yml`, `roles/tmux/tasks/main.yml`,
  `roles/zsh/tasks/main.yml`, `roles/mise/tasks/main.yml`

- [ ] **Step 0: Linux baseline** (for Task 5 Step 4), before any edit:
  run the Task 5 Step 4 docker command against the unmodified repo and save the
  `--list-tasks` output to the scratchpad as `tasks-before.txt`.

- [ ] **Step 1: `roles/macos/tasks/main.yml`**

```yaml
- name: Install Brewfile packages
  ansible.builtin.command: brew bundle --file={{ playbook_dir }}/Brewfile
  register: brew_bundle
  changed_when: "'Installing' in brew_bundle.stdout or 'Upgrading' in brew_bundle.stdout"
```

- [ ] **Step 2: `setup.yml`**
  - `pre_tasks` "Update apt": add `when: ansible_os_family == 'Debian'`.
  - Add first task: `name: macOS packages`, `tags: macos`, `import_role: name: macos`,
    `when: ansible_os_family == 'Darwin'`.
  - Add `when: ansible_os_family == 'Debian'` to: Core Utils, Fish Shell, rustup,
    rye, Neovim, Terminal, "Copy xinitrc for WSLg Workaround".
  - Leave shared: ZSH, Stow, Mise, SSH, GPG, Tmux, Claude Code, "Copy local git config".

- [ ] **Step 3: Shared roles — gate only their apt/package tasks** with
  `when: ansible_os_family == 'Debian'`:
  - `roles/stow/tasks/main.yml` "Install stow".
  - `roles/tmux/tasks/main.yml` "Install Tmux" (TPM clone stays shared).
  - `roles/zsh/tasks/main.yml`: "Install ZSH", "Install zoxide", "Install fzf",
    the three plugin clones, "Change user shell to zsh" (macOS default shell is zsh).
    Keep shared: Oh My Zsh clone, catppuccin download.
  - `roles/stow/tasks/main.yml` "Run ZSH_CUSTOM Stow" stays shared (links aliases/functions into omz custom).

- [ ] **Step 4: `roles/mise/tasks/main.yml`** — gate "Fetch"/"Install mise-en-place"
  on Debian; replace hardcoded bin with a fact:

```yaml
- name: Set mise binary path
  ansible.builtin.set_fact:
    mise_bin: "{{ '/opt/homebrew/bin/mise' if ansible_os_family == 'Darwin' else ansible_env.HOME + '/.local/bin/mise' }}"
```
  and use `{{ mise_bin }}` in both lines of "Install mise toolchains".

- [ ] **Step 5:** `ansible-playbook setup.yml --syntax-check` → no errors.
  `ansible-playbook setup.yml --list-tasks` → Debian-only tasks still listed (list ignores `when`).
- [ ] **Step 6:** Commit the six files — `feat(macos): gate Linux-only roles and add macos role`

### Task 3: Make stow safe on a fresh or existing Mac

**Files:**
- Modify: `roles/stow/tasks/main.yml`, `roles/gpg/tasks/main.yml`, `.stow-local-ignore`
- Move: `.gnupg/gpg-agent.conf` → `roles/gpg/files/gpg-agent.conf.debian`

- [ ] **Step 1: Find conflicts.** `stow -n -v . --target ~ 2>&1 | grep -iE 'conflict|existing'`.
  Record each. For each real file that matches the repo copy, back it up to the
  scratchpad, `diff -q` it against the repo, then delete it so stow can link. Any
  file that *differs* → stop and ask the human.
- [ ] **Step 2: gpg-agent.conf per OS.** `git mv .gnupg/gpg-agent.conf roles/gpg/files/gpg-agent.conf.debian`.
  If `.gnupg/` then holds only `gpg.conf`, leave it stowed. Add to `roles/gpg/tasks/main.yml`:

```yaml
- name: Install gpg-agent.conf
  tags: [gpg, gpg-conf]
  ansible.builtin.copy:
    dest: "{{ ansible_env.HOME }}/.gnupg/gpg-agent.conf"
    mode: "0600"
    src: "{{ 'gpg-agent.conf.debian' if ansible_os_family == 'Debian' else omit }}"
    content: "{{ 'pinentry-program /opt/homebrew/bin/pinentry-mac\n' if ansible_os_family == 'Darwin' else omit }}"
```
- [ ] **Step 3: Pre-create dirs so stow never folds them.** Add as the first task
  of `roles/stow/tasks/main.yml` (before "Run Stow"):

```yaml
- name: Pre-create dirs stow must descend into
  ansible.builtin.file:
    path: "{{ ansible_env.HOME }}/{{ item }}"
    state: directory
    mode: "{{ '0700' if item == '.gnupg' else '0755' }}"
  loop:
    - .config
    - .claude/hooks
    - .claude/skills
    - .claude/commands
    - .local/bin
    - .gnupg
```
  Also add `^/\.serena` and `\.DS_Store` to `.stow-local-ignore`.
- [ ] **Step 4: Fresh-HOME test** (Review Focus 1):

```bash
FAKE=$(mktemp -d)   # executor: use the session scratchpad dir
HOME=$FAKE ansible-playbook -i hosts setup.yml --tags stow,claude,gpg-conf -e gpg_passphrase=unused 2>&1 | tail -5
test -d "$FAKE/.claude" && ! test -L "$FAKE/.claude" && echo OK-claude-real-dir
test -d "$FAKE/.config" && ! test -L "$FAKE/.config" && echo OK-config-real-dir
test -L "$FAKE/.claude/hooks/crg-update.sh" && echo OK-hook-linked
grep pinentry-mac "$FAKE/.gnupg/gpg-agent.conf"
```
  Expected: three OK lines + pinentry-mac line. `gpg-conf` tag skips the vaulted
  key copy, so no vault password is needed.
- [ ] **Step 5:** Commit — `fix(stow): pre-create target dirs and split gpg-agent.conf per OS`

### Task 4: `install` bootstrap script + README

**Files:**
- Create: `install` (mode 0755)
- Modify: `README.md`

- [ ] **Step 1: `install`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname)" == Darwin ]]; then
  xcode-select -p >/dev/null 2>&1 || { xcode-select --install; echo "Re-run after Xcode CLT finishes."; exit 1; }
  [[ -x /opt/homebrew/bin/brew ]] || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  brew install ansible stow
fi

ansible-playbook -i hosts --ask-become-pass --ask-vault-pass setup.yml "$@"
```
- [ ] **Step 2: Verify PATH handling** (Review Focus 4):
  `env -i HOME=$HOME PATH=/usr/bin:/bin bash -n install && env -i HOME=$HOME PATH=/usr/bin:/bin bash -c 'eval "$(/opt/homebrew/bin/brew shellenv)"; command -v brew'`
  → prints `/opt/homebrew/bin/brew`.
- [ ] **Step 3: README** — rename intro to cover Linux + macOS; add a `## macOS`
  section: `git clone … && cd ansible-dotfiles && ./install`. Note that `./install`
  passes extra args through (e.g. `./install --tags claude`).
- [ ] **Step 4:** Commit `install README.md` — `feat(macos): add install bootstrap script`

### Task 5: End-to-end verification on this Mac

- [ ] **Step 1:** `./install --check --diff` → 0 failed. Read every `changed` line;
  anything unexpected → stop and ask.
- [ ] **Step 2:** `./install` (real run) → 0 failed.
- [ ] **Step 3:** `./install` again → 0 failed; `brew bundle` task `ok`, stow tasks `ok` (Review Focus 3).
- [ ] **Step 4: Linux regression** (Review Focus 5), in OrbStack:
  `docker run --rm -v "$PWD":/r -w /r ubuntu:24.04 bash -c 'apt-get update -qq && apt-get install -yqq ansible >/dev/null && ansible-playbook -i hosts setup.yml --syntax-check && ansible-playbook -i hosts setup.yml --list-tasks' `
  → syntax OK. Save as `tasks-after.txt`, `diff` against Task 2 Step 0's
  `tasks-before.txt`. Only additions: macos role, mise fact, gpg-agent.conf task,
  pre-create dirs task.
- [ ] **Step 5:** Open a new Ghostty window: prompt renders, `mise ls` works,
  `echo test | gpg --clearsign` prompts via pinentry-mac.

## Not in scope (logged)

- `.zshrc` hardcodes `/opt/homebrew` (lines 8, 87, 91, 134) → Linux shell likely broken.
- Tracked `.DS_Store` files (`git rm --cached`).
- `rye` role installs a deprecated tool (Linux).
