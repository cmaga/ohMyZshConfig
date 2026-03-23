# Large Plan Template

Use this template for plans with 8+ files, 4-6 agents, multiple waves with
complex contract chains. Same structure as Medium but with additional waves
and coordination notes.

---

## Output Format

```markdown
# Implementation Plan: [descriptive title]

## Overview
[3-5 sentence description including the architectural approach and why it was chosen]

## Acceptance Criteria
- [ ] [criterion 1]
- [ ] [criterion 2]
...
- [ ] [criterion N]

## Architecture Notes
[Key architectural decisions made during planning. Include enough context that
agents understand WHY they're building things a certain way, not just WHAT.
This section prevents agents from "improving" the design in ways that conflict
with decisions already made.]

## Team Structure

**Lead**: Opus (coordination only — use delegate mode)

### Agent: [name] (Wave 1 — Foundation)
- **Model**: Sonnet
- **Role**: [role description]
- **Files owned**: [exact file paths]
- **Produces contracts**: [list]
- **Spawn prompt**:
  ```
  [Complete spawn prompt]
  ```

### Agent: [name] (Wave 2)
- **Model**: Sonnet
- **Role**: [role description]
- **Files owned**: [exact file paths — NO overlap with other Wave 2 agents]
- **Consumes contracts**: [list with INJECT_CONTRACT_FROM_[name] placeholders]
- **Produces contracts**: [if any]
- **Spawn prompt**:
  ```
  [Complete spawn prompt with contract injection placeholders]
  ```

### Agent: [name] (Wave 2, parallel)
[repeat for each Wave 2 agent]

### Agent: [name] (Wave 3)
- **Model**: Sonnet
- **Role**: [role description]
- **Files owned**: [exact file paths]
- **Consumes contracts**: [from Wave 1 AND/OR Wave 2]
- **Spawn prompt**:
  ```
  [Complete spawn prompt with all needed contract placeholders]
  ```

### Agent: reviewer (Final Wave)
- **Model**: Opus
- **Role**: Final quality gate
- **Files owned**: All (cleanup authority)
- **Depends on**: All other agents
- **Spawn prompt**:
  ```
  [Complete spawn prompt from agents/reviewer.md]
  ```

## Wave Execution Plan

### Wave 1: Foundation
**Agents**: [names]
**Purpose**: [what gets established — schemas, shared types, core configs]
**Completes when**: All Wave 1 tasks done, contracts delivered to lead
**Contract handoff**: Lead extracts contracts from completion messages and holds
them for injection into Wave 2 spawn prompts.

### Wave 2: Core Implementation
**Agents**: [names — run in parallel]
**Purpose**: [main feature work across independent domains]
**Consumes**: Wave 1 contracts
**Produces**: [any contracts needed by Wave 3]
**Completes when**: All Wave 2 tasks done
**File conflict risk**: [note any files that are close to the boundary between
agents — the lead should monitor these. If two agents MUST touch the same file,
assign it to one agent and have the other send a message requesting the change.]

### Wave 3: Integration (if needed)
**Agents**: [names]
**Purpose**: [wire together Wave 2 outputs, integration tests, cross-cutting concerns]
**Consumes**: Wave 1 + Wave 2 contracts
**Completes when**: All Wave 3 tasks done

### Final Wave: Review
**Agents**: reviewer
**Purpose**: Cross-cutting quality check
**Completes when**: All verification passes, completion report sent

## Contracts

### Contract: [name]
- **Produced by**: [agent] (Wave N)
- **Consumed by**: [agents] (Wave N+1)
- **Content**: [precise description of what must be delivered]
- **Delivery mechanism**: [completion message to lead / write to file path]

[repeat for each contract]

## Tasks

[Same format as Medium template — each task has ID, assigned agent, wave,
depends on, blocks, files, action, verification, done criteria, contract output]

## Coordination Notes

### File Conflict Prevention
[Explicitly list which agent owns which directory/file. If there are shared files,
designate one owner and describe how other agents request changes to it.]

### Agent Communication
[Describe any cases where agents should message each other directly rather than
going through the lead. E.g., "If the frontend agent needs clarification on an
API response shape, it should message the backend agent directly."]

### Failure Handling
If any agent fails (test doesn't pass, can't complete a task after 3 attempts):
1. Agent sends failure message to lead with error context
2. Lead does NOT attempt to fix it
3. Lead notifies the user with the error context
4. Pipeline pauses until user intervenes

## Final Verification
[same as Medium]

## Execution Instructions
Create an Agent Team called "[team-name]".

Use delegate mode — the lead coordinates only, does not implement.

Wave execution protocol:
1. Create ALL tasks upfront with their blockedBy relationships
2. Spawn Wave 1 agents
3. When Wave 1 completes, extract contracts from completion messages
4. Spawn Wave 2 agents with Wave 1 contracts injected into spawn prompts
5. When Wave 2 completes, extract any produced contracts
6. Spawn Wave 3 agents with accumulated contracts (if Wave 3 exists)
7. When all implementation waves complete, spawn reviewer
8. When reviewer reports done, notify the user

Critical: Write all contracts to files on disk IN ADDITION to sending via
message. Files survive context compaction, messages may not. Recommended
location: .claude/contracts/[team-name]/[contract-name].md

All implementation teammates use Sonnet. Reviewer uses Opus.
```
