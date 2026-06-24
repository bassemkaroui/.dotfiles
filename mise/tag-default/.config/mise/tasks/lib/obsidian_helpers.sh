# Shared Obsidian install/update helpers.
# Source AFTER lib/helpers.sh (needs info/warn/ok/ok_changed/fail) and with
# TASK_NAME already set:
#   TASK_NAME="install:obsidian"
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/helpers.sh"
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/obsidian_helpers.sh"
#
# Obsidian ships official AppImages on GitHub releases. We install them to
# ~/.local/bin/obsidian, record the version in a state file (so update checks
# never have to launch the GUI), and best-effort wire up a .desktop launcher.

OBSIDIAN_REPO="obsidianmd/obsidian-releases"
OBSIDIAN_BIN="$HOME/.local/bin/obsidian"
OBSIDIAN_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/obsidian"
OBSIDIAN_VERSION_FILE="$OBSIDIAN_STATE_DIR/version"
OBSIDIAN_DESKTOP_FILE="$HOME/.local/share/applications/obsidian.desktop"
OBSIDIAN_ICON_FILE="$HOME/.local/share/icons/hicolor/256x256/apps/obsidian.png"

# Cached latest-release JSON (populated by obsidian_fetch_release).
OBSIDIAN_RELEASE_JSON=""

# Fetch the latest-release JSON once (cached). Returns non-zero on failure so
# callers can decide between warn and fail. Safe to run in the main shell.
obsidian_fetch_release() {
    [[ -n "$OBSIDIAN_RELEASE_JSON" ]] && return 0
    OBSIDIAN_RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/$OBSIDIAN_REPO/releases/latest")" || return 1
    [[ -n "$OBSIDIAN_RELEASE_JSON" ]]
}

# Echo the latest version (leading "v" stripped). Needs obsidian_fetch_release.
obsidian_latest_version() {
    printf '%s' "$OBSIDIAN_RELEASE_JSON" \
        | grep '"tag_name"' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/'
}

# Echo the AppImage download URL for this machine's architecture. Empty when the
# arch is unsupported or no matching asset is found. Needs obsidian_fetch_release.
obsidian_appimage_url() {
    local pattern
    case "$(uname -m)" in
        x86_64) pattern='Obsidian-[0-9.]+\.AppImage"' ;;
        aarch64 | arm64) pattern='Obsidian-[0-9.]+-arm64\.AppImage"' ;;
        *) return 0 ;;
    esac
    printf '%s' "$OBSIDIAN_RELEASE_JSON" \
        | grep '"browser_download_url"' \
        | grep -E "$pattern" \
        | head -1 \
        | sed -E 's/.*"(https[^"]+)".*/\1/'
}

# Echo the installed version, or nothing if Obsidian isn't installed / unknown.
obsidian_installed_version() {
    [[ -f "$OBSIDIAN_VERSION_FILE" && -x "$OBSIDIAN_BIN" ]] || return 0
    tr -d '[:space:]' <"$OBSIDIAN_VERSION_FILE"
}

# Best-effort: extract the bundled icon and write a .desktop launcher so Obsidian
# shows up in the application menu. Never fatal — AppImage extraction can fail on
# sandboxed/FUSE-less hosts, in which case the launcher still gets a generic icon
# name (blank in the menu, but functional).
obsidian_desktop_integration() {
    local version="$1"
    mkdir -p "$(dirname "$OBSIDIAN_DESKTOP_FILE")" "$(dirname "$OBSIDIAN_ICON_FILE")"

    local extract_dir
    extract_dir="$(mktemp -d)"
    if (cd "$extract_dir" && "$OBSIDIAN_BIN" --appimage-extract obsidian.png >/dev/null 2>&1) \
        && [[ -f "$extract_dir/squashfs-root/obsidian.png" ]]; then
        cp "$extract_dir/squashfs-root/obsidian.png" "$OBSIDIAN_ICON_FILE"
        ok "Installed Obsidian icon"
    else
        warn "Could not extract Obsidian icon — menu entry may show a blank icon"
    fi
    rm -rf "$extract_dir"

    cat >"$OBSIDIAN_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Obsidian
Comment=A knowledge base that works on local Markdown files
Exec=$OBSIDIAN_BIN %u
Icon=obsidian
Terminal=false
Type=Application
Categories=Office;Utility;
MimeType=x-scheme-handler/obsidian;
StartupWMClass=obsidian
X-Obsidian-Version=$version
EOF
    ok "Wrote desktop launcher: $OBSIDIAN_DESKTOP_FILE"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$(dirname "$OBSIDIAN_DESKTOP_FILE")" >/dev/null 2>&1 || true
    fi
}

# Download the AppImage for the given version/url, install it to ~/.local/bin,
# record the version, and run desktop integration. Uses fail on hard errors, so
# call it from the task's main shell (not a subshell / command substitution).
obsidian_install_appimage() {
    local version="$1" url="$2"
    [[ -n "$url" ]] || fail "No Obsidian AppImage available for architecture $(uname -m)"

    mkdir -p "$(dirname "$OBSIDIAN_BIN")" "$OBSIDIAN_STATE_DIR"

    local tmp
    tmp="$(mktemp)"
    info "Downloading Obsidian $version ..."
    if ! curl -fSL -o "$tmp" "$url"; then
        rm -f "$tmp"
        fail "Failed to download Obsidian AppImage from $url"
    fi
    chmod +x "$tmp"
    mv "$tmp" "$OBSIDIAN_BIN"
    printf '%s\n' "$version" >"$OBSIDIAN_VERSION_FILE"
    ok_changed "Obsidian $version installed to $OBSIDIAN_BIN"

    obsidian_desktop_integration "$version"

    # Make obsidian resolvable in the current session.
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
}
