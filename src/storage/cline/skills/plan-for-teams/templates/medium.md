# Medium Plan Template

Use this template for plans with 3-8 files, 3-4 agents, wave coordination
with contracts between waves.

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
- [ ] [criterion 4]
- [ ] [criterion 5]

## Team Structure

**Lead**: Opus (coordination only — use delegate mode)

### Agent: [name] (Wave 1)
- **Model**: Sonnet
- **Role**: [role description]
- **Files owned**: [exact file paths]
- **Produces contracts**: [what this agent must output for downstream agents]
- **Spawn prompt**:
  ```
  [Complete spawn prompt from appropriate agents/*.md template.
   Include: role, tasks, files owned, verification commands,
   and contract obligations.]
  ```

### Agent: [name] (Wave 2)
- **Model**: Sonnet
- **Role**: [role description]
- **Files owned**: [exact file paths]
- **Consumes contracts**: [what this agent needs from Wave 1]
- **Produces contracts**: [if any, for downstream]
- **Spawn prompt**:
  ```
  [Complete spawn prompt. Include UPSTREAM CONTRACTS section
   with placeholder: INJECT_CONTRACT_FROM_[wave1-agent-name].
   The lead will replace this placeholder with the actual contract
   content from the Wave 1 agent's completion message.]
  ```

### Agent: [name] (Wave 2, parallel)
- **Model**: Sonnet
- **Role**: [role description]
- **Files owned**: [exact file paths — must NOT overlap with other Wave 2 agents]
- **Consumes contracts**: [what this agent needs from Wave 1]
- **Spawn prompt**:
  ```
  [Complete spawn prompt with contract injection placeholder]
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
**Agents**: [agent name(s)]
**Purpose**: [what foundation work gets done]
**Completes when**: All Wave 1 tasks marked complete and contracts delivered

**Contract handoff**: When Wave 1 agents complete, they send a message to the
lead containing their produced contracts. The lead extracts these and injects
them into Wave 2 spawn prompts before spawning Wave 2 agents.

### Wave 2: Implementation
**Agents**: [agent names — these run in parallel]
**Purpose**: [what gets built]
**Consumes**: Contracts from Wave 1
**Completes when**: All Wave 2 tasks marked complete

### Final Wave: Review
**Agents**: reviewer
**Purpose**: Cross-cutting quality check, fix issues, verify integration
**Completes when**: All verification commands pass, completion report sent

## Contracts

### Contract: [name, e.g., "Database Schema"]
- **Produced by**: [agent name] (Wave 1)
- **Consumed by**: [agent names] (Wave 2)
- **Content**: [describe exactly what the producing agent must include in their
  completion message. E.g., "Exact table definitions with column types, TypeScript
  interfaces that mirror the schema, all enums and constants." Be specific enough
  that the lead knows what to extract and paste.]

### Contract: [name, e.g., "API Signatures"]
- **Produced by**: [agent name] (Wave 2)
- **Consumed by**: [agent names] (later waves or reviewer)
- **Content**: [exact description]

## Tasks

### Task 1: [title]
- **ID**: 1
- **Assigned to**: [agent name]
- **Wave**: 1
- **Depends on**: none
- **Blocks**: [task IDs that depend on this]
- **Files**: [file paths]
- **Action**: [precise description]
- **Verification**: `[command]`
- **Done when**: [observable outcome]
- **Contract output**: [what this task produces for downstream — or "none"]

### Task 2: [title]
- **ID**: 2
- **Assigned to**: [agent name]
- **Wave**: 2
- **Depends on**: 1
- **Blocks**: [task IDs]
- **Files**: [file paths]
- **Action**: [precise description]
- **Verification**: `[command]`
- **Done when**: [observable outcome]

...

### Task N: Review and validate
- **ID**: N
- **Assigned to**: reviewer
- **Wave**: Final
- **Depends on**: [all previous task IDs]
- **Action**: Review all changes, fix issues, run full verification suite
- **Verification**: [all verification commands]

## Final Verification
Run all of these after all tasks complete:
- `[test command]`
- `[lint command]`
- `[build command]`
- [any additional checks]

## Execution Instructions
Create an Agent Team called "[team-name]".

Use delegate mode — the lead coordinates only, does not implement.

Wave execution protocol:
1. Create all tasks with their dependency (blockedBy) relationships
2. Spawn Wave 1 agents. Wait for them to complete and deliver contracts.
3. Extract contract content from Wave 1 completion messages.
4. Spawn Wave 2 agents with contracts injected into their spawn prompts.
   Replace INJECT_CONTRACT_FROM_[name] placeholders with actual content.
5. Wait for Wave 2 to complete.
6. Spawn reviewer agent.
7. When reviewer reports done, notify the user.

All implementation teammates use Sonnet. Reviewer uses Opus.
```
