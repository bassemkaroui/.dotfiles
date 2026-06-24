# .dotfiles Repository

## Overview

A modular dotfiles management system using **GNU Stow** for clean symlink-based deployment and **Mise** for task automation. Configures a complete development environment across 16 config packages with tag-based device variants.

## Tech Stack

| Component     | Purpose                                              |
| ------------- | ---------------------------------------------------- |
| **Stow**      | Symlink farm manager for deploying dotfiles packages |
| **Mise**      | Version manager + task runner for setup automation   |
| **Zsh**       | Primary shell with oh-my-zsh + Powerlevel10k         |
| **Runtimes**  | Rust, Go, Node.js, Neovim (managed via mise)         |
| **CLI Tools** | fzf, ripgrep, fd, yazi, bat, delta, eza, zoxide      |

## Project Structure

```
.dotfiles/
├── bash/             → Shell configurations (tag-default/)
├── zsh/              → Zsh config (tag-default/)
├── tmux/             → Tmux + oh-my-tmux submodule (tag-default/)
├── nvim/             → Neovim config submodule (tag-default/)
├── p10k/             → Powerlevel10k prompt (tag-default/)
├── fzf/, yazi/, bat/, ruff/ → CLI tool configs (tag-default/)
├── gh/, gh-dash/     → GitHub CLI & dashboard configs (tag-default/)
├── claude/           → Claude Code IDE config (tag-default/)
├── mise/             → Mise tool config — nested stow (tag-default/)
├── gpg/, gnome_themes/, ghostty/ → Additional tools (tag-default/)
└── .mise.toml        → Root mise task definitions
```

**Every package uses `tag-*` subdirectories.** Files inside a tag dir mirror `~/.` structure:

- `bash/tag-default/.bashrc` → `~/.bashrc` (when stowed)
- `bat/tag-default/.config/bat/themes/...` → `~/.config/bat/themes/...`

## Quick Start

**First-time setup:**

```bash
git clone --recursive https://github.com/bassemkaroui/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
gh auth login           # Or: export GITHUB_TOKEN=ghp_... — required for mise install (rate limit)
mise run init           # Installs stow, prompts for mise conf.d exclusions, deploys mise config
mise run bootstrap      # Full machine setup
```

> **GitHub token is required.** `mise install` resolves aqua/github/vfox tools (ripgrep, fzf, gh, neovim, …) by hitting the GitHub releases API, which rate-limits unauthenticated callers to 60 req/hr. `init` Step 0 probes `$MISE_GITHUB_TOKEN` → `$GITHUB_TOKEN` → `$GH_TOKEN` → `gh auth token`. If none are found and `gh` is missing, `init` (interactive mode) offers to install it via `mise install gh@latest` (single API call, fits in the unauth budget) and runs `gh auth login`. Non-sudo users who can't install `gh` at all can instead generate a PAT at https://github.com/settings/tokens (no scopes required) and `export GITHUB_TOKEN=ghp_...` before re-running. Non-interactive mode warns and continues best-effort.

**Manual stow deployment:**

```bash
stow -d bash -t ~ tag-default              # Deploy a single package (default tag)
stow -d <package> -t ~ tag-laptop          # Deploy a device-specific variant (e.g. tag-laptop/tag-desktop)
```

## Essential Commands

| Task                    | Command                          |
| ----------------------- | -------------------------------- |
| Full machine setup      | `mise run bootstrap`             |
| Set/change device tag   | `mise run setup:device-tag`      |
| Manage exclusions       | `mise run setup:exclude`         |
| Manage mise tool exclusions | `mise run setup:mise-conf-exclude` |
| Manage install opt-outs | `mise run setup:install-exclude` |
| Manage custom configs   | `mise run setup:custom-dotfiles` |
| Deploy/redeploy configs | `mise run setup:dotfiles`        |
| Install git signing (if GPG key present) | `mise run setup:git-signing`     |
| Check GPG key expiry    | `mise run gpg:check-expiry`      |
| Extend GPG key expiry (default 1y) | `mise run gpg:extend-expiry [--period <value>]` |
| List GPG secret keys    | `mise run gpg:list`              |
| Back up GPG keyring (encrypted) | `mise run gpg:backup`    |
| Restore a GPG backup (latest if --archive omitted) | `mise run gpg:restore [--archive <path>]` |
| Set ownertrust=ultimate on own keys | `mise run gpg:trust`     |
| Run CI-equivalent lint locally | `mise run lint`           |
| Install/update Obsidian (AppImage) | `mise run install:obsidian` |
| Check for newer Obsidian release | `mise run update:obsidian` |
| Update tmux             | `mise run update:oh-my-tmux`     |
| Update GNOME ext manifest | `mise run update:gnome-extensions` |
| COSMIC DE setup         | `mise run setup:cosmic`          |
| Set COSMIC theme        | `mise run setup:cosmic-theme`    |
| Delete cached themes    | `mise run setup:cosmic-theme-clean` |
| Install/update tools    | `mise run install:*`             |
| Verify stow conflicts   | `stow -nv -t ~ <package>`        |

## Key Patterns

- **Modular via Stow:** Each tool in its own package; deploy selectively
- **Uniform tag layout:** All packages use `tag-*` subdirectories (e.g. `bash/tag-default/`; a device-specific variant would live at `<package>/tag-laptop/`). Deployed based on `.device-tag` with fallback to `tag-default/`
- **Graphical detection:** Ghostty and GNOME extensions installation checks for graphical environment (`$DISPLAY`, `$WAYLAND_DISPLAY`, etc.) instead of device type. Override via `.graphical-env` (accepted values: `graphical`/`yes` to force-enable, `server`/`none`/`no` to force-disable)
- **Desktop environment detection:** DE-specific packages (GNOME themes, extensions) are auto-excluded when not on the matching DE. Detection via `.desktop-env` override → `$XDG_CURRENT_DESKTOP` → binary/directory fallback. Accepted `.desktop-env` values: `gnome`, `cosmic`, `unknown` (with `none`/`server`/`headless` aliased to `unknown`). Helpers: `is_gnome()`, `is_cosmic()` in `helpers.sh`
- **Non-interactive mode:** Set `DOTFILES_NONINTERACTIVE=1` to make `init` and every task it triggers skip prompts and pick safe defaults — required for automated installs (CI, provisioning, `curl | bash`-style flows). Honored by `init`, `setup:zsh` (Phase 6 hostname), `setup:p10k-icon`, `setup:p10k-configure`, `setup:device-tag`, `setup:exclude`, `setup:mise-conf-exclude`, `setup:install-exclude`, `setup:custom-dotfiles`, `install:ghostty` (defaults to `deb`; override via `GHOSTTY_INSTALL_METHOD`), and `install:obsidian` (installs when a graphical env is detected, skips on a headless host). Without this flag, `init` runs `bootstrap` only after a user confirmation prompt; with it, the run is fully unattended. The Step 0 GitHub token check warns (rather than aborts) under this mode so unattended runs can still proceed best-effort
- **Media tools (ffmpeg, imagemagick):** Installed by `install:media-tools` (a `bootstrap` dep), not via the asdf plugin defaults — those compile from source for 10-20 minutes each. Strategy: try `sudo apt-get install -y ffmpeg imagemagick` first (small, integrated); if no sudo, fall back to mise `ubi:` static binaries from `BtbN/FFmpeg-Builds` and `ImageMagick/ImageMagick`. Static binaries don't ship shared libs — fine for shell consumers (yazi, scripts), would break linkers
- **Per-machine exclusions:** Three parallel gitignored opt-out files, each managed by its own `setup:*` task. (1) `.stow-exclude` lists stow packages to skip; managed by `setup:exclude`. (2) `.mise-conf-exclude` lists `mise/.config/mise/conf.d/*.toml` tool groups to skip — `init` prompts for these in Step 1.5, *before* it stows mise, so excluded conf files are never symlinked and `mise install` later in `bootstrap` never sees them; re-runnable via `setup:mise-conf-exclude` (followed by `setup:dotfiles` to re-stow); `runtime.toml` is protected (always kept) because language runtimes are pre-installed via `bootstrap`'s `install:runtimes` dependency. (3) `.install-exclude` lists standalone `install:<key>` app/CLI tasks to skip (`obsidian`, `ghostty`, `veracrypt`, `pathpicker`) — managed by `setup:install-exclude`, and each opt-out-able task checks `is_install_excluded <key>` early and exits cleanly when listed; `install:obsidian`'s decline prompt also writes its key here. The exclusion vocabulary lives in `helpers.sh` (`INSTALL_OPTOUT_KEYS`/`INSTALL_OPTOUT_DESCS`). The first two files are honored by `setup:dotfiles`
- **Custom packages:** Users can add their own config packages in a sibling directory (`~/.dotfiles-custom/`) via `setup:custom-dotfiles`. Tracked in `.custom-packages` (INI-style with `[name:tag]` sections). Custom packages are tag-aware and immune to `.stow-exclude`. See [CUSTOM-PACKAGES.md](CUSTOM-PACKAGES.md)
- **XDG compliance:** Configs use `~/.config/` for tool-specific settings
- **Task-driven:** All setup automation flows through Mise
- **Nested Stow:** Mise config itself is stowed, enabling config management of the manager

See `.claude/docs/architectural_patterns.md` for detailed pattern documentation.

## Additional Documentation

- [Architectural Patterns](.claude/docs/architectural_patterns.md) — Stow packages, Mise tasks, device configs
- [Tools Setup](.claude/docs/tools_setup.md) — Runtime installation, CLI integrations
- [Custom Packages](CUSTOM-PACKAGES.md) — Adding your own config packages on a sibling directory (`~/.dotfiles-custom`)
- [Troubleshooting](.claude/docs/troubleshooting.md) — Common stow conflicts, missing dependencies

## Working with Claude

**Before starting any non-trivial task**, create a task list with `TaskCreate` to track the steps. Mark each task `in_progress` when you begin it and `completed` when done.

**Before committing or pushing any change under `.mise/tasks/` or `mise/tag-default/.config/mise/tasks/`, run `mise run lint`.** It runs `shellcheck --severity=warning` and `shfmt -d -i 4 -ci -bn` against the exact same file set as `.github/workflows/ci.yml`, so passing locally means passing in CI. The task auto-downloads the CI-pinned `shfmt` (v3.10.0) to `~/.cache/dotfiles-lint/` on first run. **Never push without a clean `mise run lint`.** If a lint fails on a message you intended to contain literal tokens like `~/...` (tilde as display text, not a path), suppress with an inline `# shellcheck disable=<code>` comment that names the rule and explains why — don't rewrite the message.

**Always include a final task in the list:** "Update docs if needed" — this must be the last task before closing out. When you reach it, reflect on whether the changes affect any of:

- `CLAUDE.md` (project overview, patterns, commands)
- `.claude/docs/architectural_patterns.md` (design patterns)
- `.claude/docs/tools_setup.md` (tool configs, integrations)
- `.claude/docs/troubleshooting.md` (common issues)

If a doc update is needed, **ask the user for confirmation before modifying any documentation files**. Do not update docs silently.
