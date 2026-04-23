# Shared GPG helpers for mise gpg:* tasks.
# Assumes helpers.sh is already sourced by the caller (for fail/info/warn/ok).

# Warn threshold in days for "expiring soon".
: "${GPG_EXPIRY_WARN_DAYS:=30}"

require_gpg() {
    if ! command -v gpg >/dev/null 2>&1; then
        fail "gpg not found in PATH — install gnupg and retry"
    fi
}

# Field separator for secret_keys_stream output. ASCII Unit Separator (0x1F) —
# non-whitespace, so `read` preserves empty fields (unlike tab/space).
GPG_FS=$'\x1f'

# Emit rows describing every own secret key and subkey, one per line, with
# fields separated by $GPG_FS.
# Columns: type  primary_fpr  own_fpr  uid  expires_epoch  caps
#   type: "pri" for a primary key row, "sub" for a subkey row
#   uid is empty on "sub" rows (it belongs to the primary)
#   expires_epoch is empty when the key has no expiration
secret_keys_stream() {
    gpg --list-secret-keys --with-colons --fixed-list-mode 2>/dev/null \
        | awk -F: -v FS_OUT="$GPG_FS" '
        function emit_primary() {
            if (pri_fpr != "" && !pri_emitted) {
                printf "pri%s%s%s%s%s%s%s%s%s\n", FS_OUT, pri_fpr, FS_OUT, pri_fpr, FS_OUT, pri_uid, FS_OUT, pri_exp, FS_OUT pri_caps
                pri_emitted = 1
            }
        }
        $1 == "sec" {
            emit_primary()
            pri_exp = $7; pri_caps = $12
            pri_fpr = ""; pri_uid = ""; pri_emitted = 0
            state = "need_pri_fpr"
            next
        }
        $1 == "fpr" && state == "need_pri_fpr" {
            pri_fpr = $10
            state = "have_pri_fpr"
            next
        }
        $1 == "uid" && state == "have_pri_fpr" && pri_uid == "" {
            pri_uid = $10
            emit_primary()
            next
        }
        $1 == "ssb" {
            emit_primary()
            sub_exp = $7; sub_caps = $12
            state = "need_sub_fpr"
            next
        }
        $1 == "fpr" && state == "need_sub_fpr" {
            printf "sub%s%s%s%s%s%s%s%s%s\n", FS_OUT, pri_fpr, FS_OUT, $10, FS_OUT, "", FS_OUT, sub_exp, FS_OUT sub_caps
            state = ""
            next
        }
        END { emit_primary() }
    '
}

# Distinct primary fingerprints, one per line.
primary_fprs() {
    secret_keys_stream | awk -F"$GPG_FS" '$1 == "pri" { print $2 }'
}

# Short fingerprint: last 16 hex chars.
short_fpr() { printf '%s' "${1: -16}"; }

# UTC date string for an epoch, or "never" if empty.
format_date() {
    local epoch="$1"
    if [[ -z "$epoch" ]]; then
        printf 'never'
    else
        date -u -d "@$epoch" +%Y-%m-%d
    fi
}

# Days between now and the given epoch. Empty epoch → empty output.
days_remaining() {
    local epoch="$1"
    [[ -z "$epoch" ]] && return 0
    local now
    now="$(date +%s)"
    printf '%d' "$(((epoch - now) / 86400))"
}

# Classify: none | ok | warn | expired.
expiry_state() {
    local days="$1"
    if [[ -z "$days" ]]; then
        printf 'none'
    elif ((days < 0)); then
        printf 'expired'
    elif ((days <= GPG_EXPIRY_WARN_DAYS)); then
        printf 'warn'
    else
        printf 'ok'
    fi
}

# Wrap text with the ANSI color matching an expiry state.
colorize_expiry() {
    local state="$1" text="$2"
    case "$state" in
        ok) printf '\033[32m%s\033[0m' "$text" ;;
        warn) printf '\033[33m%s\033[0m' "$text" ;;
        expired) printf '\033[1;31m%s\033[0m' "$text" ;;
        *) printf '%s' "$text" ;;
    esac
}

# Truncate a string to N chars, appending ellipsis if cut.
truncate_str() {
    local s="$1" n="$2"
    if ((${#s} > n)); then
        printf '%s…' "${s:0:n-1}"
    else
        printf '%s' "$s"
    fi
}

# Print the table header used by `gpg:check-expiry` and `gpg:list`.
print_expiry_header() {
    local show_caps="${1:-0}"
    if ((show_caps)); then
        printf '  %-4s %-16s %-40s %-10s %-8s %s\n' \
            "Type" "Fingerprint" "UID" "Expires" "Days" "Caps"
    else
        printf '  %-4s %-16s %-40s %-10s %s\n' \
            "Type" "Fingerprint" "UID" "Expires" "Days"
    fi
}

# Print one table row from a TSV line produced by secret_keys_stream.
# Args: <tsv_line> [show_caps=0]
print_expiry_row() {
    local line="$1" show_caps="${2:-0}"
    local type pri_fpr own_fpr uid epoch caps
    IFS="$GPG_FS" read -r type pri_fpr own_fpr uid epoch caps <<<"$line"

    local days state days_str date_str uid_disp caps_disp
    days="$(days_remaining "$epoch")"
    state="$(expiry_state "$days")"
    date_str="$(format_date "$epoch")"
    if [[ -z "$days" ]]; then
        days_str="—"
    else
        days_str="$days"
    fi

    if [[ "$type" == "pri" ]]; then
        uid_disp="$(truncate_str "$uid" 40)"
    else
        uid_disp="(subkey)"
    fi
    caps_disp="$caps"

    # Colorize the days cell only; leave the rest uncolored so columns stay aligned.
    local days_cell
    days_cell="$(colorize_expiry "$state" "$(printf '%-8s' "$days_str")")"

    if ((show_caps)); then
        printf '  %-4s %-16s %-40s %-10s %s %s\n' \
            "$type" "$(short_fpr "$own_fpr")" "$uid_disp" "$date_str" "$days_cell" "$caps_disp"
    else
        printf '  %-4s %-16s %-40s %-10s %s\n' \
            "$type" "$(short_fpr "$own_fpr")" "$uid_disp" "$date_str" "$days_cell"
    fi
}
