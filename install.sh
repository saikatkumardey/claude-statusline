#!/bin/bash
# One-liner installer for claude-statusline
# Usage: curl -fsSL https://raw.githubusercontent.com/saikatkumardey/claude-statusline/main/install.sh | bash

set -e

SCRIPT_URL="https://raw.githubusercontent.com/saikatkumardey/claude-statusline/main/statusline.sh"
DEST="$HOME/.claude/statusline.sh"
SETTINGS="$HOME/.claude/settings.json"

echo "→ Installing claude-statusline..."

# Download the script
curl -fsSL "$SCRIPT_URL" -o "$DEST"
chmod +x "$DEST"
echo "✔ Script installed to $DEST"

# Check for jq dependency
if ! command -v jq &>/dev/null; then
  echo "⚠  jq is not installed. Install it with: brew install jq  (macOS) or  apt install jq  (Linux)"
fi

# Check for bc dependency
if ! command -v bc &>/dev/null; then
  echo "⚠  bc is not installed. Install it with: brew install bc  (macOS) or  apt install bc  (Linux)"
fi

# Patch settings.json
if [[ -f "$SETTINGS" ]]; then
  # Check if statusLine is already set
  if jq -e '.statusLine' "$SETTINGS" > /dev/null 2>&1; then
    echo "⚠  settings.json already has a statusLine entry — skipping (edit manually if needed)"
  else
    tmp=$(mktemp)
    jq --arg cmd "bash $DEST" '. + {statusLine: {type: "command", command: $cmd}}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "✔ settings.json updated"
  fi
else
  mkdir -p "$(dirname "$SETTINGS")"
  echo "{\"statusLine\": {\"type\": \"command\", \"command\": \"bash $DEST\"}}" > "$SETTINGS"
  echo "✔ settings.json created"
fi

echo ""
echo "✔ Done! Restart Claude Code to see your new statusline."
echo ""
echo "  Looks like:  ~/work/myproject main ✔ 3m | claude-sonnet-4-6 effort:auto \$0.042 ⏱5m 12k↑ ▓▓▓▓▓▓▓▓░░ 78%"
