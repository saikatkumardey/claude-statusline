#!/bin/bash
# Claude Code Statusline
# https://github.com/saikatkumardey/claude-statusline
#
# Adapts to terminal width:
#   wide (≥80): two lines with full details
#   medium (50-79): two lines, compact
#   narrow (<50): single line, essentials only
#
# Requirements: bash, jq, git, bc
# Setup: see README.md

# Read JSON input from stdin
input=$(cat)

# Terminal width
cols=$(tput cols 2>/dev/null || echo 80)

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

# Shorten path to current directory name only
short_path=$(basename "$cwd")

# Color codes
blue=$(printf '\033[1;34m')
green=$(printf '\033[32m')
red=$(printf '\033[31m')
white=$(printf '\033[37m')
grey=$(printf '\033[90m')
yellow=$(printf '\033[33m')
orange=$(printf '\033[38;5;208m')
reset=$(printf '\033[0m')

# Shorten model name to just sonnet/opus/haiku and pick color
short_model=""
model_color="$grey"
if [[ -n "$model" ]]; then
  case "$model" in
    *sonnet*) short_model="sonnet"; model_color="$orange" ;;
    *opus*)   short_model="opus";   model_color="$red" ;;
    *haiku*)  short_model="haiku";  model_color="$grey" ;;
    *)        short_model="${model#claude-}"; model_color="$grey" ;;
  esac
fi

# Session cost
cost_display=""
if [[ -n "$total_cost" ]] && (( $(echo "$total_cost > 0" | bc -l 2>/dev/null) )); then
  if (( $(echo "$total_cost < 0.10" | bc -l 2>/dev/null) )); then
    cost_display=$(printf '$%.3f' "$total_cost")
  else
    cost_display=$(printf '$%.2f' "$total_cost")
  fi
fi

# Session age
age_display=""
if [[ -n "$total_duration_ms" ]] && [[ "$total_duration_ms" -gt 0 ]]; then
  total_seconds=$(( total_duration_ms / 1000 ))
  age_hours=$(( total_seconds / 3600 ))
  age_minutes=$(( (total_seconds % 3600) / 60 ))
  if [[ $age_hours -gt 0 ]]; then
    age_display="$(printf '%dh%dm' $age_hours $age_minutes)"
  else
    age_display="$(printf '%dm' $age_minutes)"
  fi
fi

# Total tokens
total_tokens=$(( total_input_tokens + total_output_tokens ))
tokens_display=""
if [[ $total_tokens -gt 0 ]]; then
  if [[ $total_tokens -ge 1000 ]]; then
    tokens_display="$(( total_tokens / 1000 ))k↑"
  else
    tokens_display="${total_tokens}↑"
  fi
fi

# Usage multiplier
pt_hour=$(TZ=America/Los_Angeles date +%H | sed 's/^0//')
pt_dow=$(TZ=America/Los_Angeles date +%u)  # 1=Mon, 7=Sun
if [[ $pt_dow -ge 6 ]] || [[ $pt_hour -lt 5 ]] || [[ $pt_hour -ge 11 ]]; then
  multiplier="2x"
  mult_color="$green"
else
  multiplier="1x"
  mult_color="$grey"
fi

# Context remaining
remaining_int=""
pct_color=""
if [[ -n "$remaining" ]]; then
  remaining_int=${remaining%.*}
  if [[ $remaining_int -le 20 ]]; then
    pct_color="$red"
  elif [[ $remaining_int -le 50 ]]; then
    pct_color="$yellow"
  else
    pct_color="$green"
  fi
fi

# Git info
git_status=""
commit_age=""
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
  fi
fi

# --- Build battery bar ---
build_bar() {
  local segments=$1
  local filled=$(( (remaining_int * segments + 99) / 100 ))
  local empty=$(( segments - filled ))
  local seg_bg empty_bg bar=""

  if [[ $remaining_int -le 20 ]]; then
    seg_bg=$(printf '\033[48;5;203m')
  elif [[ $remaining_int -le 50 ]]; then
    seg_bg=$(printf '\033[48;5;220m')
  else
    seg_bg=$(printf '\033[48;5;83m')
  fi
  empty_bg=$(printf '\033[48;5;237m')

  for ((s=0; s<filled; s++)); do bar="${bar}${seg_bg} ${reset}"; done
  for ((s=0; s<empty; s++)); do bar="${bar}${empty_bg} ${reset}"; done
  echo -n "$bar"
}

# --- Layout based on terminal width ---
if [[ $cols -lt 50 ]]; then
  # NARROW: single line — dir branch cost multiplier ctx%
  output="${blue}${short_path}${reset}"
  [[ -n "$git_status" ]] && output="${output} ${git_status}"
  [[ -n "$cost_display" ]] && output="${output} ${white}${cost_display}${reset}"
  output="${output} ${mult_color}${multiplier}${reset}"
  [[ -n "$remaining_int" ]] && output="${output} ${pct_color}${remaining_int}%${reset}"

elif [[ $cols -lt 80 ]]; then
  # MEDIUM: two lines, no battery bar, no tokens
  output="${blue}${short_path}${reset}"
  [[ -n "$git_status" ]] && output="${output} ${git_status}"
  [[ -n "$commit_age" ]] && output="${output} ${white}${commit_age}${reset}"
  output="${output}
"
  [[ -n "$short_model" ]] && output="${output}${model_color}${short_model}${reset}"
  [[ -n "$cost_display" ]] && output="${output} ${white}${cost_display}${reset}"
  [[ -n "$age_display" ]] && output="${output} ${grey}⏱${age_display}${reset}"
  output="${output} ${mult_color}${multiplier}${reset}"
  [[ -n "$remaining_int" ]] && output="${output} ${pct_color}${remaining_int}%${reset}"

else
  # WIDE: two lines, full details with battery bar
  output="${blue}${short_path}${reset}"
  [[ -n "$git_status" ]] && output="${output} ${git_status}"
  [[ -n "$commit_age" ]] && output="${output} ${white}${commit_age}${reset}"
  output="${output}
"
  if [[ -n "$short_model" ]]; then
    if [[ -n "$effort" ]]; then
      output="${output}${model_color}${short_model}${reset} ${grey}${effort}${reset}"
    else
      output="${output}${model_color}${short_model}${reset}"
    fi
  fi
  [[ -n "$cost_display" ]] && output="${output} ${white}${cost_display}${reset}"
  [[ -n "$age_display" ]] && output="${output} ${grey}⏱${age_display}${reset}"
  [[ -n "$tokens_display" ]] && output="${output} ${grey}${tokens_display}${reset}"
  output="${output} ${mult_color}${multiplier}${reset}"
  if [[ -n "$remaining_int" ]]; then
    bar=$(build_bar 8)
    output="${output} ${bar} ${pct_color}${remaining_int}%${reset}"
  fi
fi

printf '%s' "${output}"
echo
