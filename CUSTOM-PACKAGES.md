# Custom Packages

Extend this dotfiles repo with your own config packages, without modifying the main repo.

## How It Works

Custom packages live in a **sibling directory** (`~/.dotfiles-custom/`) that is completely separate from the main dotfiles repo. This means:

- Custom packages are always present, regardless of git operations on `~/.dotfiles`
- No branch switching required
- The main repo stays pristine and easy to update
- Each machine can have its own custom packages independently

The sibling directory can optionally be its own git repo for version control.

A tracking file (`.custom-packages`) inside the sibling directory records which packages you've added.

## Device Tags

Custom packages are **tag-aware**. Each package is associated with the device tag of the machine where it was added (from `.device-tag`). This allows different machines to have different configs for the same tool.

- When adding a package, it gets tagged with the current machine's `.device-tag` value
- If a package already exists with a different tag, a new tagged variant is created alongside it
- During deployment, the variant matching the machine's tag (or `tag-default` as fallback) is stowed

## Quick Start

```bash
mise run setup:custom-dotfiles
```

The task will:
1. Create `~/.dotfiles-custom/` if it doesn't exist (with optional `git init`)
2. Run a consistency check on any existing custom packages
3. Enter an interactive loop where you can add or remove packages

After the loop, run `mise run setup:dotfiles` to deploy everything (bootstrap does this automatically).

## Adding a Package

When you choose **add**, the task will prompt you for:

1. **Source path** -- the config file or directory to manage (e.g., `~/.config/alacritty`)
2. **Full or partial** (directories only):
   - **Full**: the entire directory is copied into the custom repo and managed by stow
   - **Partial**: you pick specific files/subdirectories to include. The parent directory is added to `RECURSE_DIRS` so stow doesn't fold it
3. **Package name** -- inferred from the path (e.g., `alacritty`), with option to override
4. **Tag** -- choose between `default` (universal fallback) or the current machine's tag (from `.device-tag`)

The task then:
- Creates a tagged stow package directory (e.g., `~/.dotfiles-custom/alacritty/tag-laptop/.config/alacritty/`)
- Updates `.custom-packages` with a `[name:tag]` entry
- Auto-commits the changes (if the custom directory is a git repo)

The actual stowing and backup of originals happens when `setup:dotfiles` runs next.

## Removing a Package

When you choose **remove**, the task will:
1. List custom packages matching the current device tag or `default` (e.g., `alacritty:laptop`)
2. Unstow the selected entry's tagged variant (`stow -D`)
3. Restore any `.bak` backups of the original files
4. Remove the `tag-*` directory for that variant
5. If no tagged variants remain for the package, remove the entire package directory
6. Update `.custom-packages` and auto-commit (if git repo)

## Environment Variable

Override the default custom packages location:

```bash
export DOTFILES_CUSTOM_DIR="$HOME/.my-custom-configs"
mise run setup:custom-dotfiles
```

Default: `~/.dotfiles-custom`

## Tracking File Format

`~/.dotfiles-custom/.custom-packages` uses an INI-style format with composite section headers:

```ini
# Custom dotfiles packages (managed by setup:custom-dotfiles)
# Do not edit manually -- use: mise run setup:custom-dotfiles
# Format: [name:tag] or [name] (bare name implies tag=default)

[alacritty:work]
source=~/.config/alacritty
type=full

[alacritty:personal]
source=~/.config/alacritty
type=full

[wezterm]
source=~/.config/wezterm
type=partial
recurse_dirs=.config/wezterm
```

| Field | Description |
|-------|-------------|
| `[name:tag]` | Package name and device tag. Bare `[name]` implies `tag=default` |
| `source` | Original path of the config file/directory |
| `type` | `full` (entire directory) or `partial` (selected items only) |
| `recurse_dirs` | Comma-separated paths added to `RECURSE_DIRS` for partial packages |

## Integration with setup:dotfiles

Custom packages are automatically:
- **Deployed** alongside default packages using the tag resolution logic (exact tag match, then `tag-default` fallback)
- **Excluded from `.stow-exclude` proposals** -- you won't be asked to exclude a package you explicitly added
- **Consistency-checked** -- if a tracked package's tag directory is missing, you'll be warned

If a custom package is manually added to `.stow-exclude`, a warning is shown and the exclusion is ignored.

## Directory Layout

```
~/.dotfiles/              (main repo, upstream)
  bash/
  zsh/
  p10k/
    tag-default/          (fallback variant)
    tag-laptop/           (laptop-specific variant)
  ...

~/.dotfiles-custom/       (your additions, separate repo)
  .custom-packages
  alacritty/
    tag-work/
      .config/
        alacritty/
          alacritty.toml
    tag-personal/
      .config/
        alacritty/
          alacritty.toml
  wezterm/
    tag-default/
      .config/
        wezterm/
          wezterm.lua
```

## New Machine Setup

1. Clone the main dotfiles repo as usual
2. Clone or create your custom packages directory:
   ```bash
   git clone <your-custom-repo> ~/.dotfiles-custom
   # or let the task create it:
   mise run setup:custom-dotfiles
   ```
3. Run `mise run setup:dotfiles` to deploy everything
