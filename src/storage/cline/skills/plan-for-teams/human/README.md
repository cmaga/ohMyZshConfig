# Plan for Teams — User Guide

## What This Skill Does

This skill generates structured implementation plans that you paste into Claude
Code to kick off an Agent Team. It bridges the gap between planning (in Cline)
and execution (in Claude Code).

## When to Use

Use this skill after you've finished planning a feature or change with Cline and
are ready to hand off implementation. Typical triggers:

- "Create a team plan for this"
- "Hand this off to Claude Code"
- "Set up an agent team"
- "Write a plan for parallel implementation"

## How It Works

1. **You plan with Cline** — discuss the feature, make architecture decisions,
   resolve ambiguity
2. **Trigger the skill** — Cline extracts all decisions from your conversation
3. **Size classification** — the skill classifies the work as Small, Medium, or
   Large based on file count and complexity
4. **Agent selection** — appropriate specialist agents are chosen (backend,
   frontend, database, test, etc.)
5. **Plan generation** — a self-contained markdown plan is produced with:
   - Agent spawn prompts
   - Task assignments with dependencies
   - Wave-based execution ordering
   - Contracts between waves (data shapes, API signatures)
   - Verification commands for every task
6. **Handoff** — the plan is saved to `.claude/plans/<slug>.md` and you paste
   the execution prompt into Claude Code

## Plan Sizes

| Size   | Files | Agents | Waves | When                                |
| ------ | ----- | ------ | ----- | ----------------------------------- |
| Small  | 1-3   | 1-2    | 1     | Bug fix, config change, isolated    |
| Medium | 3-8   | 3-4    | 2-3   | Multi-module feature, API + UI      |
| Large  | 8+    | 4-6    | 3+    | Architectural change, cross-cutting |

## Key Concepts

### Waves

Tasks are grouped into waves based on dependencies. Wave 1 (foundation) must
complete before Wave 2 (implementation) can start. Agents within the same wave
run in parallel.

### Contracts

When agents in different waves depend on each other's output, contracts define
exactly what the earlier agent must produce (schema types, API signatures, etc.).
The Claude Code lead injects these into later agents' prompts.

### File Ownership

No two agents touch the same file. This prevents merge conflicts and makes
responsibility clear.

## After Execution

When Claude Code finishes, come back to Cline and use the
[cline-feature-creator](../cline-feature-creator/SKILL.md) improve mode to
provide feedback on how the plan performed. This feeds into the eval system
and improves future plans.
