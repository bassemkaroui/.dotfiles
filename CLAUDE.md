# .dotfiles Repository

## Overview

A modular dotfiles management system using **GNU Stow** for clean symlink-based deployment and **Mise** for task automation. Configures a complete development environment across 16 config packages with device-aware (laptop/desktop) variants.

## Tech Stack

| Component | Purpose |
|-----------|---------|
| **Stow** | Symlink farm manager for deploying dotfiles packages |
| **Mise** | Version manager + task runner for setup automation |
| **Zsh** | Primary shell with oh-my-zsh + Powerlevel10k |
| **Runtimes** | Rust, Go, Node.js, Neovim (managed via mise) |
| **CLI Tools** | fzf, ripgrep, fd, yazi, bat, delta, eza, zoxide |

## Project Structure

```
.dotfiles/
├── bash/, zsh/        → Shell configurations
├── git/              → Git config & helpers
├── tmux/             → Tmux (oh-my-tmux submodule)
├── nvim/             → Neovim config (git submodule)
├── p10k/             → Powerlevel10k prompt (laptop/desktop variants)
├── ssh/              → SSH configs (laptop/desktop variants)
├── fzf/, yazi/, bat/ → CLI tool configs
├── gh/, gh-dash/     → GitHub CLI & dashboard configs
├── claude/           → Claude Code IDE config (settings, keybindings, plugins)
├── mise/             → Mise tool config (nested stow)
├── gpg/, gnome_themes/, ruby/ → Additional tools
└── .mise.toml        → Root mise task definitions
```

**Each directory is a Stow package** that mirrors `~/.` structure:
- `bash/.bashrc` → `~/.bashrc` (when stowed)
- `bat/.config/bat/config` → `~/.config/bat/config`

## Quick Start

**First-time setup:**
```bash
git clone --recursive git@github.com:bassemkaroui/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
mise run init           # Installs stow, deploys mise config
mise run bootstrap      # Full machine setup
```

**Manual stow deployment:**
```bash
stow -t ~ bash zsh git tmux fzf yazi bat nvim gh gh-dash claude # Core configs
stow -t ~ mise                            # Mise config
stow -t ~ -S laptop                       # Device-specific (from p10k/, ssh/)
```

## Essential Commands

| Task | Command |
|------|---------|
| Full machine setup | `mise run bootstrap` |
| Deploy/redeploy configs | `mise run setup:dotfiles` |
| Update tmux | `mise run update:oh-my-tmux` |
| Install/update tools | `mise run install:*` |
| Verify stow conflicts | `stow -nv -t ~ <package>` |

## Key Patterns

- **Modular via Stow:** Each tool in its own package; deploy selectively
- **Device-aware:** Laptop/desktop variants in `p10k/` and `ssh/`; auto-detected and persisted to `.device-type`
- **XDG compliance:** Configs use `~/.config/` for tool-specific settings
- **Task-driven:** All setup automation flows through Mise
- **Nested Stow:** Mise config itself is stowed, enabling config management of the manager

See `.claude/docs/architectural_patterns.md` for detailed pattern documentation.

## Additional Documentation

- [Architectural Patterns](.claude/docs/architectural_patterns.md) — Stow packages, Mise tasks, device configs
- [Tools Setup](.claude/docs/tools_setup.md) — Runtime installation, CLI integrations
- [Troubleshooting](.claude/docs/troubleshooting.md) — Common stow conflicts, missing dependencies

## Documentation Maintenance

After completing any code change, reflect on whether the change affects:
- `CLAUDE.md` (project overview, patterns, commands)
- `.claude/docs/architectural_patterns.md` (design patterns)
- `.claude/docs/tools_setup.md` (tool configs, integrations)
- `.claude/docs/troubleshooting.md` (common issues)

If a doc update is needed, **ask the user for confirmation before modifying any documentation files**. Do not update docs silently.
