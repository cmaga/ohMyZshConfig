# Update Memory Bank Workflow

## Brief overview

Workflow for updating/creating the persistent memory bank documentation that maintains project context across Cline sessions.

## Update Process

When updating the memory bank, follow these steps:

### Step 1: Review or Initialize Memory Bank

**If memory bank exists:**

- Read all files in `docs/memory-bank/` to understand current documentation state

**If memory bank is missing:**

- Create `docs/memory-bank/` directory
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

Investigate the project to understand any architectural changes:

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
- Add learnings and insights

#### progress.md

- Update what's working
- Document what's left to build
- Record current status
- Add or resolve known issues
- Track evolution of project decisions

### Step 4: Update Other Files as Needed

Review and update if changes occurred:

#### systemPatterns.md

- New architectural decisions
- Updated design patterns
- Changed component relationships
- Modified implementation paths

#### techContext.md

- New technologies or dependencies
- Changed development setup
- Updated constraints or requirements

#### projectBrief.md & productContext.md

- Usually stable, update only if fundamental changes occur

### Step 5: Report Updates

Summarize what was updated:

- Which files were modified
- Key changes documented
- New insights captured

## Additional Context Files

Create additional files/folders within `docs/memory-bank/` when needed:

- **Complex features** → `features/[feature-name].md`
- **API specifications** → `api/[service-name].md`
- **Integration docs** → `integrations/[system-name].md`
- **Testing strategies** → `testing/[test-type].md`
- **Deployment procedures** → `deployment/[environment].md`

Guidelines for additional files:

- Create when core files become too large or unfocused
- Use clear, descriptive naming
- Reference from relevant core files
- Maintain same documentation standards

## Important Notes

- **Always review ALL files** - Even if not all need updates
- **Be comprehensive** - **After every memory reset, I begin completely fresh. The Memory Bank is my only link to previous work.** It must be maintained with precision and clarity, as my effectiveness depends entirely on its accuracy.
- **Preserve context** - Don't remove historical decisions, explain evolution
