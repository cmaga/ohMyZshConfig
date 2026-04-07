---
name: workflow-memory-bank
description: Workflow for updating/creating persistent memory bank documentation
disable-model-invocation: true
---

# Update Memory Bank

Workflow for updating/creating the persistent memory bank documentation that maintains project context across Claude Code sessions.

**Important:** All paths in this skill are relative to the project root (current working directory), not the global `~/.claude/` directory. Each project maintains its own independent memory bank.

## Update Process

### Step 1: Review or Initialize Memory Bank

**If memory bank exists:**

- Read all files in `.claude/skills/workflow-memory-bank/` to understand current documentation state

**If memory bank is missing:**

- Create `.claude/skills/workflow-memory-bank/` directory
- Initialize all core files with basic structure:
  - `projectBrief.md` - Gather from README, package files, and project structure
  - `productContext.md` - Derive from existing documentation and code purpose
  - `activeContext.md` - Start with current working state and obvious next steps
  - `systemPatterns.md` - Analyze architecture from code structure
  - `techContext.md` - Extract from package files, configs, and dependencies
  - `progress.md` - Assess what exists and what appears incomplete
- Gather project information from available sources (README, code, configs)
- Interview user for missing context if needed

### Step 2: Investigate Documentation Deviations (Optional)

**Only perform this step if you're not confident about recent changes or architectural deviations.**

- Check if implementation matches documented architecture
- Identify what deviated and why
- Determine if deviations are mistakes or intentional improvements
- If uncertain, validate with the user

### Step 3: Update/Create Core Files

Focus updates on the most dynamic files:

#### activeContext.md

- Document current work focus
- Record recent changes and their impact
- Update next steps and priorities
- Capture active decisions and considerations
- Document important patterns discovered

#### progress.md

- Update what's working
- Document what's left to build
- Record current status
- Add or resolve known issues
- Track evolution of project decisions

### Step 4: Update Other Files as Needed

#### systemPatterns.md

- New architectural decisions
- Updated design patterns
- Changed component relationships

#### techContext.md

- New technologies or dependencies
- Changed development setup
- Updated constraints or requirements

#### projectBrief.md & productContext.md

- Usually stable, update only if fundamental changes occur

### Step 5: Report Updates

- Which files were modified
- Key changes documented
- New insights captured

## Additional Context Files

Create additional files/folders within `.claude/skills/workflow-memory-bank/` when needed:

- **Complex features** - `features/[feature-name].md`
- **API specifications** - `api/[service-name].md`
- **Integration docs** - `integrations/[system-name].md`
- **Testing strategies** - `testing/[test-type].md`
- **Deployment procedures** - `deployment/[environment].md`

Guidelines:

- Create when core files become too large or unfocused
- Use clear, descriptive naming
- Reference from relevant core files

## Important Notes

- **Always review ALL files** - Even if not all need updates
- **Be comprehensive** - The Memory Bank is the only link to previous work. Maintain with precision and clarity
- **Preserve context** - Don't remove historical decisions, explain evolution
