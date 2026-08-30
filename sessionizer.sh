#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

SEARCH_ROOT="$HOME/Dev"
MAX_DEPTH=3
WINDOWS=(Claude IDE Termione Termitwo)

sanitize() { printf '%s' "$1" | tr '.:' '__'; }

list_repos() {
  fd -HI --max-depth "$MAX_DEPTH" '^\.git$' "$SEARCH_ROOT" 2>/dev/null |
    xargs -n1 dirname | sort -u
}

list_dirs() {
  fd --type d --max-depth 2 . "$SEARCH_ROOT" 2>/dev/null |
    sed 's:/*$::' | sort -u
}

session_names() { tmux list-sessions -F '#{session_name}' 2>/dev/null || true; }
session_roots() { tmux list-sessions -F '#{@sessionizer_root}' 2>/dev/null | sed '/^$/d' || true; }

picker_input() {
  local mode="${1:-repos}"
  session_names | sed 's/^/● /'
  local roots dir
  roots="$(session_roots)"
  { if [ "$mode" = all ]; then list_dirs; else list_repos; fi; } | while IFS= read -r dir; do
    if [ -n "$roots" ] && grep -qxF "$dir" <<<"$roots"; then
      continue
    fi
    printf '%s\n' "$dir"
  done
}

create_session() {
  local dir="$1" name="$2" w
  if tmux has-session -t="$name" 2>/dev/null; then
    return 1
  fi
  tmux new-session -ds "$name" -c "$dir" -n "${WINDOWS[0]}"
  tmux set-option -t "$name" @sessionizer_root "$dir"
  for w in "${WINDOWS[@]:1}"; do
    tmux new-window -t "$name:" -c "$dir" -n "$w"
  done
  tmux select-window -t "$name:${WINDOWS[0]}"
}

case "${1:-}" in
  --list)
    if [ "${2:-}" = "--all" ]; then picker_input all; else picker_input; fi
    exit 0
    ;;
  --new)
    dir="${2:?usage: sessionizer.sh --new <dir> [name]}"
    dir="${dir%/}"
    [ -d "$dir" ] || { echo "no such directory: $dir" >&2; exit 1; }
    name="$(sanitize "${3:-$(basename "$dir")}")"
    if ! create_session "$dir" "$name"; then
      echo "session \"$name\" already exists" >&2
      exit 1
    fi
    if [ -n "${TMUX:-}" ]; then
      tmux switch-client -t "=$name"
    fi
    exit 0
    ;;
esac

selected="$(picker_input | fzf --reverse --prompt='repos > ' \
  --header='alt-h: toggle all dirs' \
  --bind "alt-h:transform:[[ \$FZF_PROMPT == 'repos > ' ]] \
    && echo 'change-prompt(dirs > )+reload($0 --list --all)' \
    || echo 'change-prompt(repos > )+reload($0 --list)'")" || exit 0

if [[ "$selected" == "● "* ]]; then
  tmux switch-client -t "=${selected#● }"
  exit 0
fi

default="$(sanitize "$(basename "$selected")")"
while :; do
  printf 'session name [%s]: ' "$default"
  IFS= read -r input </dev/tty
  name="$(sanitize "${input:-$default}")"
  [ -z "$name" ] && continue
  if create_session "$selected" "$name"; then
    break
  fi
  printf 'session "%s" already exists — choose another name\n' "$name"
done
tmux switch-client -t "=$name"
