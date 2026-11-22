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

# Runs a command with its output logged to $FM_UI_LOG, returning its exit
# status. No error block on screen: install.sh's ERR trap reports an
# unconditional failure as one line, and callers handle the rest.
ui_exec() {
    local rc=0
    {
        printf '\n$ %s\n' "$*"
        "$@"
    } >> "$FM_UI_LOG" 2>&1 || rc=$?
    return "$rc"
}

ui_exec_quiet() {
    ui_exec "$@"
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

# ── Interactive selectors ──
# Both draw in place: the question stays on one line and collapses to
# `question   answer` once confirmed, so the transcript reads like a filled-in
# form. Non-interactive runs print the default answer and move on.

ui__truncate() {
    local text="$1" max=$(( $(ui_cols) - 6 ))
    if (( max < 10 )); then
        max=10
    fi
    if (( ${#text} > max )); then
        text="${text:0:max-1}…"
    fi
    printf '%s' "$text"
}

ui__confirm_line() {
    local prompt="$1" sel="$2"
    printf '\r\033[2K%s   ' "$prompt"
    if (( sel )); then
        printf '%sNo%s   %s[Yes]%s' "$c_dim" "$c_reset" "$c_brand" "$c_reset"
    else
        printf '%s[No]%s   %sYes%s' "$c_brand" "$c_reset" "$c_dim" "$c_reset"
    fi
}

ui__choose_label() {
    local entry="$1"
    if [[ "$entry" == *::* ]]; then
        printf '%s (%s)' "${entry%%::*}" "${entry#*::}"
    else
        printf '%s' "$entry"
    fi
}

ui__choose_value() {
    printf '%s' "${1%%::*}"
}

ui__choose_line() {
    local text="$1" selected="$2"
    text="$(ui__truncate "$text")"
    if [[ "$selected" == "1" ]]; then
        printf '%s❯%s %s\n' "$c_brand" "$c_reset" "$text"
    else
        printf '  %s%s%s\n' "$c_dim" "$text" "$c_reset"
    fi
}

ui_confirm() {
    local prompt="$1" default="${2:-n}" hint="${3:-}"
    local sel=0 answer key esc

    if [[ "$default" == "y" || "$default" == "yes" ]]; then
        sel=1
    fi

    if [[ ! -t 0 || ! -t 1 ]]; then
        answer="No"
        if (( sel )); then answer="Yes"; fi
        printf '%s   %s\n' "$prompt" "$answer"
        if (( sel == 1 )); then return 0; else return 1; fi
    fi

    while true; do
        ui__confirm_line "$prompt" "$sel"
        IFS= read -rsn1 key || key=""
        case "$key" in
            ''|$'\n'|$'\r') break ;;
            [Yy]) sel=1; break ;;
            [Nn]) sel=0; break ;;
            [Hh]) sel=0 ;;
            [Ll]) sel=1 ;;
            ' '|$'\t') sel=$(( 1 - sel )) ;;
            $'\x1b')
                IFS= read -rsn2 -t 0.1 esc || esc=""
                case "$esc" in
                    '[D'|'[A'|'OD'|'OA') sel=0 ;;
                    '[C'|'[B'|'OC'|'OB') sel=1 ;;
                esac
                ;;
        esac
    done

    # Collapse the toggle into a plain `question   answer` line, then show any
    # follow-up hint underneath.
    printf '\r\033[2K'
    answer="No"
    if (( sel )); then answer="Yes"; fi
    printf '\r\033[2K%s   %s\n' "$prompt" "$answer"
    if [[ -n "$hint" ]]; then
        printf '%s%s%s\n' "$c_dim" "$(ui__truncate "$hint")" "$c_reset"
    fi
    if (( sel == 1 )); then return 0; else return 1; fi
}

ui_choose() {
    local prompt="$1" options="$2" default_index="${3:-1}"
    local -a items=()
    local IFS='|' opt
    for opt in $options; do
        items+=("$opt")
    done

    local count="${#items[@]}" i key esc selected
    if (( default_index < 1 || default_index > count )); then
        default_index=1
    fi
    local sel=$(( default_index - 1 ))

    if [[ ! -t 0 || ! -t 1 ]]; then
        UI_ANSWER="$(ui__choose_value "${items[$sel]}")"
        printf '%s   %s\n' "$prompt" "$UI_ANSWER"
        return
    fi

    printf '%s\n' "$prompt"
    for (( i=0; i<count; i++ )); do
        selected=0
        if (( i == sel )); then selected=1; fi
        ui__choose_line "$(ui__choose_label "${items[$i]}")" "$selected"
    done

    while true; do
        IFS= read -rsn1 key || key=""
        case "$key" in
            ''|$'\n'|$'\r') break ;;
            [Jj]) sel=$(( (sel + 1) % count )) ;;
            [Kk]) sel=$(( (sel - 1 + count) % count )) ;;
            [1-9])
                if (( key >= 1 && key <= count )); then
                    sel=$(( key - 1 ))
                fi
                ;;
            $'\x1b')
                IFS= read -rsn2 -t 0.1 esc || esc=""
                case "$esc" in
                    '[B'|'OB') sel=$(( (sel + 1) % count )) ;;
                    '[A'|'OA') sel=$(( (sel - 1 + count) % count )) ;;
                esac
                ;;
        esac

        # Redraw the question + option block in place.
        printf '\033[%dA' $(( count + 1 ))
        printf '%s\n' "$prompt"
        for (( i=0; i<count; i++ )); do
            selected=0
            if (( i == sel )); then selected=1; fi
            ui__choose_line "$(ui__choose_label "${items[$i]}")" "$selected"
        done
    done

    # Collapse the block into one line: question + chosen answer.
    printf '\033[%dA' $(( count + 1 ))
    for (( i=0; i<=count; i++ )); do
        printf '\r\033[2K'
        if (( i < count )); then printf '\n'; fi
    done
    printf '\033[%dA' "$count"
    UI_ANSWER="$(ui__choose_value "${items[$sel]}")"
    printf '\r\033[2K%s   %s\n' "$prompt" "$UI_ANSWER"
}

# ── Multi-select selector ──
# Disabled with the project-management question: Opera has no PWA subsystem,
# so there was nothing for the answer to drive. Kept intact rather than
# deleted — re-enable by removing the two `FM_PM_DISABLED` guard lines.
#
# Same drawing conventions as ui_choose, but any number of options can be
# selected. An option literally named "Skip" is exclusive: choosing it clears
# everything else, and choosing anything else clears it. Confirming with
# nothing selected also answers "Skip", so the possible outcomes are every
# combination of the real options plus Skip.
#
# Space or Tab toggles the option under the cursor, j/k or the arrow keys
# move it, Enter confirms. Digits are deliberately not bound — a short list
# does not need them, and ui_choose keeps that behaviour for itself.
: <<'FM_PM_DISABLED'
ui__multi_line() {
    local text="$1" marked="$2" cursor="$3"
    local box="[ ]"
    if (( marked )); then
        box="[x]"
    fi
    text="$(ui__truncate "$text")"
    if (( cursor )); then
        printf '%s❯%s %s %s\n' "$c_brand" "$c_reset" "$box" "$text"
    else
        printf '  %s%s %s%s\n' "$c_dim" "$box" "$text" "$c_reset"
    fi
}

ui_choose_multi() {
    local prompt="$1" options="$2"
    local -a items=() marked=()
    local IFS='|' opt
    for opt in $options; do
        items+=("$opt")
        marked+=(0)
    done

    local count="${#items[@]}" i key esc cursor=0 skip_idx=-1

    for (( i=0; i<count; i++ )); do
        if [[ "${items[$i]}" == "Skip" ]]; then
            skip_idx=$i
            break
        fi
    done

    # Nothing is ever pre-selected, so a non-interactive run answers Skip.
    if [[ ! -t 0 || ! -t 1 ]]; then
        UI_ANSWER="Skip"
        printf '%s   %s\n' "$prompt" "$UI_ANSWER"
        return 0
    fi

    printf '%s\n' "$prompt"
    for (( i=0; i<count; i++ )); do
        ui__multi_line "${items[$i]}" "${marked[$i]}" $(( i == cursor ))
    done

    while true; do
        IFS= read -rsn1 key || key=""
        case "$key" in
            ''|$'\n'|$'\r') break ;;
            [Jj]) cursor=$(( (cursor + 1) % count )) ;;
            [Kk]) cursor=$(( (cursor - 1 + count) % count )) ;;
            ' '|$'\t')
                if (( skip_idx >= 0 && cursor == skip_idx )); then
                    # Toggling Skip: picking it clears every other option.
                    if (( marked[cursor] )); then
                        marked[cursor]=0
                    else
                        for (( i=0; i<count; i++ )); do marked[$i]=0; done
                        marked[cursor]=1
                    fi
                elif (( marked[cursor] )); then
                    marked[cursor]=0
                else
                    marked[cursor]=1
                    # Anything real selected turns Skip off.
                    if (( skip_idx >= 0 )); then marked[skip_idx]=0; fi
                fi
                ;;
            $'\x1b')
                IFS= read -rsn2 -t 0.1 esc || esc=""
                case "$esc" in
                    '[B'|'OB') cursor=$(( (cursor + 1) % count )) ;;
                    '[A'|'OA') cursor=$(( (cursor - 1 + count) % count )) ;;
                esac
                ;;
        esac

        # Redraw the question + option block in place.
        printf '\033[%dA' $(( count + 1 ))
        printf '%s\n' "$prompt"
        for (( i=0; i<count; i++ )); do
            ui__multi_line "${items[$i]}" "${marked[$i]}" $(( i == cursor ))
        done
    done

    # Collapse the block into one line: question + chosen answer.
    printf '\033[%dA' $(( count + 1 ))
    for (( i=0; i<=count; i++ )); do
        printf '\r\033[2K'
        if (( i < count )); then printf '\n'; fi
    done
    printf '\033[%dA' "$count"

    UI_ANSWER=""
    for (( i=0; i<count; i++ )); do
        if (( marked[i] )) && [[ "${items[$i]}" != "Skip" ]]; then
            if [[ -n "$UI_ANSWER" ]]; then
                UI_ANSWER+=", "
            fi
            UI_ANSWER+="${items[$i]}"
        fi
    done
    if [[ -z "$UI_ANSWER" ]]; then
        UI_ANSWER="Skip"
    fi
    printf '\r\033[2K%s   %s\n' "$prompt" "$UI_ANSWER"
}
FM_PM_DISABLED

ui_save_answers() {
    mkdir -p "$(dirname "$FM_UI_ANSWERS")"
    {
        printf 'FM_ANSWER_DOCK=%q\n' "$FM_ANSWER_DOCK"
        printf 'FM_ANSWER_PASSWORD_MANAGER=%q\n' "$FM_ANSWER_PASSWORD_MANAGER"
        printf 'FM_ANSWER_DEV=%q\n' "$FM_ANSWER_DEV"
        # Disabled with the question below — nothing reads it while the
        # project-management layer is commented out.
        # printf 'FM_ANSWER_PM=%q\n' "${FM_ANSWER_PM:-Skip}"
    } > "$FM_UI_ANSWERS"
}

ui_collect_answers() {
    # Reuse saved answers as defaults, but ask again on every run for now.
    if [[ -f "$FM_UI_ANSWERS" ]]; then
        # shellcheck disable=SC1090
        source "$FM_UI_ANSWERS"
    fi

    # Dock defaults to No on every run, regardless of what was saved before.
    FM_ANSWER_DOCK="no"
    FM_ANSWER_PASSWORD_MANAGER="${FM_ANSWER_PASSWORD_MANAGER:-Zoho Vault}"
    FM_ANSWER_DEV="${FM_ANSWER_DEV:-yes}"

    if ui_confirm "Do you prefer a dock on your workstation?" "n"; then
        FM_ANSWER_DOCK="yes"
    else
        FM_ANSWER_DOCK="no"
    fi

    local password_default=1
    case "$FM_ANSWER_PASSWORD_MANAGER" in
        "1Password")   password_default=2 ;;
        "Proton Pass") password_default=3 ;;
        "Bitwarden")   password_default=4 ;;
        "LastPass")    password_default=5 ;;
    esac
    ui_choose \
        "Do you already use a password manager?" \
        "Zoho Vault::free for personal use, recommended|1Password|Proton Pass|Bitwarden|LastPass" \
        "$password_default"
    FM_ANSWER_PASSWORD_MANAGER="$UI_ANSWER"

    local dev_default="y"
    if [[ "$FM_ANSWER_DEV" == "no" ]]; then
        dev_default="n"
    fi
    if ui_confirm \
        "Do you intend to use this machine for crafting software?" "$dev_default" \
        "Don't worry — just some essentials and nice-to-haves."; then
        FM_ANSWER_DEV="yes"
    else
        FM_ANSWER_DEV="no"
    fi

    # Disabled with the multi-select primitive above: Opera has no PWA
    # subsystem, so the answer had nothing to drive in module 05. Re-enable
    # by removing these three lines and the two FM_PM_DISABLED guards.
    #
    # FM_ANSWER_PM="Skip"
    # ui_choose_multi \
    #     "Which project management tool do you use? (you can select multiple)" \
    #     "Notion|Linear|Skip"
    # FM_ANSWER_PM="$UI_ANSWER"

    ui_save_answers
    printf '\n'
}
