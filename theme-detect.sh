#!/usr/bin/env bash
# Set tmux-dotbar colors to match the macOS system appearance.
# Dark = the original palette; light = a readable variant for a light terminal bg.
# Run at tmux start and re-runnable via a keybind after flipping the system theme.

set -euo pipefail

if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
	# Dark (original look)
	tmux set -g @tmux-dotbar-bg "default"
	tmux set -g @tmux-dotbar-fg "#547998"
	tmux set -g @tmux-dotbar-fg-current "#CBE0F0"
	tmux set -g @tmux-dotbar-fg-session "#65D1FF"
	tmux set -g @tmux-dotbar-fg-prefix "#3EFFDC"
else
	# Light = GitHub Light High Contrast (synced with ghostty + nvim)
	tmux set -g @tmux-dotbar-bg "default"
	tmux set -g @tmux-dotbar-fg "#66707b"
	tmux set -g @tmux-dotbar-fg-current "#0349b4"
	tmux set -g @tmux-dotbar-fg-session "#1b7c83"
	tmux set -g @tmux-dotbar-fg-prefix "#622cbc"
fi

# Rebuild dotbar's status formats with the new colors.
tmux run-shell "$HOME/.config/tmux/plugins/tmux-dotbar/dotbar.tmux"
