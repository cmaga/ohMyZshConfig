# Small Plan Template

Use this template for plans with 1-3 files, 1-2 agents, no wave coordination needed.

---

## Output Format

```markdown
# Implementation Plan: [descriptive title]

## Overview
[2-3 sentence description of what this plan implements]

## Acceptance Criteria
- [ ] [criterion 1]
- [ ] [criterion 2]
- [ ] [criterion 3]

## Team Structure

**Lead**: Opus (coordination only — use delegate mode)

### Agent: implementer
- **Model**: Sonnet
- **Role**: [brief role description]
- **Files owned**: [exact file paths this agent may modify]
- **Spawn prompt**:
  ```
  [Complete spawn prompt built from agents/implementer.md template,
   filled in with task-specific details, file ownership, and
   verification commands]
  ```

### Agent: reviewer (if applicable)
- **Model**: Opus
- **Role**: Final quality gate
- **Files owned**: All (cleanup authority)
- **Depends on**: implementer
- **Spawn prompt**:
  ```
  [Complete spawn prompt built from agents/reviewer.md template]
  ```

## Tasks

### Task 1: [title]
- **ID**: 1
- **Assigned to**: implementer
- **Depends on**: none
- **Files**: [file paths]
- **Action**: [precise description of what to change]
- **Verification**: `[command]`
- **Done when**: [observable outcome]

### Task 2: [title]
...

### Task N: Review and validate
- **ID**: N
- **Assigned to**: reviewer
- **Depends on**: [all previous task IDs]
- **Verification**: [full verification suite]

## Final Verification
Run all of these after all tasks complete:
- `[test command]`
- `[lint command]`
- `[build command]`
- [any additional checks]

## Execution Instructions
Create an Agent Team called "[team-name]". Use delegate mode — the lead
coordinates only, it does not implement. Spawn agents in order, wait for
dependencies to resolve before spawning dependent agents. All teammates
use Sonnet except the reviewer which uses Opus.
```
