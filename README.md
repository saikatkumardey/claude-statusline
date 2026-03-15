# claude-statusline

A rich, adaptive statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows git state, model, session cost, context usage, and more — and adjusts automatically to your terminal width.

![claude-statusline preview](preview.png)

## What it shows

The layout adapts to your terminal width:

### Wide (≥ 80 cols) — full two-line display

| Line | Segments |
|------|----------|
| **Git** | `myproject` `main ✔` `3m` |
| **Session** | `sonnet` `auto` `$0.04` `⏱5m` `12k↑` `2x` `████░░ 78%` |

### Medium (50–79 cols) — compact two lines

| Line | Segments |
|------|----------|
| **Git** | `myproject` `main ✔` `3m` |
| **Session** | `sonnet` `$0.04` `⏱5m` `2x` `78%` |

### Narrow (< 50 cols) — single line, essentials only

```
myproject main ✔ $0.04 2x 78%
```

## Install

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/saikatkumardey/claude-statusline/main/install.sh | bash
```

This downloads the script, makes it executable, and patches your `~/.claude/settings.json` automatically.

### Manual

1. Download the script:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/saikatkumardey/claude-statusline/main/statusline.sh \
     -o ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash ~/.claude/statusline.sh"
     }
   }
   ```

3. Restart Claude Code.

### Let Claude do it

Just tell Claude Code:

> Use the statusline script from https://github.com/saikatkumardey/claude-statusline

It will run the install script for you.

## Requirements

- `bash` (pre-installed on macOS/Linux)
- [`jq`](https://jqlang.github.io/jq/) — `brew install jq` / `apt install jq`
- `bc` — `brew install bc` / `apt install bc`
- `git`

## Customisation

The script is a single, readable bash file. Edit `~/.claude/statusline.sh` directly — colors, segments, thresholds. Changes take effect on the next status refresh (no restart needed).

### Context battery colors

| Remaining | Color |
|-----------|-------|
| > 50% | Green |
| 21–50% | Yellow |
| ≤ 20% | Red |

### Effort mapping

Based on `thinking.budget_tokens`:

| Budget | Level |
|--------|-------|
| 0 / absent | `auto` |
| < 5,000 | `low` |
| 5,000–9,999 | `medium` |
| ≥ 10,000 | `high` |

### Usage multiplier

| Display | When | Color |
|---------|------|-------|
| `2x` | Weekdays outside 5–11 AM PT, weekends | Green |
| `1x` | Weekdays 5–11 AM PT (off-peak) | Grey |

## How it works

Claude Code calls the statusline command on every refresh, passing a JSON blob via stdin. The script reads the terminal width via `tput cols`, parses the JSON with `jq`, and builds an ANSI-colored string sized for the available space. See the [statusline docs](https://docs.anthropic.com/en/docs/claude-code/settings#status-line) for the full JSON schema.

## License

MIT
