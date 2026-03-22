# My dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and automated with [mise](https://mise.jdx.dev/).

## Quick Start (New Machine)

1. Install mise:
   ```bash
   curl https://mise.run | sh
   ```

2. Clone this repo (use HTTPS on a new machine — SSH isn't configured yet):
   ```bash
   git clone --recursive https://github.com/bassemkaroui/.dotfiles.git ~/.dotfiles
   cd ~/.dotfiles/tmux/.tmux && git checkout master && cd ~/.dotfiles
   git config submodule.recurse true
   ```

3. Bootstrap everything:
   ```bash
   cd ~/.dotfiles && mise run init
   ```

4. After SSH keys are set up, switch the remote to SSH:
   ```bash
   git -C ~/.dotfiles remote set-url origin git@github.com:bassemkaroui/.dotfiles.git
   ```

> The `setup:dotfiles` task can also clone the repo for you if `~/.dotfiles` doesn't exist yet. It will prompt you to set up SSH auth for GitHub first.

## What Bootstrap Does

1. Installs nala, stow, and runtimes (Rust, Go, Node) in parallel
2. Sets up zsh + oh-my-zsh + powerlevel10k + plugins
3. Installs all mise-managed tools
4. Deploys dotfiles via stow (auto-detects laptop/desktop)
5. Configures shell integrations (fzf, zoxide, bat, etc.)
6. Post-setup: corepack, VeraCrypt

## Manual Stow Usage

### Deploy all dotfiles

```bash
mise run setup:dotfiles
```

### Deploy individual packages

```bash
cd ~/.dotfiles
stow -t ~ bash fzf git gnome_themes gpg zsh tmux bat yazi mise nvim gh gh-dash claude
```

### Device-specific configs (ssh, p10k)

```bash
cd ~/.dotfiles/ssh && stow -t ~ laptop   # or desktop
cd ~/.dotfiles/p10k && stow -t ~ laptop  # or desktop
```

### Dry-run / Unstow

```bash
stow -nv -t ~ bash   # dry-run
stow -D -t ~ zsh     # unstow
```

## Stow Packages

| Package | Contents |
|---------|----------|
| bash | `.bashrc`, `.bash_logout`, `.profile` |
| mise | `.config/mise/` (config, conf.d, tasks) |
| bat | `.config/bat/themes/` (tokyonight) |
| fzf | `.fzf.bash`, `.fzf.zsh` |
| git | `.gitconfig`, `.git-completion.bash`, `.git-prompt.sh`, `.git-template/` |
| gnome_themes | `.themes/` (ChromeOS-dark, WhiteSur-dark) |
| gpg | `.gnupg/gpg-agent.conf` |
| p10k | `.p10k.zsh` (laptop/desktop variants) |
| ssh | `.ssh/config` (laptop/desktop variants) |
| tmux | `.config/tmux/` ([oh-my-tmux](https://github.com/gpakosz/.tmux) submodule) |
| yazi | `.config/yazi/` (config, keymap, plugins, theme) |
| zsh | `.zshrc`, `.zshenv` |
| nvim | `.config/nvim/` (Neovim config — git submodule) |
| gh | `.config/gh/config.yml` (GitHub CLI config) |
| gh-dash | `.config/gh-dash/config.yml` (GitHub dashboard TUI) |
| claude | `.claude/` (Claude Code settings, keybindings, plugins, commands, agents, skills) |

## Mise Tasks

| Task | Description |
|------|-------------|
| `init` | Entry point: install stow, deploy mise config, optionally run bootstrap |
| `bootstrap` | Full machine setup |
| `install:stow` | Install GNU Stow (apt/nala or from source if no sudo) |
| `install:nala` | Install nala apt frontend |
| `install:runtimes` | Install Rust, Go, Node via mise |
| `install:veracrypt` | Install latest VeraCrypt |
| `setup:zsh` | Full zsh environment setup |
| `setup:dotfiles` | Deploy dotfiles via stow (auto-detects device type) |
| `setup:shell-tools` | Configure shell integrations |
| `setup:p10k-configure` | Run p10k configuration wizard |
| `setup:zsh-config` | Configure `.zshrc` with mise integration, plugins, and theme (run after `setup:dotfiles`) |
| `setup:completions` | Set up shell completions directory |
| `setup:nodes-tools` | Enable corepack |
| `update:oh-my-tmux` | Update oh-my-tmux submodule to latest master |

## tmux

Based on [oh-my-tmux](https://github.com/gpakosz/.tmux) (git submodule). Plugins are configured in `tmux.conf.local` but the plugins directory is not tracked. After cloning or pulling new plugin configs, install them inside a tmux session with `<prefix> I`.

To update the submodule to the latest upstream:

```bash
mise run update:oh-my-tmux
```

## References

- [Stow has forever changed the way I manage my dotfiles](https://www.youtube.com/watch?v=y6XCebnB9gs)
- [Sync your .dotfiles with git and GNU Stow](https://www.youtube.com/watch?v=CFzEuBGPPPg)
- [Git Submodules Tutorial](https://youtu.be/gSlXo2iLBro)
