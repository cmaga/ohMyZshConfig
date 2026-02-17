---
name: cline-configuration
description: Use when user wishes to update project specific cline configuration. Helps users bootstrap a cline configuraiton and create an automation plan to work towards.
---

# cline-configuration

The goal of this skill is to help users Bootstrap and evolve a custom Cline configuration tailored for a specific project, with the goal of **progressive automation toward autonomous Cline development**.

## Steps

### Step 1: Check Prerequisites

- Verify the target project has a `./docs/memory-bank/` directory
- If the memory bank doesn't exist, stop and tell the user to create it first

### Step 2: Deep dive available tools

Read the bundled Cline documentation to understand available automation features:

**Official Documentation:**

- Read all files in `dependencies/repos/cline/docs/customization/`

**Supplemental Guidance:**

- [dependencies/supplemental-docs/tool-combinations.md](dependencies/supplemental-docs/tool-combinations.md) - Advanced patterns for combining tools

### Step 3: Detect Mode

Determine which mode to operate in based on project state and user request:

| Condition                                                                                          | Mode           | Go To                                                                                                            |
| -------------------------------------------------------------------------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------- |
| No `.clinerules/` directory exists                                                                 | Initialization | [dependencies/supplemental-docs/modes/initialization.md](dependencies/supplemental-docs/modes/initialization.md) |
| `.clinerules/` exists + user mentions "progress cline configuration"                               | Progress       | [dependencies/supplemental-docs/modes/progress.md](dependencies/supplemental-docs/modes/progress.md)             |
| `.clinerules/` exists + user has issues, process changes, or mentions "update cline configuration" | Feedback       | [dependencies/supplemental-docs/modes/feedback.md](dependencies/supplemental-docs/modes/feedback.md)             |

### Step 4: Execute Mode

Follow the instructions in the linked mode file to complete the task.

## Self-improvement Guidelines

- If at any point you encounter ambiguity that affects your ability to complete these steps describe why to the user and start the sentence with "GLOBAL CLINE-CONFIGURATION SKILL ENCOUNTERED A PROBLEM: ..." so this skill can be continually improved.
