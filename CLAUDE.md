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
├── git/              → Git config & helpers (tag-default/)
├── tmux/             → Tmux + oh-my-tmux submodule (tag-default/)
├── nvim/             → Neovim config submodule (tag-default/)
├── p10k/             → Powerlevel10k prompt (tag-default/)
├── ssh/              → SSH configs (tag-desktop/, tag-laptop/)
├── fzf/, yazi/, bat/ → CLI tool configs (tag-default/)
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
mise run init           # Installs stow, deploys mise config
mise run bootstrap      # Full machine setup
```

**Manual stow deployment:**

```bash
stow -d bash -t ~ tag-default              # Deploy a single package (default tag)
stow -d ssh -t ~ tag-laptop                # Deploy a device-specific variant
```

## Essential Commands

| Task                    | Command                          |
| ----------------------- | -------------------------------- |
| Full machine setup      | `mise run bootstrap`             |
| Set/change device tag   | `mise run setup:device-tag`      |
| Manage exclusions       | `mise run setup:exclude`         |
| Manage custom configs   | `mise run setup:custom-dotfiles` |
| Deploy/redeploy configs | `mise run setup:dotfiles`        |
| Update tmux             | `mise run update:oh-my-tmux`     |
| Update GNOME ext manifest | `mise run update:gnome-extensions` |
| Set COSMIC theme        | `mise run setup:cosmic-theme`    |
| Delete cached themes    | `mise run setup:cosmic-theme-clean` |
| Install/update tools    | `mise run install:*`             |
| Verify stow conflicts   | `stow -nv -t ~ <package>`        |

## Key Patterns

- **Modular via Stow:** Each tool in its own package; deploy selectively
- **Uniform tag layout:** All packages use `tag-*` subdirectories (e.g., `bash/tag-default/`, `ssh/tag-laptop/`). Deployed based on `.device-tag` with fallback to `tag-default/`
- **Graphical detection:** Ghostty and GNOME extensions installation checks for graphical environment (`$DISPLAY`, `$WAYLAND_DISPLAY`, etc.) instead of device type. Override via `.graphical-env`
- **Desktop environment detection:** DE-specific packages (GNOME themes, extensions) are auto-excluded when not on the matching DE. Detection via `.desktop-env` override → `$XDG_CURRENT_DESKTOP` → binary/directory fallback. Helpers: `is_gnome()`, `is_cosmic()` in `helpers.sh`
- **Per-machine exclusions:** `.stow-exclude` (gitignored) lists packages to skip on a specific machine; managed interactively by `setup:dotfiles`
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

**Always include a final task in the list:** "Update docs if needed" — this must be the last task before closing out. When you reach it, reflect on whether the changes affect any of:

- `CLAUDE.md` (project overview, patterns, commands)
- `.claude/docs/architectural_patterns.md` (design patterns)
- `.claude/docs/tools_setup.md` (tool configs, integrations)
- `.claude/docs/troubleshooting.md` (common issues)

If a doc update is needed, **ask the user for confirmation before modifying any documentation files**. Do not update docs silently.
