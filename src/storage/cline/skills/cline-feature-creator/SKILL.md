---
name: cline-feature-creator
description: Create and improve Cline features (rules, skills, workflows, hooks, .clineignore) with best practices for writing LLM instructions. Use when the user wants to create a new cline feature, build a skill, add a rule, set up a workflow, create a hook, or configure .clineignore. Also use when the user wants to improve an existing skill based on feedback, or asks about best practices for writing markdown instructions for LLMs. Even if the user just says they want to automate something or add custom behavior to Cline, this skill can help determine the right feature type.
---

# Cline Feature Creator

Create new Cline features and improve existing skills through a guided, best-practice-driven workflow.

## Detect Mode

| Condition                               | Mode    | Action                              |
| --------------------------------------- | ------- | ----------------------------------- |
| User wants to create something new      | Create  | Go to [Create Mode](#create-mode)   |
| User wants to improve an existing skill | Improve | Go to [Improve Mode](#improve-mode) |

## Create Mode

### Step 1: Determine Scope

Ask the user whether this feature should be global or project-scoped:

| Scope       | Save Location                                                             | When to Use                   |
| ----------- | ------------------------------------------------------------------------- | ----------------------------- |
| **Global**  | This repo (`src/storage/cline/skills/`, `src/storage/cline/rules/`, etc.) | Available across all projects |
| **Project** | Current project (`.clinerules/`, `.cline/skills/`, etc.)                  | Scoped to one project         |

### Step 2: Capture Intent

Understand what the user wants. Start with understanding why
the user is asking for the feature. How do we make their job
easier?

### Step 3: Select Feature Type

Read [docs/feature-selection.md](docs/feature-selection.md) and use the decision tree to recommend the right feature type. Present the recommendation with a one-line justification. WAIT for user approval
before moving to the next step.

### Step 4: Load Writing Guide

Read [docs/writing-guide.md](docs/writing-guide.md). Apply these principles to everything you write for the user. Do not present the guide to the user — just follow it.

### Step 5: Guided Creation

Read the feature-specific reference and template:

| Feature Type | Reference                                              | Template                                             |
| ------------ | ------------------------------------------------------ | ---------------------------------------------------- |
| Rule         | [references/rules.md](references/rules.md)             | [templates/rule.md](templates/rule.md)               |
| Skill        | [references/skills.md](references/skills.md)           | [templates/skill/SKILL.md](templates/skill/SKILL.md) |
| Workflow     | [references/workflows.md](references/workflows.md)     | [templates/workflow.md](templates/workflow.md)       |
| Hook         | [references/hooks.md](references/hooks.md)             | [templates/hook.sh](templates/hook.sh)               |
| .clineignore | [references/clineignore.md](references/clineignore.md) | N/A                                                  |

Read the doc references to create the feature. Ask the user for any additional information needed.

### Step 6: Save and Validate

Save the feature to the correct location based on scope (Step 1).

**If creating a skill:**

1. Run structural validation: `python scripts/validate.py <path-to-skill-directory>`
2. Copy [templates/evals.yaml](templates/evals.yaml) into the skill's `evals/` directory, filling in the `skill` and `created` fields
3. Add a feedback collection section at the bottom of the skill's SKILL.md (see [references/skills.md](references/skills.md) for the pattern)

**For all other feature types:** Save and confirm with the user. No additional scaffolding needed.

---

## Improve Mode

**Skills only.** For rules, workflows, hooks, and .clineignore — just edit them directly; they are simple and deterministic enough not to need the feedback loop.

### Step 1: Load Context

1. Read the skill's SKILL.md and any bundled resources
2. Read `evals/evals.yaml` — the append-only event log containing all feedback, analyses, and changes

### Step 2: Analyze

Scan the log chronologically:

- Find all `type: feedback` entries
- Find the most recent `type: analysis` entry — note which feedback IDs were already reviewed
- Identify new feedback since last analysis
- Check `type: change` entries for previously failed approaches (`result: reverted` with `lesson`)
- Cluster new feedback by theme, identify recurring issues and root causes

### Step 3: Recommend

Append a new `type: analysis` entry to `evals/evals.yaml` with:

- `reviewed_feedback`: all feedback IDs reviewed (including previous)
- `recurring_issues`: with frequency counts
- `root_causes`: hypothesized causes
- `recommendations`: suggested changes with confidence
- `anti_recommendations`: approaches tried and failed (from prior `type: change` entries with `result: reverted`)

Present recommendations to the user with clear reasoning.

### Step 4: Apply Changes

After user approval:

1. Read [docs/writing-guide.md](docs/writing-guide.md) — apply to all rewrites
2. Make the approved changes to the skill
3. Run structural validation: `python scripts/validate.py <path-to-skill-directory>`
4. Append a `type: change` entry to `evals/evals.yaml` with version, trigger, description, and result

---

## Self-Improvement

If you encounter ambiguity that prevents completing these steps, tell the user starting with: "CLINE-FEATURE-CREATOR SKILL ENCOUNTERED A PROBLEM: ..." so this skill can be improved.
