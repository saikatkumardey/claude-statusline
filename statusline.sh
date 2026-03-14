#!/bin/bash
# Claude Code Statusline
# https://github.com/saikatkumardey/claude-statusline
#
# Shows: directory · git branch/status/age · model · effort · cost · session age · tokens · context battery
#
# Requirements: bash, jq, git, bc
# Setup: see README.md

# Read JSON input from stdin
input=$(cat)

# Extract fields from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
total_input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Extract effort level: try known candidate paths, fall back to "auto"
effort=$(echo "$input" | jq -r '
  if .thinking.budget_tokens? != null then
    if .thinking.budget_tokens == 0 then "auto"
    elif .thinking.budget_tokens >= 10000 then "high"
    elif .thinking.budget_tokens >= 5000 then "medium"
    else "low"
    end
  elif .api_configuration.thinking_budget_tokens? != null then
    if .api_configuration.thinking_budget_tokens == 0 then "auto"
    elif .api_configuration.thinking_budget_tokens >= 10000 then "high"
    elif .api_configuration.thinking_budget_tokens >= 5000 then "medium"
    else "low"
    end
  else
    "auto"
  end
' 2>/dev/null || echo "")

# Shorten path to last 3 components (like %3~ in zsh)
IFS='/' read -ra path_parts <<< "$cwd"
path_len=${#path_parts[@]}
if [ $path_len -le 3 ]; then
  short_path="$cwd"
else
  start_idx=$((path_len - 3))
  short_path="${path_parts[$start_idx]}"
  for ((i=start_idx+1; i<path_len; i++)); do
    short_path="$short_path/${path_parts[$i]}"
  done
fi
short_path="${short_path/#$HOME/\~}"

# Color codes
blue=$(printf '\033[1;34m')
green=$(printf '\033[32m')
red=$(printf '\033[31m')
cyan=$(printf '\033[36m')
white=$(printf '\033[37m')
grey=$(printf '\033[90m')
yellow=$(printf '\033[33m')
reset=$(printf '\033[0m')

output=""

# User@host (SSH or switched user only)
if [[ -n "$SSH_CONNECTION" ]]; then
  output="${cyan}$(whoami)@$(hostname -s)${reset}:"
elif [[ "$LOGNAME" != "$USER" ]]; then
  output="${cyan}$(whoami)${reset}:"
fi

# Directory
output="${output}${blue}${short_path}${reset} "

# Git: branch + clean/dirty + time since last commit
if git --no-optional-locks rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || \
           git --no-optional-locks rev-parse --short HEAD 2>/dev/null)

  if git --no-optional-locks diff --quiet 2>/dev/null && \
     git --no-optional-locks diff --cached --quiet 2>/dev/null; then
    git_status="${green}${branch} ✔${reset}"
  else
    git_status="${green}${branch}${reset} ${red}✗${reset}"
  fi

  if last_commit=$(git --no-optional-locks -c log.showSignature=false log --format='%at' -1 2>/dev/null); then
    now=$(date +%s)
    seconds_since_last_commit=$((now - last_commit))
    minutes=$((seconds_since_last_commit / 60))
    hours=$((minutes / 60))
    days=$((hours / 24))
    years=$((days / 365))

    if [[ $years -gt 0 ]]; then
      commit_age="${years}y$((days % 365))d"
    elif [[ $days -gt 0 ]]; then
      commit_age="${days}d$((hours % 24))h"
    elif [[ $hours -gt 0 ]]; then
      commit_age="${hours}h$((minutes % 60))m"
    else
      commit_age="${minutes}m"
    fi

    output="${output}${git_status} ${white}${commit_age}${reset}"
  else
    output="${output}${git_status}"
  fi
fi

# Model + effort
if [[ -n "$model" ]]; then
  if [[ -n "$effort" ]]; then
    output="${output} ${grey}|${reset} ${grey}${model} effort:${effort}${reset}"
  else
    output="${output} ${grey}|${reset} ${grey}${model}${reset}"
  fi
fi

# Session cost
if [[ -n "$total_cost" ]] && (( $(echo "$total_cost > 0" | bc -l 2>/dev/null) )); then
  if (( $(echo "$total_cost < 0.10" | bc -l 2>/dev/null) )); then
    cost_display=$(printf '$%.3f' "$total_cost")
  else
    cost_display=$(printf '$%.2f' "$total_cost")
  fi
  output="${output} ${white}${cost_display}${reset}"
fi

# Session age
if [[ -n "$total_duration_ms" ]] && [[ "$total_duration_ms" -gt 0 ]]; then
  total_seconds=$(( total_duration_ms / 1000 ))
  age_hours=$(( total_seconds / 3600 ))
  age_minutes=$(( (total_seconds % 3600) / 60 ))
  if [[ $age_hours -gt 0 ]]; then
    age_display="$(printf '%dh%dm' $age_hours $age_minutes)"
  else
    age_display="$(printf '%dm' $age_minutes)"
  fi
  output="${output} ${grey}⏱${age_display}${reset}"
fi

# Total tokens used this session
total_tokens=$(( total_input_tokens + total_output_tokens ))
if [[ $total_tokens -gt 0 ]]; then
  if [[ $total_tokens -ge 1000 ]]; then
    tokens_display="$(( total_tokens / 1000 ))k↑"
  else
    tokens_display="${total_tokens}↑"
  fi
  output="${output} ${grey}${tokens_display}${reset}"
fi

# Context battery bar (10 segments, color-coded)
if [[ -n "$remaining" ]]; then
  remaining_int=${remaining%.*}

  if [[ $remaining_int -le 20 ]]; then
    bar_color="$red"
  elif [[ $remaining_int -le 50 ]]; then
    bar_color="$yellow"
  else
    bar_color="$green"
  fi

  filled=$(( (remaining_int + 9) / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for ((s=0; s<filled; s++)); do bar="${bar}▓"; done
  for ((s=0; s<empty; s++)); do bar="${bar}░"; done

  output="${output} ${bar_color}${bar} ${remaining_int}%${reset}"
fi

printf '%s' "${output}"
echo
