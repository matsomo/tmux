#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

SEARCH_ROOT="$HOME/Dev"
MAX_DEPTH=3
WINDOWS=(Claude IDE Termione Termitwo)

# tmux forbids . and : in session names. Sets $REPLY rather than printing, so
# callers don't need a forking $(...).
sanitize() { REPLY="${1//[.:]/_}"; }

list_repos() {
  # --prune: don't descend into the .git dirs themselves
  fd -HI --max-depth "$MAX_DEPTH" --prune --format '{//}' '^\.git$' "$SEARCH_ROOT" 2>/dev/null |
    sort -u
}

list_dirs() {
  fd --type d --max-depth 2 --format '{}' . "$SEARCH_ROOT" 2>/dev/null | sort -u
}

# One tmux call and one awk pass, instead of a process per line: forks are
# what gets slow when the machine is busy.
picker_input() {
  local mode="${1:-repos}"
  SESSIONS="$(tmux list-sessions -F '#{session_name}	#{@sessionizer_root}' 2>/dev/null || true)" \
    awk '
      BEGIN {
        n = split(ENVIRON["SESSIONS"], lines, "\n")
        for (i = 1; i <= n; i++) {
          split(lines[i], f, "\t")
          if (f[1] != "") print "● " f[1]
          if (f[2] != "") open[f[2]] = 1
        }
        fflush()
      }
      !($0 in open)
    ' <(if [ "$mode" = all ]; then list_dirs; else list_repos; fi)
}

# Creates the session, and switches to it when run inside tmux, in one tmux
# call. A duplicate name makes new-session fail, which aborts the rest of the
# chain, so there's no separate has-session check.
create_session() {
  local dir="$1" name="$2" w
  local cmd=(new-session -ds "$name" -c "$dir" -n "${WINDOWS[0]}"
    \; set-option -t "=$name:" @sessionizer_root "$dir")
  for w in "${WINDOWS[@]:1}"; do
    cmd+=(\; new-window -t "=$name:" -c "$dir" -n "$w")
  done
  cmd+=(\; select-window -t "=$name:${WINDOWS[0]}")
  if [ -n "${TMUX:-}" ]; then
    cmd+=(\; switch-client -t "=$name")
  fi
  tmux "${cmd[@]}"
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
    sanitize "${3:-${dir##*/}}"
    create_session "$dir" "$REPLY"
    exit
    ;;
esac

# pipefail off here: if Enter lands before the list finishes, the lister dies
# of SIGPIPE, and that must not discard the selection — only fzf's status counts.
# enter waits for the search to catch up with the query (under load it lags
# the keystrokes and would accept a stale item) and ignores a no-match Enter.
set +o pipefail
selected="$(picker_input | fzf --reverse --prompt='repos > ' \
  --header='alt-h: toggle all dirs' \
  --bind 'enter:wait+accept-non-empty' \
  --bind "alt-h:transform:[[ \$FZF_PROMPT == 'repos > ' ]] \
    && echo 'change-prompt(dirs > )+reload($0 --list --all)' \
    || echo 'change-prompt(repos > )+reload($0 --list)'")" || exit 0

if [[ "$selected" == "● "* ]]; then
  tmux switch-client -t "=${selected#● }"
  exit 0
fi

sanitize "${selected##*/}"
default="$REPLY"
while :; do
  printf 'session name [%s]: ' "$default"
  IFS= read -r input </dev/tty
  sanitize "${input:-$default}"
  [ -z "$REPLY" ] && continue
  create_session "$selected" "$REPLY" && break
  echo 'choose another name'
done
