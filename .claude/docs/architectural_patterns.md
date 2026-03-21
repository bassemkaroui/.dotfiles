# Architectural Patterns

## Stow-Based Modular Organization

**Pattern:** Each tool/config category is a Stow "package" that independently mirrors the home directory structure.

**Implementation:**
- Package: `zsh/.zshrc` → Deployed as `~/.zshrc`
- Package: `bat/.config/bat/config` → Deployed as `~/.config/bat/config`
- Selective deployment: `stow -t ~ bash zsh` deploys only Bash and Zsh configs; others remain unchanged

**Benefits:**
- No file duplication across packages
- Selective deployment (install only needed configs)
- Easy rollback (uninstall one package without touching others)
- Clean version control (native git paths match deployed paths)

**Conflict handling:** `setup:dotfiles` automatically backs up existing files/directories (`.bak` suffix) before stowing. It distinguishes shared directories (e.g., `~/.config`, `~/.gnupg`) from package-owned directories (e.g., `~/.config/yazi`) — shared dirs are descended into, package-owned dirs are backed up as a whole.

**When applying:** Use Stow for any new tool/service config. Follow directory structure that mirrors `~/.` paths.

---

## Mise Task Automation

**Pattern:** Hierarchical task organization under `.config/mise/tasks/` with root-level orchestration in `.mise.toml`.

**Structure:**
```
.config/mise/tasks/
├── install/
│   ├── stow.sh       # Bootstrap stow installation
│   ├── nala.sh       # Package manager
│   ├── runtimes.sh   # Rust, Go, Node via mise
│   └── ...
├── setup/
│   ├── zsh.sh        # Oh-my-zsh + plugins + p10k
│   ├── dotfiles.sh   # Stow all packages
│   ├── shell-tools.sh  # Fzf, zoxide, bat integrations
│   └── ...
└── (root tasks in .mise.toml)
```

**Execution flow:**
1. `mise run init` — Bootstrap entry point (user-facing)
2. `mise run bootstrap` — Runs install/* then setup/* in sequence
3. Individual tasks: `mise run setup:zsh`, `mise run install:runtimes`

**Benefits:**
- Single entry point for new machines
- Idempotent tasks (safe to re-run)
- Self-documenting (task names match responsibilities)
- Hierarchical grouping prevents command clutter

**When applying:** Create task files for repeatable setup steps. Use `setup:*` for post-install configuration, `install:*` for tool installation.

---

## Device-Specific Configurations

**Pattern:** Hardware/device variants (laptop vs. desktop) co-exist in the same Stow package and are selected during setup. The detected device type is persisted for future runs.

**Implementation:**
```
p10k/
├── laptop/
│   └── .p10k.zsh       # Minimal prompt (resource-constrained)
├── desktop/
│   └── .p10k.zsh       # Full-featured prompt
└── (shared p10k config if any)
```

**Device-specific packages** are defined as a data-driven array in `setup:dotfiles`:
```bash
DEVICE_PACKAGES=(ssh p10k)
```
To add a new device-variant package, create `<package>/laptop/` and `<package>/desktop/` subdirectories, then append the package name to this array.

**Selection logic (priority order):**
1. `DOTFILES_DEVICE` environment variable (explicit override)
2. `.device-type` file in repo root (persisted from previous run)
3. Auto-detection via `/sys/class/power_supply/BAT*` (battery = laptop, otherwise desktop)
4. Interactive prompt to confirm or change

After detection, the result is persisted to `.dotfiles/.device-type` (git-ignored) so subsequent runs skip detection entirely.

**Same pattern in:**
- `ssh/laptop/` vs. `ssh/desktop/` — Different SSH key paths/configs per device
- Mise config allows hardware-specific tool choices (e.g., ARM vs. x86)

**Benefits:**
- Single repo for all machines
- No branch switching or manual selection
- Config changes sync across devices but preserve device-specific overrides
- Persisted device type eliminates repeated prompts on re-runs

**When applying:** Use for configs that vary by hardware, OS, or environment (SSH keys, display settings, resource limits).

---

## Nested Stow (Meta-Configuration)

**Pattern:** The Mise tool itself is configured via a Stow package (`mise/`), enabling version control of the task automation system.

**Implementation:**
- `mise/.config/mise/config.toml` → Stowed as `~/.config/mise/config.toml` (Mise's own config)
- `mise/.config/mise/tasks/` → Stowed as `~/.config/mise/tasks/` (Task definitions)

**Benefit:** Mise configuration is version-controlled alongside other dotfiles; updates to Mise tasks propagate via normal git workflow.

**When applying:** Extend this pattern if you manage other manager tools (Docker, Nix, etc.) — give them their own Stow packages so their configs are tracked.

---

## XDG Base Directory Specification Compliance

**Pattern:** Tool configs use XDG paths to centralize configuration under `~/.config/` and data under `~/.local/share/`.

**Implementation:**
```
bat/.config/bat/config → ~/.config/bat/config
yazi/.config/yazi/yazi.toml → ~/.config/yazi/yazi.toml
tmux/.config/tmux/tmux.conf → ~/.config/tmux/tmux.conf
```

**Benefits:**
- Consistent organization across all tools
- Easy to backup/sync `~/.config/` and `~/.local/share/`
- Respects user home directory conventions
- Simplifies shell integrations (tools follow standard paths)

**When applying:** Always deploy configs to XDG-compliant locations. Verify tools support `XDG_CONFIG_HOME` environment variable before assuming they follow the spec.

---

## External Dependencies via Submodules

**Pattern:** External projects (e.g., oh-my-tmux) are integrated as git submodules, ensuring version pinning and easy updates.

**Current usage:**
- `tmux/.tmux` → Submodule pointing to [oh-my-tmux](https://github.com/gpakosz/.tmux)
- Deployed as `~/.config/tmux/` after stowing

**Update flow:**
- `git submodule update --remote` updates to latest
- `mise run update:oh-my-tmux` — Wrapper task for user-friendly updates

**Benefits:**
- Pinned versions (reproducible setups)
- Updates tracked in git history
- Submodule can be maintained separately

**When applying:** Use for stable, actively-maintained external projects. Avoid for frequently-changing tools or libraries.

---

## Package Manager Abstraction

**Pattern:** Tool installation attempts multiple package managers in fallback sequence: nala → apt → dnf → pacman → source build.

**Implementation:**
Tasks like `install:nala`, `install:runtimes` use conditional logic:
```bash
if command -v nala >/dev/null; then
  nala install package
elif command -v apt >/dev/null; then
  apt-get install package
elif command -v dnf >/dev/null; then
  dnf install package
# ... etc
```

**Benefits:**
- Single dotfiles repo works across Debian, Fedora, Arch, Ubuntu, etc.
- Graceful degradation if package manager unavailable
- Source builds as last resort for tools not in package repos

**When applying:** Use for cross-distro dotfiles. Test fallback paths on target systems.
