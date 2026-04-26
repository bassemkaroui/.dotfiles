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

**Per-machine mise tool exclusions:** A parallel gitignored `.mise-conf-exclude` lets you skip individual `mise/tag-default/.config/mise/conf.d/*.toml` files on a given machine — e.g. drop the `ai.toml` group on a server, the `net.toml` group on a sandbox. Managed by `setup:mise-conf-exclude` (same `[a]dd`/`[r]emove` UX as `setup:exclude`), which auto-discovers available files from the repo's `conf.d/` directory. The exclusion prompt runs **inside `init`** (Step 1.5), *before* mise is stowed, so the choice is captured early enough to matter; the same task is also re-runnable later as `mise run setup:mise-conf-exclude`. Enforcement happens at stow time: when stowing the `mise` package, `setup:dotfiles` (and `mise/tasks/init`) builds a `--ignore=^<file>$` flag per excluded entry, so excluded conf files never get symlinked into `~/.config/mise/conf.d/` and the subsequent `mise install` simply doesn't see them. Restow (`stow -R`) reconciles the deployed state automatically when the exclusion set grows or shrinks. `runtime.toml` is treated as protected (`MISE_CONF_PROTECTED` in `helpers.sh`): it's hidden from the exclude UI and silently dropped from `.mise-conf-exclude` if hand-edited in, because language runtimes are always-on via `bootstrap`'s `install:runtimes` dependency.

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

## Host-Specific Overlays via `include-local`

**Pattern:** For files that need only a few host-specific lines on top of an otherwise-shared config, commit the shared part and have it `include` a gitignored `~/.<name>.local` sibling. The tool silently skips the include if the file is absent, so a bare machine works out of the box and gains the overlay only when the local file is populated.

**Why not tags?** Tag-based variants (above) require duplicating the whole file per variant. When 95% of the content is shared and only 5% varies, `include-local` avoids the duplication and keeps the shared content authoritative.

**Implementation (git signing, the reference case):**
```gitconfig
# ~/.gitconfig (committed, shared)
[user]
  name = Bassem Karoui
  email = bassem.karoui1@gmail.com
# ... all shared settings ...
[include]
  path = ~/.gitconfig.local      # silently skipped if missing
```
```gitconfig
# ~/.gitconfig.local (generated, never committed, populated only when the
# required resource — here, a GPG secret key — is available on this machine)
[user]
  signingkey = F7FA37710715D6E5
[commit]
  gpgsign = true
[tag]
  gpgSign = true
```

**Bootstrap flow:**
1. Ship a committed template `<name>.local.example` alongside the shared file (stowed normally, becomes `~/<name>.local.example`).
2. A mise task (`setup:git-signing` is the reference) detects whether the prerequisite is satisfied (e.g., `gpg --list-secret-keys <id>`) and copies the template into place as `~/<name>.local` — only if it doesn't already exist (idempotent, never clobbers manual edits).
3. Wire the task via `#MISE depends_post=["setup:<name>-local"]` on `setup:dotfiles` so re-stowing automatically re-runs the install check.

**Which tools support this natively:** git (`[include]`), ssh (`Include ~/.ssh/config.d/*`), zsh/bash (`[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local`; the same pattern is used for `~/.p10k.local.zsh`, sourced from `~/.zshrc` after `~/.p10k.zsh` to overlay per-machine prompt tweaks like the OS icon), tmux (`source-file -q`). For tools without native include support, either switch to tag-based variants or introduce a templating layer (not currently used in this repo).

**Defensive gitignore:** `*.local` is ignored in `.dotfiles-custom/.gitignore` so that a stray `.local` file placed inside a package directory by mistake doesn't get committed.

**When applying:** Use when a file's machine-specific variation is small (a handful of keys/lines) and the underlying tool supports includes. For whole-file variance (e.g., `ssh/tag-laptop/.ssh/config` vs `ssh/tag-desktop/.ssh/config`), keep using tags.

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

## Desktop Environment Detection

**Pattern:** DE-specific packages (e.g., GNOME themes, GNOME extensions) are conditionally deployed based on the detected desktop environment. This is separate from the graphical environment check — a system can be graphical but running COSMIC instead of GNOME.

**Detection checks (in order):**
1. `.desktop-env` pin file (gitignored) — `gnome`, `cosmic`, or `unknown`
2. `$XDG_CURRENT_DESKTOP` environment variable (case-insensitive, handles colon-separated values like `pop:GNOME`)
3. Binary/directory presence fallback — `gnome-shell` binary → GNOME; `~/.config/cosmic/` directory → COSMIC

**Helper functions** (in `helpers.sh`):
- `detect_desktop_env()` — Sets `DESKTOP_ENV` global (cached after first call)
- `is_gnome()` / `is_cosmic()` — Convenience wrappers returning 0/1

**How it affects deployment:**
- `setup:dotfiles` auto-excludes `gnome_themes` when not on GNOME (separate from `.stow-exclude`, which is user-managed)
- `install:gnome-extensions` and `update:gnome-extensions` skip when not on GNOME
- Auto-excluded packages are also unstowed if previously deployed (e.g., after switching from GNOME to COSMIC)

**When applying:** Use `is_gnome()` / `is_cosmic()` guards for any DE-specific tool or config. To add a future COSMIC-only package, add a `! is_cosmic` check in `setup:dotfiles` following the same pattern as `gnome_themes`.

---

## COSMIC Desktop Setup

**Pattern:** Umbrella task for all COSMIC-specific setup: prerequisites first, then interactive theme configuration.

**Task:** `setup:cosmic` — runs during bootstrap (after `install:gnome-extensions`), guarded by `is_cosmic()`. Delegates to `setup:cosmic-theme` after prerequisites are satisfied.

**Flow:**
1. Detect COSMIC desktop (skips silently on GNOME/other DEs)
2. **Prerequisites:** install `ddcutil` (external monitor brightness control), configure i2c udev rule, add user to `i2c` group, reload udev
3. **Theme setup:** delegates to `setup:cosmic-theme`

**Theme task (`setup:cosmic-theme`):**
1. Present interactive menu with predefined themes + custom search option
2. Query `cosmic-themes.org/api/themes?search=<name>` API (returns JSON with `.ron` content)
3. For custom searches with no exact match, show fuzzy results for user to pick
4. Save `.ron` file to `~/.local/share/cosmic-themes/` cache
5. Apply theme via `cosmic-settings appearance import <ron_file>` for immediate effect

**Key files:**
- `mise/tag-default/.config/mise/tasks/setup/cosmic` — umbrella task (prerequisites + theme)
- `mise/tag-default/.config/mise/tasks/setup/cosmic-theme` — interactive theme task
- `mise/tag-default/.config/mise/tasks/setup/cosmic-theme-clean` — cache cleanup task
- `mise/tag-default/.config/mise/tasks/lib/cosmic_theme_helper.py` — API search and download helper

**COSMIC theme config architecture:**
- Themes use `.ron` (Rusty Object Notation) files
- `cosmic-settings appearance import` handles parsing, writing config entries, and live-reloading the theme (same mechanism the Settings GUI uses)

**When applying:** Add new COSMIC-specific prerequisites to `setup:cosmic` (before the theme delegation). Theme selection is interactive — users can skip to keep their current theme.

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
