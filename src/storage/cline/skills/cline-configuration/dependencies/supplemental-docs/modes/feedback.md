# Mode: Feedback

Use this mode when the user has issues with existing configuration or when process changes require updating the automation plan (`.clinerules/` already exists).

## Step 1: Read Current Configuration

Read the project's Cline configuration to understand the current state:

- `.clineignore` file (if exists) to understand file access patterns
- All rule files (root level `.md` files in `.clinerules/`)
- All skills (`.clinerules/skills/`)
- All workflows (`.clinerules/workflows/`)
- All hooks (`.clinerules/hooks/`)
- Automation tracking (`.clinerules/automation/ROADMAP.md` and `PROGRESS.md`)

## Step 2: Understand the Requested Change

Determine what the user is asking for. Clarify with `ask_followup_question` if needed:

- What problem are you experiencing?
- What change are you requesting?
- What outcome do you expect?

## Step 3: Identify Scope of Change

Work top-down to determine the scope:

1. **Roadmap level**: Does this require changes to phase definitions, goals, or success criteria?
2. **Phase level**: Does it cascade to the current phase? (reset, adjust, or unchanged)
3. **Configuration level**: What specific files need to change? (.clineignore, rules, skills, workflows, hooks)
4. **History check**: Review PROGRESS.md - what didn't work in the past that we should avoid?

## Step 4: Propose a Plan

Present findings and proposed solution to the user:

**Summary:**

- **Original Problem**: What went wrong or what changed
- **Root Cause**: What caused the issue
- **Proposed Fix**: How we plan to address it
- **Prevention**: How we will avoid this in the future

**Proposed Changes:**

List each file with the exact changes to be made:

```txt
File: .clinerules/[filename]
Change: [Description of what will be modified]
```

**PROGRESS.md Update** (will be added when changes are implemented):

```markdown
## Session: [Date]

- Problem: [Original problem]
- Cause: [Root cause]
- Fix: [What was changed]
- Prevention: [How to avoid in future]
- Files: [List of files modified]
```

**Do NOT implement until user approves the plan.**

## Step 5: Implement Approved Changes

After user approval:

- Execute the approved changes
- Update `.clinerules/automation/PROGRESS.md` with session details and learnings
- Report what was changed

## Guidelines

- Always read the full configuration before making changes
- Learn from past mistakes (check PROGRESS.md history)
- Document learnings for future improvement
