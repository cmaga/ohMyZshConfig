# Mode: Progress

This mode is for when the user wants to advance to the next phase in the automation roadmap.

## Steps

### Step 1: Read Current State

Read `.clinerules/automation/ROADMAP.md` to understand:

- Current phase and its goals
- What configurations exist for current phase
- What's planned for next phase

Also read `.clinerules/automation/PROGRESS.md` to review recent session history.

### Step 2: Assess Stability History

Based on the progress history is there anything we can learn from how we write configurations?

### Step 3: Re-read Memory Bank

Read the **project's** `./docs/memory-bank/` to refresh context on project documentation.

### Step 4: Plan the next phase

- Are we keeping everything from the last phase?
- Is there anything we would like to change in the proposed phase we are transitioning to? Or does it look solid?
- Use learnings from the stabiliy history to propose new configurations

### Step 5: Update Roadmap

Update `.clinerules/automation/ROADMAP.md`:

- Mark current phase as complete
- Update "Current Phase" indicator
- Check off completed configurations
- Add any learnings or adjustments to Iteration Log

### Step 6: Update Progress Tracker

Log the phase advancement in `.clinerules/automation/PROGRESS.md`:

```markdown
## Session: [Date]

- Action: Advanced from Phase [N] to Phase [N+1]
- Configurations added: [List new files]
- Notes: [Any relevant context]
```

### Step 7: Report Summary

Report back with:

- What phase was completed
- Current phase goals and success criteria
- Recommended next steps

## Guidelines

- Only advance one phase at a time
- Don't skip phases - each builds on the previous
