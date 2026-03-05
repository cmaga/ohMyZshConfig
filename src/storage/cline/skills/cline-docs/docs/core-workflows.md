# Core Workflows

## Tasks

A task is a self-contained work session with conversation history, code changes, and decisions.

### Task Structure

Each task:
- Has unique ID and dedicated storage directory
- Contains full conversation history
- Tracks token usage and API costs
- Creates checkpoints after file changes
- Can be interrupted and resumed across sessions

### Scoping

**One task = one goal.** Focused tasks produce better results because relevant context stays in the context window.

| Scenario | Action |
|----------|--------|
| Switching to different feature | New task |
| Building on work just completed | Continue |
| Cline keeps going off-track | New task |
| Iterating on same files | Continue |
| Refining Cline's last output | Continue |

Start new task: Click **+** button or use `/newtask` command.

### Context Window

Context fills with prompts, responses, file contents, command outputs, and system instructions. When approaching limit, Cline compresses older parts.

Reduce baseline usage with `.clineignore` to exclude dependencies and build artifacts.

## Plan & Act Mode

Separates thinking from doing.

### Plan Mode

Read-only exploration. Cline can read files, run searches, discuss strategy. Cannot modify files or execute commands.

Use for:
- Exploring unfamiliar codebases
- Architecture decisions
- Identifying edge cases
- Creating implementation strategy

### Act Mode

Execution mode. Cline can modify files, run commands, implement changes.

Conversation history carries over from Plan mode.

### Workflow

1. Start in Plan mode, describe goal
2. Let Cline explore relevant files
3. Discuss approach and edge cases
4. Switch to Act mode when confident
5. Cline implements the solution

### Different Models Per Mode

Enable "Use different models for Plan and Act" in settings. Common patterns:

| Use Case | Plan Mode | Act Mode |
|----------|-----------|----------|
| Cost optimization | Smaller model | Faster model |
| Maximum quality | Claude Opus | Claude Sonnet |

## Checkpoints

Git-based snapshots for rollback without losing conversation.

### How It Works

Shadow Git repository separate from project's actual Git. Commits after each tool use.

- Project Git history stays clean
- Captures everything including untracked files
- Persists across editor sessions

### Restore Options

| Option | Effect |
|--------|--------|
| Restore Files | Revert files, keep conversation |
| Restore Task Only | Delete messages, keep files |
| Restore Files & Task | Revert both |

### When to Use

| Scenario | Action |
|----------|--------|
| Cline broke something | Restore Files, ask for different approach |
| Experimenting with solutions | Compare checkpoints, restore best one |
| Cline misunderstood intent | Restore Files & Task, rephrase |
| Want to try different prompt | Restore Task Only |

## Adding Context (@ Mentions)

| Syntax | What It Does |
|--------|--------------|
| `@/path/to/file` | File content |
| `@/path/to/folder/` | Folder contents (trailing slash) |
| `@problems` | Workspace errors/warnings |
| `@terminal` | Recent terminal output |
| `@git-changes` | Uncommitted changes |
| `@<commit-hash>` | Specific commit diff |
| `@https://url` | Web page content |

### Multi-root Workspaces

Prefix with workspace name: `@workspace-name:/path/to/file`

### Drag & Drop

- Hold **Shift** while dragging files in VS Code
- Supports text files, images, PDFs, CSVs, Excel

### Context Menu Commands

Right-click selected code:
- **Add to Cline** - Start conversation with code context
- **Fix with Cline** - Quick fixes
- **Explain with Cline** - Understand complex code
- **Improve with Cline** - Refactoring suggestions

Terminal right-click: Add output to Cline for help with errors.

Source Control: "Generate Commit Message" from staged changes.

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/newtask` | Fresh task with distilled context from current conversation |
| `/smol` (or `/compact`) | Compress conversation, stay in same task |
| `/newrule` | Create rule file for preferences |
| `/deep-planning` | Investigate codebase, plan thoroughly, create implementation task |
| `/explain-changes` | AI explanations for git diffs (VS Code only) |
| `/reportbug` | Report bug with diagnostics |

### /newtask

Packages key decisions, file changes, and progress into new task with clean context. Use when context is 75%+ full mid-implementation.

### /smol

Compresses conversation without creating new task. Use when deep in debugging and need to continue same task.

### /deep-planning

Four-step process:
1. Silent investigation of codebase
2. Clarifying questions
3. Generate `implementation_plan.md`
4. Create task with trackable steps

Use for multi-file features, architectural changes, complex integrations.

### Custom Workflows

Create Markdown files in `.clinerules/workflows/`, invoke with `/your-workflow.md`.

## Cross-References

- Checkpoints + Auto-approve → See [features.md](features.md)
- Creating rules → See [customization.md](customization.md)
- Deep planning details → See [features.md](features.md)