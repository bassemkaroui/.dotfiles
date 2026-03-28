#!/usr/bin/env python3
"""COSMIC theme helper: search, download, and apply themes from cosmic-themes.org.

Commands:
  search <name>              Search for themes, output JSON lines: name|downloads
  download <name> <outfile>  Download exact-match theme .ron to file
  apply <ron_file>           Parse .ron and write config entries to COSMIC config dir

The .ron file contains a ThemeBuilder struct. Each top-level field is written
as a separate file under:
  ~/.config/cosmic/com.system76.CosmicTheme.{Dark|Light}.Builder/v1/<field>
"""

import json
import os
import sys
import urllib.parse
import urllib.request

THEMES_API = "https://cosmic-themes.org/api/themes"


# ─── RON parsing ────────────────────────────────────────────────────────────


def parse_top_level_fields(ron_content: str) -> dict[str, str]:
    """Extract top-level key: value pairs from a RON struct, handling nested parens."""
    content = ron_content.strip()
    if content.startswith("(") and content.endswith(")"):
        content = content[1:-1]

    fields: dict[str, str] = {}
    i = 0
    length = len(content)

    while i < length:
        # Skip whitespace and commas
        while i < length and content[i] in " \t\n\r,":
            i += 1
        if i >= length:
            break

        # Skip comments
        if content[i : i + 2] == "//":
            while i < length and content[i] != "\n":
                i += 1
            continue

        # Read field name
        key_start = i
        while i < length and content[i] != ":":
            i += 1
        if i >= length:
            break
        key = content[key_start:i].strip()
        i += 1  # skip ':'

        # Skip whitespace after colon
        while i < length and content[i] in " \t\n\r":
            i += 1

        # Read value (handle nested parentheses)
        value_start = i
        depth = 0
        in_string = False
        escape = False

        while i < length:
            ch = content[i]
            if escape:
                escape = False
                i += 1
                continue
            if ch == "\\":
                escape = True
                i += 1
                continue
            if ch == '"':
                in_string = not in_string
                i += 1
                continue
            if in_string:
                i += 1
                continue
            if ch == "(":
                depth += 1
            elif ch == ")":
                if depth == 0:
                    break
                depth -= 1
            elif ch == "," and depth == 0:
                break
            i += 1

        value = content[value_start:i].strip()
        if value.endswith(","):
            value = value[:-1].strip()
        fields[key] = value

        if i < length and content[i] == ",":
            i += 1

    return fields


def detect_variant(fields: dict[str, str]) -> str:
    """Detect dark/light from palette field."""
    palette = fields.get("palette", "")
    for prefix in ("Dark", "HighContrastDark"):
        if palette.startswith(prefix):
            return "Dark"
    for prefix in ("Light", "HighContrastLight"):
        if palette.startswith(prefix):
            return "Light"
    return "Dark"


# ─── API interaction ────────────────────────────────────────────────────────


def api_search(name: str, limit: int = 20) -> list[dict]:
    """Search cosmic-themes.org API. Returns list of theme dicts."""
    encoded = urllib.parse.quote(name)
    url = f"{THEMES_API}?search={encoded}&limit={limit}"
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            return json.loads(resp.read())
    except Exception as e:
        print(f"ERROR: API request failed: {e}", file=sys.stderr)
        sys.exit(1)


# ─── Commands ────────────────────────────────────────────────────────────────


def cmd_search(name: str) -> None:
    """Search and output results as pipe-delimited lines: name|downloads."""
    results = api_search(name)
    if not results:
        sys.exit(1)
    for theme in results:
        print(f"{theme['name']}|{theme['downloads']}")


def cmd_download(name: str, outfile: str) -> None:
    """Download a theme by name (exact match first, then first result)."""
    results = api_search(name)
    if not results:
        print("ERROR: No themes found", file=sys.stderr)
        sys.exit(1)

    # Try exact match (case-insensitive)
    match = None
    for theme in results:
        if theme["name"].lower() == name.lower():
            match = theme
            break

    if match is None:
        # No exact match — output available names and exit with code 2
        for theme in results:
            print(f"{theme['name']}|{theme['downloads']}")
        sys.exit(2)

    # Write .ron content to file
    with open(outfile, "w") as f:
        f.write(match["ron"])

    print(f"NAME={match['name']}")
    print(f"DOWNLOADS={match['downloads']}")


def cmd_apply(ron_file: str) -> None:
    """Parse .ron file and write config entries."""
    with open(ron_file, "r") as f:
        ron_content = f.read()

    fields = parse_top_level_fields(ron_content)
    if not fields:
        print("ERROR: No fields parsed from .ron file", file=sys.stderr)
        sys.exit(1)

    variant = detect_variant(fields)
    component = f"com.system76.CosmicTheme.{variant}.Builder"
    config_dir = os.path.expanduser(f"~/.config/cosmic/{component}/v1")
    os.makedirs(config_dir, exist_ok=True)

    written = 0
    for key, value in fields.items():
        entry_path = os.path.join(config_dir, key)
        with open(entry_path, "w") as f:
            f.write(value)
        written += 1

    print(f"VARIANT={variant}")
    print(f"COMPONENT={component}")
    print(f"CONFIG_DIR={config_dir}")
    print(f"ENTRIES_WRITTEN={written}")


# ─── Main ────────────────────────────────────────────────────────────────────


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <search|download|apply> [args...]", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "search" and len(sys.argv) == 3:
        cmd_search(sys.argv[2])
    elif cmd == "download" and len(sys.argv) == 4:
        cmd_download(sys.argv[2], sys.argv[3])
    elif cmd == "apply" and len(sys.argv) == 3:
        cmd_apply(sys.argv[2])
    else:
        print(f"Usage: {sys.argv[0]} <search|download|apply> [args...]", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
