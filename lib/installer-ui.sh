#!/usr/bin/env bash

# installer-ui.sh — prompts, progress bar and quiet command runner.
#
# Every install module sets one label at the top:
#
#   STEP_LABEL="Installing Noctalia shell"
#
# and calls `ui_step` before each action. The bar prints that label and moves
# the percentage per action. Change the label in one place, nothing else.

FM_UI_TOTAL="${FM_UI_TOTAL:-0}"
FM_UI_CURRENT="${FM_UI_CURRENT:-0}"
FM_UI_LABEL="${FM_UI_LABEL:-}"
FM_UI_ACTIVE="${FM_UI_ACTIVE:-0}"
FM_UI_WARN_COUNT="${FM_UI_WARN_COUNT:-0}"
FM_UI_LOG="${FM_UI_LOG:-${FM_FEDORA_PATH:-$PWD}/install.log}"
FM_UI_ANSWERS="${FM_UI_ANSWERS:-$HOME/.config/fm-fedora/install.conf}"

ui_cols() {
    local cols="${COLUMNS:-}"
    if ! [[ "$cols" =~ ^[0-9]+$ ]] || (( cols < 40 )); then
        cols="$(tput cols 2>/dev/null || echo 80)"
    fi
    echo "$cols"
}

ui_clear() {
    printf '\r\033[2K'
}

ui_draw() {
    local pct=0
    if (( FM_UI_TOTAL > 0 )); then
        pct=$(( FM_UI_CURRENT * 100 / FM_UI_TOTAL ))
    fi
    if (( pct > 100 )); then
        pct=100
    fi

    local width=24
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_filled bar_empty
    printf -v bar_filled '%*s' "$filled" ''
    printf -v bar_empty '%*s' "$empty" ''
    bar_filled="${bar_filled// /█}"
    bar_empty="${bar_empty// /░}"

    local label="${FM_UI_LABEL:-Working}"
    local max=$(( $(ui_cols) - width - 14 ))
    if (( max < 12 )); then
        max=12
    fi
    if (( ${#label} > max )); then
        label="${label:0:max-1}…"
    fi

    printf '\r\033[2K%s[%s%s%s%s]%s %3d%%  %s' \
        "$c_dim" "$c_brand" "$bar_filled" "$c_dim" "$bar_empty" "$c_reset" \
        "$pct" "$label"
}

ui_note() {
    if (( FM_UI_ACTIVE )); then
        ui_clear
        printf '%s\n' "$*"
        ui_draw
    else
        printf '%s\n' "$*"
    fi
}

ui_init() {
    FM_UI_TOTAL="${1:-0}"
    FM_UI_CURRENT=0
    FM_UI_ACTIVE=1
    FM_UI_LOG="${FM_UI_LOG:-$FM_FEDORA_PATH/install.log}"
    mkdir -p "$(dirname "$FM_UI_LOG")"
    : > "$FM_UI_LOG"
    ui_draw
}

ui_step() {
    local label="${1:-${STEP_LABEL:-}}"
    if [[ -z "$label" ]]; then
        local src="${BASH_SOURCE[1]:-}"
        label="$(basename "${src:-working}" .sh)"
    fi
    FM_UI_LABEL="$label"
    FM_UI_CURRENT=$(( FM_UI_CURRENT + 1 ))
    if (( FM_UI_TOTAL > 0 && FM_UI_CURRENT > FM_UI_TOTAL )); then
        FM_UI_TOTAL="$FM_UI_CURRENT"
    fi
    FM_UI_ACTIVE=1
    ui_draw
}

ui_exec() {
    local rc=0
    {
        printf '\n$ %s\n' "$*"
        "$@"
    } >> "$FM_UI_LOG" 2>&1 || rc=$?

    if (( rc != 0 )); then
        ui_clear
        printf '%s✖ Command failed (exit %d):%s %s\n' \
            "$c_err" "$rc" "$c_reset" "$*" >&2
        printf '  Last lines from %s:\n' "$FM_UI_LOG" >&2
        tail -n 10 "$FM_UI_LOG" 2>/dev/null | sed 's/^/    /' >&2
        return "$rc"
    fi
}

ui_finish() {
    FM_UI_CURRENT="$FM_UI_TOTAL"
    FM_UI_LABEL="Done"
    ui_draw
    printf '\n'
    FM_UI_ACTIVE=0
}

ui_count_steps() {
    # Keep every `ui_step` call unconditional and at the top level of a module:
    # the total is the number of calls, so one inside an if/loop would make the
    # percentage drift.
    local total=0 file count
    for file in "$@"; do
        [[ -f "$file" ]] || continue
        count="$(grep -cE '^[[:space:]]*ui_step([[:space:]]|$)' "$file" 2>/dev/null || true)"
        total=$(( total + ${count:-0} ))
    done
    echo "$total"
}

ui_confirm() {
    local prompt="$1" default="${2:-n}" hint reply=""
    if [[ "$default" == "y" ]]; then
        hint="[Y/n]"
    else
        hint="[y/N]"
    fi

    printf '  %s\n' "$prompt"
    if [[ -t 0 ]]; then
        read -r -p "  $hint " reply || reply=""
    fi
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[Yy] ]]
}

ui_choose() {
    local prompt="$1" options="$2" default_index="${3:-1}" reply="" index=1 option
    local IFS='|'

    printf '  %s\n' "$prompt"
    for option in $options; do
        printf '    %d) %s\n' "$index" "$option"
        index=$(( index + 1 ))
    done

    if [[ -t 0 ]]; then
        read -r -p "  Select [$default_index]: " reply || reply=""
    fi
    reply="${reply:-$default_index}"
    if ! [[ "$reply" =~ ^[0-9]+$ ]] || (( reply < 1 || reply >= index )); then
        reply="$default_index"
    fi

    index=1
    UI_ANSWER=""
    for option in $options; do
        if (( index == reply )); then
            UI_ANSWER="$option"
            break
        fi
        index=$(( index + 1 ))
    done
}

ui_save_answers() {
    mkdir -p "$(dirname "$FM_UI_ANSWERS")"
    {
        printf 'FM_ANSWER_DOCK=%q\n' "$FM_ANSWER_DOCK"
        printf 'FM_ANSWER_PASSWORD_MANAGER=%q\n' "$FM_ANSWER_PASSWORD_MANAGER"
        printf 'FM_ANSWER_DEV=%q\n' "$FM_ANSWER_DEV"
    } > "$FM_UI_ANSWERS"
}

ui_collect_answers() {
    # Reuse saved answers as defaults, but ask again on every run for now.
    if [[ -f "$FM_UI_ANSWERS" ]]; then
        # shellcheck disable=SC1090
        source "$FM_UI_ANSWERS"
    fi

    FM_ANSWER_DOCK="${FM_ANSWER_DOCK:-no}"
    FM_ANSWER_PASSWORD_MANAGER="${FM_ANSWER_PASSWORD_MANAGER:-Zoho Vault}"
    FM_ANSWER_DEV="${FM_ANSWER_DEV:-yes}"

    local dock_default="n"
    if [[ "$FM_ANSWER_DOCK" == "yes" ]]; then
        dock_default="y"
    fi
    if ui_confirm "Do you prefer a dock on your workstation?" "$dock_default"; then
        FM_ANSWER_DOCK="yes"
    else
        FM_ANSWER_DOCK="no"
    fi

    local password_default=5
    case "$FM_ANSWER_PASSWORD_MANAGER" in
        "1Password")   password_default=1 ;;
        "Proton Pass") password_default=2 ;;
        "Bitwarden")   password_default=3 ;;
        "LastPass")    password_default=4 ;;
    esac
    ui_choose \
        "Do you already use a password manager? Zoho Vault is free for personal use and recommended if you don't have one." \
        "1Password|Proton Pass|Bitwarden|LastPass|Zoho Vault" \
        "$password_default"
    FM_ANSWER_PASSWORD_MANAGER="$UI_ANSWER"

    local dev_default="y"
    if [[ "$FM_ANSWER_DEV" == "no" ]]; then
        dev_default="n"
    fi
    if ui_confirm "Do you intend to use this machine for crafting software?
     Don't worry, we won't bloat your machine. Just some essentials and nice to haves." "$dev_default"; then
        FM_ANSWER_DEV="yes"
    else
        FM_ANSWER_DEV="no"
    fi

    ui_save_answers
    printf '\n'
}
