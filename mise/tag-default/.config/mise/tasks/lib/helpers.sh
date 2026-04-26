# Shared logging helpers for mise tasks.
# Usage: set TASK_NAME before sourcing.
#   TASK_NAME="setup:zsh"
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/helpers.sh"

: "${TASK_NAME:=unknown}"

_pad=18 # column width for task name alignment

info() { printf '\033[1;34m[INFO]\033[0m \033[36m%-*s\033[0m ▸ %s\n' "$_pad" "$TASK_NAME" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m \033[36m%-*s\033[0m ▸ %s\n' "$_pad" "$TASK_NAME" "$*"; }
ok() { printf '\033[1;32m[ OK ]\033[0m \033[36m%-*s\033[0m ▸ %s\n' "$_pad" "$TASK_NAME" "$*"; }
ok_changed() { printf '\033[1;32m[ OK ]\033[0m \033[36m%-*s\033[0m \033[1;32m●\033[0m %s\n' "$_pad" "$TASK_NAME" "$*"; }
fail() {
    printf '\033[1;31m[FAIL]\033[0m \033[36m%-*s\033[0m ▸ %s\n' "$_pad" "$TASK_NAME" "$*"
    exit 1
}

# ─── Shared paths ─────────────────────────────────────────────────────────────

DOTFILES_DIR="$HOME/.dotfiles"
CUSTOM_DIR="${DOTFILES_CUSTOM_DIR:-$HOME/.dotfiles-custom}"
DEVICE_TAG_FILE="$DOTFILES_DIR/.device-tag"
STOW_EXCLUDE_FILE="$DOTFILES_DIR/.stow-exclude"
MISE_CONF_EXCLUDE_FILE="$DOTFILES_DIR/.mise-conf-exclude"
DESKTOP_ENV_FILE="$DOTFILES_DIR/.desktop-env"
CUSTOM_FILE="$CUSTOM_DIR/.custom-packages"

# Canonical list of default stow packages (shared across tasks)
ALL_DEFAULT_PACKAGES=(bash fzf gnome_themes gpg zsh tmux bat yazi mise nvim gh gh-dash claude ghostty p10k)

# ─── GitHub token resolution ─────────────────────────────────────────────────
#
# `mise install` resolves aqua/github/vfox tools by hitting the GitHub releases
# API, which rate-limits unauthenticated callers to 60 req/hr. A fresh bootstrap
# easily blows past that and fails with cryptic 403s. Probe in priority order
# (env first, then `gh auth token`) and export MISE_GITHUB_TOKEN so every
# subsequent `mise install` / `mise run` subprocess inherits it. Caller decides
# whether a missing token is a warn or a hard fail based on interactivity.
#
# Returns 0 if a token was located/exported, 1 otherwise.
ensure_github_token() {
    if [[ -n "${MISE_GITHUB_TOKEN:-}" ]]; then
        ok "GitHub token already set in env (\$MISE_GITHUB_TOKEN)"
        return 0
    fi
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        export MISE_GITHUB_TOKEN="$GITHUB_TOKEN"
        ok "GitHub token loaded from \$GITHUB_TOKEN"
        return 0
    fi
    if [[ -n "${GH_TOKEN:-}" ]]; then
        export MISE_GITHUB_TOKEN="$GH_TOKEN"
        ok "GitHub token loaded from \$GH_TOKEN"
        return 0
    fi
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
        local token
        token="$(gh auth token 2>/dev/null || true)"
        if [[ -n "$token" ]]; then
            export MISE_GITHUB_TOKEN="$token"
            ok "GitHub token loaded from gh CLI"
            return 0
        fi
    fi
    return 1
}

# Interactive recovery path used when ensure_github_token fails and the user
# is at a TTY. Offers to install gh via mise (aqua:cli/cli — single GitHub API
# call, fits in the 60/hr unauth budget), runs `gh auth login`, then re-probes.
# Returns 0 if a token was obtained, 1 if the user declined or auth failed.
# Caller must check DOTFILES_NONINTERACTIVE before calling — this function
# unconditionally prompts.
prompt_github_auth() {
    if ! command -v gh &>/dev/null; then
        read -rp $'\033[1;34m[INFO]\033[0m   Install gh now via mise (aqua:cli/cli) so you can authenticate? [Y/n] ' answer
        if [[ ! "${answer,,}" =~ ^(y|yes|)$ ]]; then
            return 1
        fi
        if ! command -v mise &>/dev/null; then
            warn "mise not on PATH — cannot auto-install gh. Install gh manually and re-run."
            return 1
        fi
        info "Installing gh via mise..."
        if ! mise install gh@latest; then
            warn "gh install failed — set GITHUB_TOKEN manually and re-run"
            return 1
        fi
        local gh_bin
        gh_bin="$(mise which gh 2>/dev/null || true)"
        if [[ -n "$gh_bin" && -x "$gh_bin" ]]; then
            # Make the freshly-installed gh discoverable for the rest of this
            # task (and any child processes that inherit our PATH).
            local gh_dir
            gh_dir="$(dirname "$gh_bin")"
            export PATH="$gh_dir:$PATH"
        fi
        ok_changed "gh installed: ${gh_bin:-$(command -v gh)}"
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        info "Launching 'gh auth login' — follow the prompts (browser or device code)..."
        if ! gh auth login; then
            warn "gh auth login failed or was cancelled"
            return 1
        fi
    fi

    # Reset the cached export so ensure_github_token re-runs the probe chain.
    unset MISE_GITHUB_TOKEN
    ensure_github_token
}

# conf.d files that must not be excluded; user-edited entries pointing at these
# are dropped on read (with a warn) and never persisted on write.
MISE_CONF_PROTECTED=(runtime.toml)

# ─── p10k helpers ─────────────────────────────────────────────────────────────

# Set by prepare_p10k_file() when ~/.p10k.zsh points into $CUSTOM_DIR.
P10K_CUSTOM_TARGET=""

# Prepare ~/.p10k.zsh for in-place modification.
# - Symlink -> main repo: break it (don't modify the default template)
# - Symlink -> custom repo: leave it (writes go through to custom repo)
# - Symlink -> elsewhere: break it with a warning
# - Broken symlink: remove it, return 1
# - Real file: leave as-is
# - Missing: warn and return 1
# Sets P10K_CUSTOM_TARGET to the resolved path if symlink points to custom repo.
prepare_p10k_file() {
    local p10k="$HOME/.p10k.zsh"
    P10K_CUSTOM_TARGET=""

    if [[ -L "$p10k" ]]; then
        local target
        target="$(readlink -f "$p10k" 2>/dev/null || true)"

        if [[ -z "$target" || ! -e "$target" ]]; then
            rm -f "$p10k"
            warn "Removed broken symlink: ~/.p10k.zsh"
            return 1
        fi

        if [[ "$target" == "$CUSTOM_DIR"/* ]]; then
            P10K_CUSTOM_TARGET="$target"
            # shellcheck disable=SC2088 # user-visible path in a display string
            info "~/.p10k.zsh points to custom repo"
        elif [[ "$target" == "$DOTFILES_DIR"/* ]]; then
            cp --remove-destination "$target" "$p10k"
            info "Replaced default-repo symlink with a real file"
        else
            cp --remove-destination "$target" "$p10k"
            warn "Replaced symlink (target: $target) with a real file"
        fi
    elif [[ ! -f "$p10k" ]]; then
        # shellcheck disable=SC2088 # user-visible path in a display string
        warn "~/.p10k.zsh does not exist — run p10k configure to create it"
        return 1
    fi
    return 0
}

# After modifying p10k, sync changes back to custom repo and auto-commit.
# No-op unless P10K_CUSTOM_TARGET was set by prepare_p10k_file().
sync_custom_p10k() {
    [[ -n "$P10K_CUSTOM_TARGET" ]] || return 0

    local p10k="$HOME/.p10k.zsh"

    # If the wizard destroyed the symlink, copy the new file back and re-stow
    if [[ ! -L "$p10k" && -f "$p10k" ]]; then
        cp "$p10k" "$P10K_CUSTOM_TARGET"
        local pkg_dir="$CUSTOM_DIR/p10k"
        local tag_dir
        tag_dir="$(basename "$(dirname "$P10K_CUSTOM_TARGET")")"
        stow -d "$pkg_dir" -t "$HOME" -R "$tag_dir" 2>/dev/null \
            && info "Re-stowed custom p10k symlink" \
            || warn "Could not re-stow p10k — symlink may need manual fix"
    fi

    # Auto-commit if custom dir is a git repo
    if [[ -d "$CUSTOM_DIR/.git" ]]; then
        local changed
        changed="$(git -C "$CUSTOM_DIR" diff --name-only -- 'p10k/' 2>/dev/null || true)"
        if [[ -n "$changed" ]]; then
            git -C "$CUSTOM_DIR" add p10k/
            git -C "$CUSTOM_DIR" commit -m "update p10k config"
            ok_changed "Auto-committed p10k changes to custom repo"
        fi
    fi
}

# ─── Shared utilities ─────────────────────────────────────────────────────────

# Check if a value is in an array
in_array() {
    local needle="$1"
    shift
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Read current exclusions from .stow-exclude (strip comments and blank lines)
read_exclusions() {
    EXCLUDED=()
    [[ -f "$STOW_EXCLUDE_FILE" ]] || return 0
    while IFS= read -r line; do
        line="${line%%#*}" # strip inline comments
        line="${line// /}" # strip spaces
        [[ -z "$line" ]] && continue
        EXCLUDED+=("$line")
    done <"$STOW_EXCLUDE_FILE"
}

# Write exclusions back to file (preserves header comments)
write_exclusions() {
    # Keep only comment/blank lines from original, then append exclusions
    local tmpfile
    tmpfile="$(mktemp)"
    grep -E '^\s*(#|$)' "$STOW_EXCLUDE_FILE" >"$tmpfile" || true
    for pkg in "${EXCLUDED[@]}"; do
        printf '%s\n' "$pkg" >>"$tmpfile"
    done
    mv "$tmpfile" "$STOW_EXCLUDE_FILE"
}

# Read excluded mise conf.d filenames (basenames, e.g. ai.toml).
# Populates MISE_CONF_EXCLUDED. Strips comments and blank lines. Protected
# entries (MISE_CONF_PROTECTED) are dropped with a warn — runtime.toml is
# always-on because language runtimes are pre-installed via install:runtimes.
read_mise_conf_excludes() {
    MISE_CONF_EXCLUDED=()
    [[ -f "$MISE_CONF_EXCLUDE_FILE" ]] || return 0
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -z "$line" ]] && continue
        if in_array "$line" "${MISE_CONF_PROTECTED[@]}"; then
            warn "Ignoring protected entry in $MISE_CONF_EXCLUDE_FILE: $line"
            continue
        fi
        MISE_CONF_EXCLUDED+=("$line")
    done <"$MISE_CONF_EXCLUDE_FILE"
}

# Write MISE_CONF_EXCLUDED back to file (preserves header comments). Protected
# entries are filtered out before writing so the file stays clean.
write_mise_conf_excludes() {
    local tmpfile
    tmpfile="$(mktemp)"
    grep -E '^\s*(#|$)' "$MISE_CONF_EXCLUDE_FILE" >"$tmpfile" || true
    for f in "${MISE_CONF_EXCLUDED[@]}"; do
        in_array "$f" "${MISE_CONF_PROTECTED[@]}" && continue
        printf '%s\n' "$f" >>"$tmpfile"
    done
    mv "$tmpfile" "$MISE_CONF_EXCLUDE_FILE"
}

# ─── Desktop environment detection ──────────────────────────────────────────

# Detect running desktop environment. Sets DESKTOP_ENV to: gnome, cosmic, or unknown.
# Checks .desktop-env override first, then XDG_CURRENT_DESKTOP, then binary presence.
# Accepted .desktop-env override values: gnome, cosmic, unknown. The aliases
# none/server/headless are normalized to "unknown" so DE-conditional tasks
# (gnome_themes, cosmic) cleanly skip on a headless machine — same vocabulary
# as .graphical-env for consistency.
detect_desktop_env() {
    [[ -n "${DESKTOP_ENV:-}" ]] && return 0 # already detected (cached)

    # 1. Override file
    if [[ -f "$DESKTOP_ENV_FILE" ]]; then
        DESKTOP_ENV="$(<"$DESKTOP_ENV_FILE")"
        DESKTOP_ENV="${DESKTOP_ENV,,}"   # lowercase
        DESKTOP_ENV="${DESKTOP_ENV// /}" # strip spaces
        case "$DESKTOP_ENV" in
            none | server | headless) DESKTOP_ENV="unknown" ;;
        esac
        if [[ "$DESKTOP_ENV" =~ ^(gnome|cosmic|unknown)$ ]]; then
            return 0
        fi
        warn "Invalid .desktop-env value '$DESKTOP_ENV' (use gnome|cosmic|unknown|none|server|headless), falling back to auto-detect"
        DESKTOP_ENV=""
    fi

    # 2. XDG_CURRENT_DESKTOP (colon-separated, case-insensitive)
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        local xdg_lower="${XDG_CURRENT_DESKTOP,,}"
        if [[ "$xdg_lower" == *"gnome"* ]]; then
            DESKTOP_ENV="gnome"
            return 0
        elif [[ "$xdg_lower" == *"cosmic"* ]]; then
            DESKTOP_ENV="cosmic"
            return 0
        fi
    fi

    # 3. Binary/directory presence fallback (for SSH sessions, etc.)
    if command -v gnome-shell &>/dev/null; then
        DESKTOP_ENV="gnome"
        return 0
    elif [[ -d "$HOME/.config/cosmic" ]]; then
        DESKTOP_ENV="cosmic"
        return 0
    fi

    DESKTOP_ENV="unknown"
}

is_gnome() {
    detect_desktop_env
    [[ "$DESKTOP_ENV" == "gnome" ]]
}
is_cosmic() {
    detect_desktop_env
    [[ "$DESKTOP_ENV" == "cosmic" ]]
}

# Find next available .bak suffix: .bak, .bak.1, .bak.2, ...
next_backup_path() {
    local path="$1"
    local backup="$path.bak"
    local i=1
    while [[ -e "$backup" ]]; do
        backup="$path.bak.$i"
        ((i++))
    done
    printf '%s' "$backup"
}

# Unstow a package and restore backups if any exist
unstow_package() {
    local pkg="$1"
    local base_dir="${2:-$DOTFILES_DIR}"

    # Unstow all tag-* variants (user may have switched tags)
    for tag_dir in "$base_dir/$pkg"/tag-*/; do
        [[ -d "$tag_dir" ]] || continue
        local tag_name
        tag_name="$(basename "$tag_dir")"
        # Only unstow and log if this tag actually has stowed symlinks
        if stow -D -n -v -d "$base_dir/$pkg" -t "$HOME" "$tag_name" 2>&1 | grep -c '^UNLINK:' >/dev/null; then
            stow -D -d "$base_dir/$pkg" -t "$HOME" "$tag_name" 2>/dev/null || true
            info "  Unstowed: $pkg/$tag_name"
        fi
    done

    # Restore backups: find .bak files that belong to this package
    local -a search_dirs=()
    for tag_dir in "$base_dir/$pkg"/tag-*/; do
        [[ -d "$tag_dir" ]] && search_dirs+=("$tag_dir")
    done

    for pkg_dir in "${search_dirs[@]}"; do
        [[ -d "$pkg_dir" ]] || continue

        # Restore directory-level backups (backup_conflicts backs up package-owned dirs wholesale)
        while IFS= read -r -d '' top_entry; do
            [[ -z "$top_entry" ]] && continue
            local target="$HOME/$top_entry"
            [[ -e "$target" || -L "$target" ]] && continue
            local restore_from=""
            local i=1
            if [[ -e "$target.bak" ]]; then
                restore_from="$target.bak"
            fi
            while [[ -e "$target.bak.$i" ]]; do
                restore_from="$target.bak.$i"
                ((i++))
            done
            if [[ -n "$restore_from" ]]; then
                mv "$restore_from" "$target"
                info "  Restored: $restore_from -> $target"
            fi
        done < <(find "$pkg_dir" -mindepth 1 -maxdepth 1 \
            -not -name '.' -not -name '..' \
            -printf '%P\0' 2>/dev/null)

        # Restore file-level backups (for files inside shared/recurse dirs)
        while IFS= read -r -d '' rel_path; do
            [[ -z "$rel_path" ]] && continue
            local target="$HOME/$rel_path"
            [[ -e "$target" || -L "$target" ]] && continue
            # Find the highest numbered backup
            local restore_from=""
            local i=1
            if [[ -e "$target.bak" ]]; then
                restore_from="$target.bak"
            fi
            while [[ -e "$target.bak.$i" ]]; do
                restore_from="$target.bak.$i"
                ((i++))
            done
            if [[ -n "$restore_from" ]]; then
                mv "$restore_from" "$target"
                info "  Restored: $restore_from -> $target"
            fi
        done < <(find "$pkg_dir" -mindepth 1 \( -type f -o -type l \) \
            -not -path '*/.git/*' -not -name '.git' \
            -printf '%P\0' 2>/dev/null)
    done
}

# ─── Custom packages INI parser/writer ───────────────────────────────────────

# Parallel arrays populated by read_custom_packages()
PKG_NAMES=()
PKG_TAGS=()
PKG_SOURCES=()
PKG_TYPES=()
PKG_RECURSE_DIRS=()

read_custom_packages() {
    PKG_NAMES=()
    PKG_TAGS=()
    PKG_SOURCES=()
    PKG_TYPES=()
    PKG_RECURSE_DIRS=()

    [[ -f "$CUSTOM_FILE" ]] || return 0

    local current_name="" current_tag="" current_source="" current_type="" current_recurse=""

    while IFS= read -r line; do
        line="${line%%#*}" # strip comments
        [[ -z "${line// /}" ]] && continue

        if [[ "$line" =~ ^\[([^:]+)(:(.+))?\]$ ]]; then
            # Save previous package if any
            if [[ -n "$current_name" ]]; then
                PKG_NAMES+=("$current_name")
                PKG_TAGS+=("$current_tag")
                PKG_SOURCES+=("$current_source")
                PKG_TYPES+=("$current_type")
                PKG_RECURSE_DIRS+=("$current_recurse")
            fi
            current_name="${BASH_REMATCH[1]}"
            current_tag="${BASH_REMATCH[3]:-default}"
            current_source=""
            current_type="full"
            current_recurse=""
        elif [[ "$line" =~ ^source=(.+)$ ]]; then
            current_source="${BASH_REMATCH[1]}"
            # Expand ~ to $HOME
            current_source="${current_source/#\~/$HOME}"
        elif [[ "$line" =~ ^type=(.+)$ ]]; then
            current_type="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^recurse_dirs=(.+)$ ]]; then
            current_recurse="${BASH_REMATCH[1]}"
        fi
    done <"$CUSTOM_FILE"

    # Don't forget last package
    if [[ -n "$current_name" ]]; then
        PKG_NAMES+=("$current_name")
        PKG_TAGS+=("$current_tag")
        PKG_SOURCES+=("$current_source")
        PKG_TYPES+=("$current_type")
        PKG_RECURSE_DIRS+=("$current_recurse")
    fi
}

write_custom_packages() {
    {
        printf '# Custom dotfiles packages (managed by setup:custom-dotfiles)\n'
        printf '# Do not edit manually — use: mise run setup:custom-dotfiles\n\n'

        for i in "${!PKG_NAMES[@]}"; do
            if [[ "${PKG_TAGS[$i]}" == "default" ]]; then
                printf '[%s]\n' "${PKG_NAMES[$i]}"
            else
                printf '[%s:%s]\n' "${PKG_NAMES[$i]}" "${PKG_TAGS[$i]}"
            fi
            printf 'source=%s\n' "${PKG_SOURCES[$i]}"
            printf 'type=%s\n' "${PKG_TYPES[$i]}"
            if [[ -n "${PKG_RECURSE_DIRS[$i]}" ]]; then
                printf 'recurse_dirs=%s\n' "${PKG_RECURSE_DIRS[$i]}"
            fi
            printf '\n'
        done
    } >"$CUSTOM_FILE"
}
