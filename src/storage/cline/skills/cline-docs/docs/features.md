# Features

## Memory Bank

Documentation methodology for persistent context across sessions. Structured markdown files that Cline reads at session start.

### Structure

```
memory-bank/
├── projectbrief.md      # Foundation: core requirements
├── productContext.md    # Why project exists
├── activeContext.md     # Current focus (updates most)
├── systemPatterns.md    # Architecture & patterns
├── techContext.md       # Tech stack & setup
└── progress.md          # Status & milestones
```

### Key Commands

- "follow your custom instructions" - Read Memory Bank, continue work
- "initialize memory bank" - Create initial structure
- "update memory bank" - Full documentation review

### Integration

- Pairs with Plan/Act mode (read in Plan, implement in Act)
- Use `/newtask` or `/smol` to manage context window
- Enable Auto-Compact for automatic context management
- Memory Bank preserves *knowledge*, Checkpoints preserve *code state*

---

## Focus Chain

Automatic todo list management with real-time progress tracking.

### How It Works

1. Cline analyzes request, creates todo list
2. Stores as editable markdown file
3. Updates progress in real-time
4. Shows progress indicator in task header (e.g., "3/8")

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Enable Focus Chain | Disabled | Enable todo tracking |
| Remind Cline Interval | 6 | How often to update (1-100 messages) |

### Best For

- Multi-step implementations
- Tasks spanning multiple context windows
- Visibility into Cline's plan

---

## Auto-Approve

Control which actions Cline can take without prompting.

### Permissions

| Setting | Allows |
|---------|--------|
| Read project files | Read, list, search in workspace |
| Read all files | Read outside workspace (requires base toggle) |
| Edit project files | Create/edit in workspace |
| Edit all files | Edit outside workspace (requires base toggle) |
| Execute safe commands | Run safe terminal commands |
| Execute all commands | Run approval-required commands |
| Use the browser | Browser tool |
| Use MCP servers | MCP tools and resources |

### Safe vs Approval-Required

Model marks each command with `requires_approval` flag. Not a fixed allowlist.

**Commonly safe**: `npm run build`, `git status`, `ls`, `cat`
**Commonly requires approval**: `npm install <pkg>`, `rm -rf`, `mv`, `sed -i`

### YOLO Mode

Auto-approves everything. All file operations, all commands, browser, MCP, mode transitions.

**Use for**: Rapid prototyping, trusted repetitive tasks, demonstrations.

**Risk**: Can delete files, modify system settings, push to git without warning.

---

## Auto-Compact

Automatic context summarization when approaching context limits.

### How It Works

1. Monitors token usage
2. When close to limit, creates comprehensive summary
3. Preserves technical details, code changes, decisions
4. Replaces conversation with summary
5. Continues where it left off

### Supported Models

Claude 4, Gemini 2.5, GPT-5, Grok 4 series use advanced LLM summarization. Others fall back to rule-based truncation.

### Cost

Leverages existing prompt cache, costs about the same as any tool call.

### Integration

- Works with Focus Chain (todo lists persist across summarizations)
- Use Checkpoints to restore pre-summarization state

---

## Subagents

Parallel research agents that explore codebase without filling main context.

### Capabilities

| Tool | Purpose |
|------|---------|
| `read_file` | Read file contents |
| `list_files` | List directory contents |
| `search_files` | Regex search |
| `list_code_definition_names` | List classes, functions |
| `execute_command` | Read-only commands |
| `use_skill` | Load skills |

**Cannot**: Write files, use browser, access MCP, spawn nested subagents.

### When to Use

- Onboarding to unfamiliar project
- Cross-cutting concerns (trace auth, logging, errors simultaneously)
- Pre-edit research to gather context
- Large codebases where sequential reads would consume too much context

### Enabling

Settings → Features → Subagents toggle. Must explicitly ask for subagents in prompt.

---

## Deep Planning

`/deep-planning` - Thorough codebase investigation before implementation.

### Process

1. **Silent Investigation** - Reads files, traces dependencies, builds mental model
2. **Discussion** - Asks targeted questions based on findings
3. **Plan Creation** - Generates `implementation_plan.md`
4. **Task Creation** - New task with implementation steps

### vs Plan Mode

| | Plan Mode | Deep Planning |
|---|-----------|---------------|
| Scope | Quick exploration | Thorough investigation |
| Output | Conversation | `implementation_plan.md` file |
| Best for | Medium tasks | Large multi-file features |
| Duration | Minutes | Longer |

### Best For

- Features touching multiple files
- Architectural changes
- Complex integrations
- Tasks where you'd whiteboard before coding

---

## Background Edit

File changes without opening diff editor tabs.

### How It Works

- Edits write directly to files
- Changes appear as collapsible diffs in chat panel
- Editor focus stays on current file

### Best For

- Auto-approve workflows
- Many small file changes
- Staying focused on current file

### Enable

Settings → Feature Settings → Enable Background Edit

---

## Worktrees

Work on multiple branches simultaneously in separate folders.

### Key Concepts

- **Main worktree**: Original repo with `.git` directory
- **Linked worktrees**: Additional folders checked out to different branches
- **Shared history**: All worktrees share commits and Git config

### Why Use With Cline

- Run Cline on multiple tasks in parallel (separate windows)
- Keep working while Cline works in another worktree
- Isolate experimental changes
- Quick context switching without stashing

### Quick Start

1. Click **New Worktree Window** on home screen
2. Enter branch name and path
3. New VS Code window opens with Cline ready

### .worktreeinclude

Auto-copy files to new worktrees (e.g., `node_modules/`). Only copies files that match both `.worktreeinclude` AND `.gitignore`.

```gitignore
node_modules/
.vscode/
.env.local
```

### Merging

Click merge icon on worktree → Review details → Choose to delete after merge → Click Merge.

If conflicts: "Ask Cline to Resolve" creates task to handle conflicts.

---

## Cross-References

- Memory Bank + Checkpoints → Knowledge vs code state protection
- Focus Chain + Auto-Compact → Todo lists persist across summarizations
- Deep Planning + Focus Chain → Plan then track execution
- Worktrees + CLI → See [cli.md](cli.md) for `--cwd` workflows
- Auto-Approve + Checkpoints → Safety net for autonomous work