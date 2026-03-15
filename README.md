# claude-statusline

A rich, information-dense statusline for [Claude Code](https://claude.ai/code) that shows everything you need at a glance — git state, model, session cost, context battery, and more.

## What it shows

![claude-statusline preview](preview.png)

The statusline spans **two lines**:

**Line 1 — git context**

| Segment | Description |
|---------|-------------|
| `~/work/myproject` | Last 3 path components (blue) |
| `main ✔` / `main ✗` | Git branch + clean/dirty indicator |
| `3m` | Time since last git commit |

**Line 2 — Claude session info**

| Segment | Description |
|---------|-------------|
| `claude-sonnet-4-6` | Active Claude model |
| `effort:auto` | Thinking effort level (`auto` / `low` / `medium` / `high`) |
| `$0.042` | Session cost so far |
| `⏱5m` | Session age |
| `12k↑` | Total tokens used this session |
| `1x` / `2x` | Usage multiplier — green 2x during peak, grey 1x during off-peak |
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

### Tell Claude to set it up

You can also just tell Claude Code directly:

> Use the statusline script from https://github.com/saikatkumardey/claude-statusline

Claude Code will run the install script for you.

## Requirements

- `bash` (pre-installed on macOS/Linux)
- `jq` — `brew install jq` or `apt install jq`
- `bc` — `brew install bc` or `apt install bc`
- `git` (for git segments)

## Customisation

The script is intentionally a single, readable bash file. Open `~/.claude/statusline.sh` and edit any section — colors, segments, thresholds — directly. Changes take effect on the next status refresh (no restart needed).

**Color thresholds for context battery:**
- >50% remaining → green
- 21–50% → yellow
- ≤20% → red

**Effort mapping** (based on `thinking.budget_tokens`):
- 0 / absent → `auto`
- <5 000 → `low`
- 5 000–9 999 → `medium`
- ≥10 000 → `high`

**Usage multiplier:**
- `2x` (green) — weekdays outside 5–11am PT, and all day on weekends (peak)
- `1x` (grey) — weekdays 5–11am PT (off-peak)

## How it works

Claude Code calls the statusline command on every status refresh and passes a JSON blob via stdin. The script parses the JSON with `jq` and builds an ANSI-colored string. See [Claude Code statusline docs](https://docs.anthropic.com/en/docs/claude-code/settings#status-line) for the full JSON schema.

## License

MIT
