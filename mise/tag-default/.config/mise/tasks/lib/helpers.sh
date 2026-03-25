# Shared logging helpers for mise tasks.
# Usage: set TASK_NAME before sourcing.
#   TASK_NAME="setup:zsh"
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/helpers.sh"

: "${TASK_NAME:=unknown}"

_pad=18 # column width for task name alignment

info()       { printf '\033[1;34m[INFO]\033[0m \033[36m%-*s\033[0m ▸ %s\n' "$_pad" "$TASK_NAME" "$*"; }
warn()       { printf '\033[1;33m[WARN]\033[0m \033[36m%-*s\033[0m ▸ %s\n' "$_pad" "$TASK_NAME" "$*"; }
ok()         { printf '\033[1;32m[ OK ]\033[0m \033[36m%-*s\033[0m ▸ %s\n' "$_pad" "$TASK_NAME" "$*"; }
ok_changed() { printf '\033[1;32m[ OK ]\033[0m \033[36m%-*s\033[0m \033[1;32m●\033[0m %s\n' "$_pad" "$TASK_NAME" "$*"; }
fail()       { printf '\033[1;31m[FAIL]\033[0m \033[36m%-*s\033[0m ▸ %s\n' "$_pad" "$TASK_NAME" "$*"; exit 1; }

# ─── Shared paths ─────────────────────────────────────────────────────────────

DOTFILES_DIR="$HOME/.dotfiles"
CUSTOM_DIR="${DOTFILES_CUSTOM_DIR:-$HOME/.dotfiles-custom}"
DEVICE_TAG_FILE="$DOTFILES_DIR/.device-tag"
STOW_EXCLUDE_FILE="$DOTFILES_DIR/.stow-exclude"
CUSTOM_FILE="$CUSTOM_DIR/.custom-packages"

# Canonical list of default stow packages (shared across tasks)
ALL_DEFAULT_PACKAGES=(bash fzf git gnome_themes gpg zsh tmux bat yazi mise nvim gh gh-dash claude ghostty ssh p10k)

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
        stow -D -d "$base_dir/$pkg" -t "$HOME" "$tag_name" 2>/dev/null || true
        info "  Unstowed: $pkg/$tag_name"
    done

    # Restore backups: find .bak files that belong to this package
    local -a search_dirs=()
    for tag_dir in "$base_dir/$pkg"/tag-*/; do
        [[ -d "$tag_dir" ]] && search_dirs+=("$tag_dir")
    done

    for pkg_dir in "${search_dirs[@]}"; do
        [[ -d "$pkg_dir" ]] || continue
        while IFS= read -r -d '' rel_path; do
            [[ -z "$rel_path" ]] && continue
            local target="$HOME/$rel_path"
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
        line="${line%%#*}"           # strip comments
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
