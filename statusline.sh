#!/bin/bash
# Claude Code Statusline
# https://github.com/saikatkumardey/claude-statusline
#
# Two-line aesthetic layout with separators and icons
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

# Extract effort level
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

# Shorten path
short_path=$(basename "$cwd")

# ── Colors ────────────────────────────────────────────────────────────────
bold=$(printf '\033[1m')
dim=$(printf '\033[2m')
blue=$(printf '\033[38;5;75m')
cyan=$(printf '\033[38;5;117m')
green=$(printf '\033[38;5;114m')
red=$(printf '\033[38;5;204m')
white=$(printf '\033[97m')
grey=$(printf '\033[38;5;242m')
yellow=$(printf '\033[38;5;222m')
orange=$(printf '\033[38;5;209m')
magenta=$(printf '\033[38;5;183m')
reset=$(printf '\033[0m')

# Separator
sep="${grey} ~ ${reset}"

# ── Model ─────────────────────────────────────────────────────────────────
short_model=""
model_color="$grey"
if [[ -n "$model" ]]; then
  model_lower=$(echo "$model" | tr '[:upper:]' '[:lower:]')
  case "$model_lower" in
    *sonnet*) short_model="sonnet"; model_color="$orange" ;;
    *opus*)   short_model="opus";   model_color="$magenta" ;;
    *haiku*)  short_model="haiku";  model_color="$cyan" ;;
    *)        short_model="$model"; model_color="$grey" ;;
  esac
fi

# ── Cost ──────────────────────────────────────────────────────────────────
cost_display=""
if [[ -n "$total_cost" ]] && (( $(echo "$total_cost > 0" | bc -l 2>/dev/null) )); then
  if (( $(echo "$total_cost < 0.10" | bc -l 2>/dev/null) )); then
    cost_display=$(printf '$%.3f' "$total_cost")
  else
    cost_display=$(printf '$%.2f' "$total_cost")
  fi
fi

# ── Session age ───────────────────────────────────────────────────────────
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

# ── Tokens ────────────────────────────────────────────────────────────────
total_tokens=$(( total_input_tokens + total_output_tokens ))
tokens_display=""
if [[ $total_tokens -gt 0 ]]; then
  if [[ $total_tokens -ge 1000000 ]]; then
    tokens_display="$(printf '%.1fM' "$(echo "$total_tokens / 1000000" | bc -l)")"
  elif [[ $total_tokens -ge 1000 ]]; then
    tokens_display="$(( total_tokens / 1000 ))k"
  else
    tokens_display="${total_tokens}"
  fi
fi

# ── Usage multiplier ─────────────────────────────────────────────────────
pt_hour=$(TZ=America/Los_Angeles date +%H | sed 's/^0//')
pt_dow=$(TZ=America/Los_Angeles date +%u)
if [[ $pt_dow -ge 6 ]] || [[ $pt_hour -lt 5 ]] || [[ $pt_hour -ge 11 ]]; then
  multiplier="2x"
  mult_color="$green"
else
  multiplier="1x"
  mult_color="$yellow"
fi

# ── Context remaining ────────────────────────────────────────────────────
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

# ── Git info ─────────────────────────────────────────────────────────────
git_status=""
commit_age=""
if git --no-optional-locks rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || \
           git --no-optional-locks rev-parse --short HEAD 2>/dev/null)

  if git --no-optional-locks diff --quiet 2>/dev/null && \
     git --no-optional-locks diff --cached --quiet 2>/dev/null; then
    git_status="${green}${branch}${reset} ${green}*${reset}"
  else
    git_status="${green}${branch}${reset} ${red}*${reset}"
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

# ── Context bar (iOS-style battery) ──────────────────────────────────────
build_bar() {
  local segments=$1
  local filled=$(( (remaining_int * segments + 99) / 100 ))
  local empty=$(( segments - filled ))
  local bar=""

  # iOS-style: green when healthy, yellow when mid, red when low
  local seg_bg
  if [[ $remaining_int -le 20 ]]; then
    seg_bg=$(printf '\033[48;5;203m')   # red
  elif [[ $remaining_int -le 50 ]]; then
    seg_bg=$(printf '\033[48;5;220m')   # yellow
  else
    seg_bg=$(printf '\033[48;5;83m')    # green
  fi
  local empty_bg=$(printf '\033[48;5;237m')  # dark grey
  # Build filled + empty blocks
  for ((s=0; s<filled; s++)); do bar="${bar}${seg_bg} ${reset}"; done
  for ((s=0; s<empty; s++)); do bar="${bar}${empty_bg} ${reset}"; done

  echo -n "${grey}[${reset}${bar}${grey}]${reset}"
}

# ══════════════════════════════════════════════════════════════════════════
# Line 1:  dir ~ branch * ~ model effort ~ [====----] 72%
# Line 2:  $0.42 ~ 12m ~ 48k tok ~ 2x
# ══════════════════════════════════════════════════════════════════════════

# --- Line 1 ---
line1="${blue}${bold}${short_path}${reset}"
[[ -n "$git_status" ]]  && line1="${line1}${sep}${git_status}"
[[ -n "$commit_age" ]]  && line1="${line1} ${dim}${grey}${commit_age}${reset}"

if [[ -n "$short_model" ]]; then
  model_part="${model_color}${bold}${short_model}${reset}"
  [[ -n "$effort" ]] && model_part="${model_part} ${grey}${effort}${reset}"
  line1="${line1}${sep}${model_part}"
fi

if [[ -n "$remaining_int" ]]; then
  if [[ $cols -ge 80 ]]; then
    bar=$(build_bar 10)
    line1="${line1}${sep}${bar} ${pct_color}${remaining_int}%${reset}"
  else
    line1="${line1}${sep}${pct_color}${remaining_int}%${reset}"
  fi
fi

# --- Line 2 ---
line2_parts=()
[[ -n "$cost_display" ]]   && line2_parts+=("${yellow}${cost_display}${reset}")
[[ -n "$age_display" ]]    && line2_parts+=("${grey}${age_display}${reset}")
[[ -n "$tokens_display" ]] && line2_parts+=("${cyan}${tokens_display} tok${reset}")
line2_parts+=("${mult_color}${multiplier}${reset}")

line2=""
for part in "${line2_parts[@]}"; do
  [[ -n "$line2" ]] && line2="${line2}${sep}"
  line2="${line2}${part}"
done

printf '%s\n%s\n' "${line1}" "${line2}"
