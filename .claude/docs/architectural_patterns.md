# Architectural Patterns

## Stow-Based Modular Organization

**Pattern:** Each tool/config category is a Stow "package" with `tag-*` subdirectories that mirror the home directory structure.

**Implementation:**
- Package: `zsh/tag-default/.zshrc` → Deployed as `~/.zshrc`
- Package: `bat/tag-default/.config/bat/themes/...` → Deployed as `~/.config/bat/themes/...`
- Selective deployment: `stow -d bash -t ~ tag-default` deploys only a single package

**Benefits:**
- No file duplication across packages
- Selective deployment (install only needed configs)
- Easy rollback (uninstall one package without touching others)
- Clean version control (native git paths match deployed paths)

**Conflict handling:** `setup:dotfiles` automatically backs up existing files/directories (`.bak` suffix) before stowing. It distinguishes shared directories (e.g., `~/.config`, `~/.gnupg`) from package-owned directories (e.g., `~/.config/yazi`) — shared dirs are descended into, package-owned dirs are backed up as a whole.

**Per-machine exclusions:** A gitignored `.stow-exclude` file at the repo root lets you skip packages on specific machines. The dedicated `setup:exclude` task creates this file automatically on first run and prompts interactively to add or remove exclusions. When a package is newly excluded, its symlinks are removed via `stow -D` and any previously-backed-up files are restored. The file format is one package name per line, with `#` comments supported. Excluded default packages can be overridden by custom packages of the same name (see Custom Packages Extension).

**When applying:** Use Stow for any new tool/service config. Follow directory structure that mirrors `~/.` paths.

---

## Mise Task Automation

**Pattern:** Hierarchical task organization under `.config/mise/tasks/` with root-level orchestration in `.mise.toml`.

**Structure:**
```
.config/mise/tasks/
├── install/
│   ├── build-deps    # System build dependencies (apt packages)
│   ├── stow          # Bootstrap stow installation
│   ├── nala          # Package manager
│   ├── runtimes      # Rust, Go, Node via mise
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

## Tag-Based Device Configurations

**Pattern:** All packages use `tag-*` subdirectories for their config files. The device tag (persisted in `.device-tag`) selects which variant to deploy, with `tag-default/` as the universal fallback.

**Implementation:**
```
bash/                     # Single-variant package
└── tag-default/
    └── .bashrc

ssh/                      # Multi-variant package (no default fallback)
├── tag-desktop/
│   └── .ssh/config      # Desktop SSH config
└── tag-laptop/
    └── .ssh/config      # Laptop SSH config
```

To add a new tagged variant, create `<package>/tag-<tag>/` subdirectories with the appropriate config files. Most packages only need `tag-default/`.

**Tag resolution logic:**
1. `DOTFILES_TAG` environment variable (explicit override)
2. `.device-tag` file in repo root (persisted from previous run)
3. Interactive prompt (default: "default")

**Package resolution (per tagged package):**
1. If `<package>/tag-$DEVICE_TAG/` exists → stow that
2. Else if `<package>/tag-default/` exists → fallback to that
3. Else → skip (package not deployed on this machine)

After resolution, the tag is persisted to `.dotfiles/.device-tag` (git-ignored). On subsequent runs, the current tag is displayed and the user is offered to change it. Changing the tag automatically migrates custom packages tagged with the old tag (unstows, renames `tag-<old>/` → `tag-<new>/`, updates `.custom-packages`). Tags must match `[a-zA-Z0-9_-]+`.

**Same pattern in:**
- `ssh/tag-desktop/` vs. `ssh/tag-laptop/` — Different SSH key paths/configs per device

**Benefits:**
- Single repo for all machines
- Free-form tags (not limited to laptop/desktop) — use "work", "personal", "server", etc.
- `tag-default` provides a universal fallback
- Config changes sync across devices but preserve device-specific overrides
- Persisted tag eliminates repeated prompts on re-runs

**When applying:** Use for configs that vary by machine role, environment, or hardware. Create `tag-*` subdirectories in any package.

---

## Graphical Environment Detection

**Pattern:** GUI tool installation (e.g., Ghostty, GNOME extensions) checks for a graphical environment rather than relying on device type. This is separate from the tag system.

**Detection checks (in order):**
1. `.graphical-env` pin file — `graphical` forces yes, `server`/`none` forces skip
2. `$DISPLAY` or `$WAYLAND_DISPLAY` environment variables
3. `$XDG_SESSION_TYPE` (`x11` or `wayland`)
4. `loginctl show-session` Type property

**When applying:** Use for any tool that only makes sense in a graphical environment. Always confirm with the user before installing.

---

## Custom Packages Extension

**Pattern:** Users can add their own config packages in a sibling directory (`~/.dotfiles-custom/`), tracked via an INI-style `.custom-packages` file with `[name:tag]` composite section headers. Custom packages are tag-aware and integrate with the existing stow deployment pipeline but live entirely outside the main dotfiles repo.

**Implementation:**
- `setup:custom-dotfiles` task manages the lifecycle (add/remove/verify)
- Custom packages live in `~/.dotfiles-custom/` (override via `DOTFILES_CUSTOM_DIR` env var)
- `.custom-packages` (INI format) inside the sibling dir uses `[name:tag]` sections (bare `[name]` = `tag=default`)
- Each entry tracks: source path, type (full/partial), and recurse_dirs
- The sibling directory can optionally be its own git repo (auto-commits are conditional on `.git` existing)
- `setup:dotfiles` loads `.custom-packages` at startup, extending `CUSTOM_PACKAGES`, `CUSTOM_PKG_TAGS`, and `RECURSE_DIRS` arrays
- Deployment uses `stow -d ~/.dotfiles-custom/<pkg> -t ~ tag-<tag>` to stow tagged variants

**Directory layout:**
```
~/.dotfiles-custom/
  alacritty/
    tag-work/
      .config/alacritty/alacritty.toml
    tag-personal/
      .config/alacritty/alacritty.toml
```

**Add workflow:**
1. Ensure sibling directory exists (create + optional `git init` if needed)
2. Read current `.device-tag` to determine the tag for this variant
3. If `(package, tag)` already exists → warn and bail
4. Copy config into tagged stow layout (`<name>/tag-<tag>/<home-relative-path>/`)
5. For partial directories: only selected items are copied; parent dir added to `RECURSE_DIRS`
6. Update `.custom-packages` with `[name:tag]` entry, auto-commit (if git repo)
7. Stowing and backup handled by `setup:dotfiles` on next run

**Remove workflow:**
1. Unstow tagged variant via `stow -D`, restore `.bak` backups
2. Remove `tag-<tag>/` directory from the package
3. If no tagged variants remain → remove entire package directory
4. Update `.custom-packages`, auto-commit (if git repo)

**Tag resolution during deployment:**
- Same logic as main packages: exact tag match → `tag-default` fallback → skip
- If multiple entries exist for the same package, the exact tag match takes priority over default

**Integration with stow-exclude:**
- Custom packages can override excluded default packages: if a default package (e.g., `p10k`) is in `.stow-exclude`, a custom package with the same name is allowed
- When adding a custom package that conflicts with a non-excluded default, the user is prompted to add the default to `.stow-exclude`
- Custom packages already in `.stow-exclude` are hidden from the exclusion UI (they can't be offered for exclusion since they live in the custom directory)

**Benefits over branch-based approach:**
- Custom packages always present regardless of git state on main repo
- No branch-switching mental overhead
- Each machine has its own independent custom directory with its own tagged variants
- Main repo stays pristine for upstream updates

**When applying:** Use `setup:custom-dotfiles` to manage any config not covered by default packages. See [CUSTOM-PACKAGES.md](../../CUSTOM-PACKAGES.md) for user-facing docs.

---

## Nested Stow (Meta-Configuration)

**Pattern:** The Mise tool itself is configured via a Stow package (`mise/`), enabling version control of the task automation system.

**Implementation:**
- `mise/tag-default/.config/mise/config.toml` → Stowed as `~/.config/mise/config.toml` (Mise's own config)
- `mise/tag-default/.config/mise/tasks/` → Stowed as `~/.config/mise/tasks/` (Task definitions)

**Benefit:** Mise configuration is version-controlled alongside other dotfiles; updates to Mise tasks propagate via normal git workflow.

**When applying:** Extend this pattern if you manage other manager tools (Docker, Nix, etc.) — give them their own Stow packages so their configs are tracked.

---

## XDG Base Directory Specification Compliance

**Pattern:** Tool configs use XDG paths to centralize configuration under `~/.config/` and data under `~/.local/share/`.

**Implementation:**
```
bat/tag-default/.config/bat/themes/... → ~/.config/bat/themes/...
yazi/tag-default/.config/yazi/yazi.toml → ~/.config/yazi/yazi.toml
tmux/tag-default/.config/tmux/tmux.conf → ~/.config/tmux/tmux.conf
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
- `tmux/tag-default/.tmux` → Submodule pointing to [oh-my-tmux](https://github.com/gpakosz/.tmux)
- Deployed as `~/.tmux` after stowing
- `nvim/tag-default/.config/nvim` → Submodule pointing to personal Neovim config
- Deployed as `~/.config/nvim/` after stowing

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

---

## Public Mirror Sync

**Pattern:** The private dotfiles repo is automatically sanitized and synced to a public mirror (`bassemkaroui/dotfiles`) on every push to `main`.

**How it works:**
1. Push to `main` triggers `.github/workflows/sync-public.yml` (GitHub Actions)
2. The workflow runs `scripts/sanitize-and-sync.sh`, which:
   - Exports tracked files and submodule content to a temp directory
   - Removes files listed in `.sanitize.yml` → `exclude_files` (e.g., `.sanitize.yml`, `.claude/`, workflow file, sync script)
   - Applies ordered text replacements from `.sanitize.yml` → `replacements` (personal info → placeholders)
   - Generates a `CUSTOMIZE.md` listing all placeholders for consumers
   - Runs leak detection against `.sanitize.yml` → `leak_patterns`
   - Force-pushes the sanitized result to the public repo

**Key files:**
- `.github/workflows/sync-public.yml` — GitHub Actions workflow
- `scripts/sanitize-and-sync.sh` — Sanitization and push logic
- `.sanitize.yml` — Replacement rules, excluded files, and leak patterns

**Required secret:** `PUBLIC_REPO_PAT` (GitHub PAT with write access to the public repo)

**Local dry-run:** `mise run mirror:dry-run` — sanitizes to `/tmp/dotfiles-sanitized` without pushing

**When applying:** To add new personal data, add a replacement rule in `.sanitize.yml` (longer/more-specific patterns first) and a corresponding leak pattern. To exclude a file from the public mirror, add it to `exclude_files`.
