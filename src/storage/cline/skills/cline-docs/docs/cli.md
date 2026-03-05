# Cline CLI

## Overview

Cline CLI brings Cline to the terminal. Two modes:

- **Interactive Mode**: Collaborative, real-time development
- **Headless Mode**: Automation, CI/CD, scripting

## Interactive Mode

Activates when running `cline` without flags in a terminal.

```bash
cline
```

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Tab` | Toggle Plan/Act mode |
| `Shift+Tab` | Toggle auto-approve all |
| `Esc` | Exit/cancel |
| `Enter` | Submit message |
| `↑`/`↓` | Navigate history |
| `Ctrl+C` | Exit with summary |

### Features

- **File mentions**: `@src/utils.ts` with fuzzy search
- **Slash commands**: `/settings`, `/models`, `/history`, `/clear`, `/help`
- **Settings panel**: Configure providers, models, features
- **Session summaries**: Tasks completed, files modified, tokens used

## Headless Mode

Activates with `-y`, `--json`, piped input, or redirected output.

```bash
# Auto-approve all actions (YOLO mode)
cline -y "Run tests and fix failures"

# JSON output for parsing
cline --json "List TODO comments" | jq '.text'

# Piped input
cat README.md | cline "Summarize this"

# Chained commands
git diff | cline -y "explain" | cline -y "write commit message"
```

### Mode Detection

| Invocation | Mode | Reason |
|------------|------|--------|
| `cline` | Interactive | No args, TTY connected |
| `cline "task"` | Interactive | TTY connected |
| `cline -y "task"` | Headless | YOLO flag |
| `cline --json "task"` | Headless | JSON flag |
| `cat file \| cline` | Headless | Piped stdin |
| `cline > output.txt` | Headless | Redirected stdout |

### Flags

| Flag | Purpose |
|------|---------|
| `-y` / `--yolo` | Auto-approve all actions |
| `-p` | Start in Plan mode |
| `-a` | Start in Act mode |
| `--json` | JSON output |
| `-i <image>` | Attach image |
| `--timeout <seconds>` | Max execution time |
| `--config <dir>` | Custom config directory |

## Configuration

### Config Command

```bash
cline config
```

Tabs: Settings, Rules, Workflows, Hooks, Skills

### Directory Structure

```
~/.cline/
├── data/
│   ├── globalState.json
│   ├── secrets.json
│   ├── settings/
│   │   └── cline_mcp_settings.json
│   ├── workspace/
│   └── tasks/
└── log/
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `CLINE_DIR` | Custom config directory |
| `CLINE_COMMAND_PERMISSIONS` | Restrict allowed commands |

### Command Permissions

```bash
export CLINE_COMMAND_PERMISSIONS='{
  "allow": ["npm *", "git *"],
  "deny": ["rm -rf *", "sudo *"],
  "allowRedirects": true
}'
```

## Multiple Instances

Use `--config` for isolated configurations:

```bash
cline --config ~/.cline-work "task"
cline --config ~/.cline-personal "task"
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Install Cline
  run: npm install -g cline

- name: Configure Cline
  run: cline auth -p anthropic -k ${{ secrets.ANTHROPIC_API_KEY }}

- name: Review PR
  run: |
    git diff origin/main...HEAD | cline -y "Review this PR"
```

### Common Use Cases

| Use Case | Command |
|----------|---------|
| Code review | `git diff \| cline -y "Review"` |
| Fix tests | `cline -y "Run tests and fix failures"` |
| Release notes | `git log v1.0..v1.1 \| cline -y "Write release notes"` |
| Fix lint | `cline -y "Fix ESLint errors"` |
| PR review | `gh pr diff 123 \| cline -y "Review"` |

## MCP Configuration

CLI uses same MCP config format as VS Code extension.

Settings file: `~/.cline/data/settings/cline_mcp_settings.json`

```json
{
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["/path/to/server.js"],
      "env": { "API_KEY": "key" }
    }
  }
}
```

## Worktree Integration

Use `--cwd` for worktree workflows:

```bash
# Parallel tasks in different worktrees
cline --cwd ~/worktree-a -y "refactor auth" &
cline --cwd ~/worktree-b -y "add tests" &
wait
```

## Troubleshooting

### View Logs

```bash
cline dev log
```

### Reset Configuration

```bash
rm -rf ~/.cline/data/
cline auth  # Re-authenticate
```

## Cross-References

- Worktrees → See [features.md](features.md)
- MCP servers → See [mcp.md](mcp.md)
- Rules/Workflows/Hooks → See [customization.md](customization.md)