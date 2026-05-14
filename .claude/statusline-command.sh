#!/bin/sh
# Claude Code status line - inspired by Starship config

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r 'if .context_window.used_percentage != null then .context_window.used_percentage else empty end')
used_tokens=$(echo "$input" | jq -r 'if .context_window.current_usage.input_tokens != null then .context_window.current_usage.input_tokens else empty end')
total_tokens=$(echo "$input" | jq -r 'if .context_window.context_window_size != null then .context_window.context_window_size else empty end')

# Colors matching Starship theme
DARK_BG='\033[48;2;44;62;80m'       # #2C3E50
GREEN_BG='\033[48;2;0;210;106m'     # #00d26a
GREEN_FG='\033[38;2;0;210;106m'     # #00d26a
BLUE_BG='\033[48;2;52;152;219m'     # #3498DB
BLUE_FG='\033[38;2;52;152;219m'     # #3498DB
TEAL_BG='\033[48;2;62;177;163m'     # #3eb1a3
TEAL_FG='\033[38;2;62;177;163m'     # #3eb1a3
DARK_FG='\033[38;2;44;62;80m'       # #2C3E50 (text on colored bg)
RESET='\033[0m'

# Username segment
user=$(whoami)
printf "${DARK_BG}${RESET}\033[38;2;255;255;255m\033[48;2;44;62;80m ${user} ${RESET}"

# Directory segment
short_dir=$(echo "$cwd" | sed "s|$HOME|~|" | awk -F'/' '{
  n=NF
  if (n <= 3) { print $0 }
  else { print ".../" $(n-1) "/" $n }
}')
printf "${GREEN_FG}${RESET}${GREEN_BG}${DARK_FG} ${short_dir} ${RESET}"

# Git branch/status segment
git_branch=""
git_status_str=""
if git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null); then
  git_modified=$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^ M\|^M ' || true)
  git_untracked=$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^??' || true)
  git_staged=$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^[MADRCU]' || true)
  git_status_str=""
  [ "$git_staged" -gt 0 ] 2>/dev/null && git_status_str="${git_status_str}+${git_staged}"
  [ "$git_modified" -gt 0 ] 2>/dev/null && git_status_str="${git_status_str}~${git_modified}"
  [ "$git_untracked" -gt 0 ] 2>/dev/null && git_status_str="${git_status_str}?${git_untracked}"
  printf "${BLUE_FG}${GREEN_BG}${RESET}${BLUE_BG}${DARK_FG}  ${git_branch}${git_status_str:+ ${git_status_str}}${RESET}"
  printf "${TEAL_FG}${BLUE_BG}${RESET}"
else
  printf "${TEAL_FG}${GREEN_BG}${RESET}"
fi

# Model + context segment
ctx_str=""
if [ -n "$used" ]; then
  if [ -n "$total_tokens" ]; then
    total_k=$(echo "$total_tokens" | awk '{printf "%.0f", $1/1000}')
    used_k=$(awk -v u="$used" -v t="$total_tokens" 'BEGIN{printf "%.0f", (u/100)*t/1000}')
    ctx_str=" | ctx: ${used}%% (${used_k}k/${total_k}k)"
  else
    ctx_str=" | ctx: ${used}%%"
  fi
fi
printf "${TEAL_BG}${DARK_FG}  ${model}${ctx_str} ${RESET}${TEAL_FG}${RESET}"

printf "\n"
