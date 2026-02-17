# Tool Combinations

Advanced patterns for combining Cline's customization tools to maximize efficiency and minimize token usage.

## Overview

While individual tools (Rules, Skills, Workflows, Hooks, .clineignore) are powerful on their own, combining them strategically can create sophisticated automation patterns. Any number of tools can be combined/chained together. This guide showcases proven combinations with real-world examples.

## Pattern 1: Documentation-to-Skill Conversion

Transform heavy documentation into an efficient Rule + Skill pattern that loads knowledge only when needed.

### The Two-Component Architecture

Converting documentation to skills requires **two components working together**:

1. **Trigger Rule** (`.clinerules/`) - Lightweight, always loaded, tells Cline WHEN to use the skill
2. **Skill** (`.clinerules/skills/skill-name/`) - Heavy documentation, loaded on-demand

### Token Efficiency Principle

> **💡 Tip:** The goal is to minimize tokens loaded on tasks that don't need the documentation, while ensuring full documentation is available when it IS needed.

| Approach | Token Impact                | When Loaded        |
| -------- | --------------------------- | ------------------ |
| Before   | 200-line monolithic rule    | Every task         |
| After    | 5-line trigger rule + skill | Only when relevant |

### How to Decompose Documentation

Transform your documentation into a two-tier system:

**Original documentation** → Split into:

| Component               | Location                      | Content                                                       | Token Cost       |
| ----------------------- | ----------------------------- | ------------------------------------------------------------- | ---------------- |
| **Behavioral guidance** | Trigger Rule (`.clinerules/`) | When to use the SDK, priority instructions, critical patterns | ~50 tokens       |
| **Reference material**  | Skill (`skills/skill-name/`)  | API docs, sample code, troubleshooting guides                 | Loaded on-demand |

## Core Guidance

Any combination and chain of hooks, rules, workflows, and skills can be used to help Cline be better at self-reliance and independently completing tasks. Do not limit solutions to those in this guide—use them as inspiration and be creative.

Effective tool combinations:

- **Reduce token usage** through on-demand loading
- **Improve accuracy** by providing context when needed
- **Enforce standards** automatically
- **Scale knowledge** without bloating context
- **Provide guardrails** Cline responses are non-determinsitic and providing sufficient context/guidance is needed to help make cline more reliable.

> **💡 Tip:** The key is understanding what each tool does best and combining them strategically for specific project's needs.
