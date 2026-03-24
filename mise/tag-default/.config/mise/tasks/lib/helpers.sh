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
