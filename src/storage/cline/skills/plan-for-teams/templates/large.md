# Large Plan Template

Use this template for plans with 8+ files, 4-6 agents, multiple waves with
complex contract chains.

**Base structure**: Same as [medium.md](medium.md) with these additions. Read
medium.md first, then apply the extensions below.

## Additional Sections for Large Plans

The large template adds these sections that medium does not have. Include them
in the output plan alongside all the standard medium sections.

---

## Output Format Extensions

Add these sections to the medium template output:

### Architecture Notes (after Overview)

```markdown
## Architecture Notes

[Key architectural decisions made during planning. Include enough context that
agents understand WHY they're building things a certain way, not just WHAT.
This section prevents agents from "improving" the design in ways that conflict
with decisions already made.]
```

### Wave 3: Integration (in Wave Execution Plan)

```markdown
### Wave 3: Integration (if needed)

**Agents**: [names]
**Purpose**: [wire together Wave 2 outputs, integration tests, cross-cutting concerns]
**Consumes**: Wave 1 + Wave 2 contracts
**Completes when**: All Wave 3 tasks done
```

### Coordination Notes (after Tasks)

```markdown
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
```

### Modified Execution Instructions

Replace the medium execution instructions with:

```markdown
## Execution Instructions

Create an Agent Team called "[team-name]".

Use delegate mode — the lead coordinates only, does not implement.

Wave execution protocol:

1. Create ALL tasks upfront with their blockedBy relationships
2. Spawn Wave 1 agents
3. When Wave 1 completes, extract contracts from completion messages
4. Write contracts to `.claude/contracts/[team-name]/` — files survive context compaction
5. Spawn Wave 2 agents with Wave 1 contracts injected into spawn prompts
6. When Wave 2 completes, extract any produced contracts
7. Spawn Wave 3 agents with accumulated contracts (if Wave 3 exists)
8. When all implementation waves complete, spawn reviewer
9. When reviewer reports done, notify the user

All implementation teammates use Sonnet. Reviewer uses Opus.
```

## How to Fill This Template

1. Start with the medium template structure
2. Add the Architecture Notes section after Overview
3. Add Wave 3 if there are integration tasks that depend on Wave 2 outputs
4. Add Coordination Notes with file conflict prevention and agent communication rules
5. Add Failure Handling
6. Use the modified Execution Instructions above
7. For 4-6 agents, pay extra attention to file ownership — no overlaps
