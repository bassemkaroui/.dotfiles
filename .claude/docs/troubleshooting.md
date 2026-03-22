# Troubleshooting Guide

## Stow Deployment Issues

### Stow Reports Conflicts

**Error:** `ERROR: stow would cause conflicts`

**Common causes:**
1. File already exists in home directory (leftover from previous install)
2. Symlink points elsewhere (conflicting stow operation)
3. Directory expected but file exists (or vice versa)

**Automatic handling:** `mise run setup:dotfiles` automatically backs up conflicting files/directories with a `.bak` suffix before stowing. It descends through shared directories (e.g., `~/.config`, `~/.gnupg`) and only backs up package-specific entries, so system directories with unrelated content are preserved.

**Manual resolution** (when running `stow` directly):
```bash
# Dry-run to see conflicts
stow -nv -t ~ <package>

# Inspect existing file
ls -la ~/.zshrc           # Check if symlink or regular file

# Remove conflicting file (if safe)
rm ~/.zshrc              # Or backup first: mv ~/.zshrc ~/.zshrc.bak

# Retry stow
stow -t ~ zsh
```

### Stow Symlinks Broken After Update

**Cause:** Git operations (reset, rebase) changed symlink targets, or package contents changed (files added/removed/moved)

**Automatic resolution:** Re-running `mise run setup:dotfiles` handles this — it uses `stow -R` (restow) which removes all existing package symlinks and recreates them from the current package state.

**Manual resolution** (for individual packages):
```bash
# Restow affected packages (removes old symlinks, creates new ones)
stow -R -t ~ zsh bash

# Or the equivalent two-step if you need more control
stow -D -t ~ zsh bash    # Delete
stow -t ~ zsh bash        # Reinstall
```

### Selective Unstow

**To remove only one device variant:**
```bash
# Remove laptop variant while keeping shared configs
stow -D -t ~ -S laptop   # From p10k/ or ssh/
```

---

## Mise Task Failures

### `mise run init` Fails on Stow Installation

**Likely cause:** Missing build dependencies or package manager unavailable

**Check:**
```bash
which stow              # Is stow already installed?
which apt               # Is apt/nala/dnf available?
gcc --version          # C compiler available? (needed to build stow)
```

**Manual stow installation:**
```bash
# Debian/Ubuntu
sudo apt-get install stow

# Fedora
sudo dnf install stow

# Arch
sudo pacman -S stow
```

### `mise run bootstrap` Hangs

**Likely cause:** Task waiting for interactive input (password prompt, confirmation)

**Check:**
- Sudoers configured for passwordless package manager (`nala`, `apt`)
- No interactive prompts in task scripts

**Workaround:** Run tasks individually to identify blocker
```bash
mise run install:stow
mise run install:nala
mise run install:runtimes  # May need passwordless sudo
```

### Wrong Device Type Detected or Persisted

**Cause:** Auto-detection picked the wrong type, or `.device-type` was persisted from a previous run on different hardware.

**Resolution:**
```bash
# Delete persisted device type and re-run
rm ~/.dotfiles/.device-type
mise run setup:dotfiles

# Or override via environment variable
DOTFILES_DEVICE=laptop mise run setup:dotfiles
```

### Runtimes Not Found After `mise run install:runtimes`

**Check:**
```bash
mise ls                      # List installed tools
which rustc                  # In PATH?
$PATH | grep .mise          # Mise bin directory in PATH?
```

**Cause:** Shell hasn't reloaded after mise activation

**Resolution:**
```bash
# Reload shell to pick up new PATH
exec zsh

# Or source mise directly
eval "$(mise activate zsh)"
source ~/.zshrc
```

---

## Shell Configuration Issues

### Zsh Won't Start After Dotfiles Deployment

**Likely cause:** Syntax error in `.zshrc` or sourced files

**Debug:**
```bash
# Check for syntax errors
zsh -n ~/.zshrc

# Start with minimal config
zsh -f   # Ignore all configs

# Incrementally source files to find culprit
source ~/.zshrc
```

### Powerlevel10k Prompt Looks Broken or Wrong

**Common causes:**
1. Missing Nerd Font (displays fallback characters)
2. P10k cache stale or incompatible with new version
3. Device variant not applied (using shared config instead of laptop/desktop)

**Resolution:**
```bash
# Regenerate p10k config
p10k configure         # Interactive wizard

# Clear cached instant prompt
rm -rf ~/.cache/p10k*  # Regenerate on next shell start

# Verify correct device variant stowed
ls -la ~/.p10k.zsh     # Check symlink target
```

### Fzf Integration Not Working

**Check:**
```bash
fzf --version          # Is fzf installed?
echo $FZF_BASE         # Should point to fzf directory
```

**If missing:**
```bash
# Re-run setup
mise run setup:shell-tools

# Or manually trigger fzf install
mise install fzf
```

### Zoxide or Bat Not Found

**Check:**
```bash
mise ls zoxide         # Installed?
zoxide --version       # In PATH?
eval "$(zoxide init zsh)"  # Try initializing
```

---

## Git Configuration Issues

### Delta (Git Diff Pager) Not Showing

**Cause:** `git config` not pointing to delta, or delta not installed

**Check:**
```bash
git config --global core.pager     # Should be 'delta'
which delta                        # Installed?
delta --version
```

**Reset git config from dotfiles:**
```bash
stow -D -t ~ git     # Unlink
stow -t ~ git        # Relink (redeploy config)
```

### SSH Keys Not Found

**Check:**
```bash
ls -la ~/.ssh/            # Keys exist?
ssh-add -l                # Loaded in agent?
ssh-agent                 # Running?
```

**Device-specific SSH config:**
```bash
cat ~/.ssh/config         # Check symlink target
# Should point to laptop/ or desktop/ variant
```

---

## Package Manager Fallbacks

### Tool Installation Via Package Manager Fails

**Stow of mis/e.toml includes fallback logic:**
1. Tries `nala` (faster apt wrapper)
2. Falls back to `apt`, `dnf`, `pacman` in sequence
3. Attempts source build as last resort

**If source build fails:**
- Check build tool availability: `gcc`, `make`, `git`
- Check for tool-specific dependencies documented in install task
- Manually build from source in `/tmp` for debugging

**Example — Stow from source:**
```bash
git clone https://git.savannah.gnu.org/git/stow.git
cd stow && ./bootstrap && ./configure && make && sudo make install
```

---

## Performance & System Issues

### First Bootstrap Takes Very Long

**Expected:** 10+ minutes for full install (depends on internet, CPU)

**Bottlenecks:**
- Package manager updates: `sudo apt update`
- Language runtime compilation: Rust, Go from source
- Large downloads: Node.js, Neovim binaries

**Optimization:**
- Pre-install Rust toolchain if available: `rustup`
- Use system Go/Node if versions match requirements
- Run `mise run install:*` tasks individually to skip unnecessary installs

### Shell Startup Slow After Setup

**Likely causes:**
1. Mise activation (`eval "$(mise activate zsh)"`) is slow with many tools
2. Oh-my-zsh plugin loading
3. P10k instant prompt regeneration

**Debug:**
```bash
time zsh -i -c exit    # Measure shell startup
time zsh -f -c exit    # Measure without any config

# Check mise performance
time eval "$(mise activate zsh)"

# Profile .zshrc
zsh -x ~/.zshrc 2>&1 | head -50  # First 50 lines of execution
```

**Optimization:**
- Move non-essential aliases to lazy-loaded function
- Use P10k instant prompt (pre-generated in background)
- Reduce oh-my-zsh plugins to essentials only
