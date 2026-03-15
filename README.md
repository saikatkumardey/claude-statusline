# claude-statusline

A rich, information-dense statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows everything you need at a glance — git state, model, session cost, context usage, and more.

![claude-statusline preview](preview.png)

## What it shows

The statusline spans **two lines**:

**Line 1 — Git context**

| Segment | Description |
|---------|-------------|
| `myproject` | Current directory name |
| `main ✔` / `main ✗` | Branch + clean/dirty indicator |
| `3m` | Time since last commit |

**Line 2 — Claude session**

| Segment | Description |
|---------|-------------|
| `claude-sonnet-4-6` | Active model |
| `effort:auto` | Thinking effort (`auto` / `low` / `medium` / `high`) |
| `$0.042` | Session cost |
| `⏱5m` | Session age |
| `12k↑` | Total tokens used |
| `2x` / `1x` | Usage multiplier (green = peak, grey = off-peak) |
| `▓▓▓▓▓▓▓▓░░ 78%` | Context window remaining (green → yellow → red) |

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

Claude Code calls the statusline command on every refresh, passing a JSON blob via stdin. The script parses it with `jq` and builds an ANSI-colored string. See the [statusline docs](https://docs.anthropic.com/en/docs/claude-code/settings#status-line) for the full JSON schema.

## License

MIT
