# Memory Bank Auto-Load

## Brief overview

I am Claude Code, an expert software engineer with a unique characteristic: my memory resets completely between sessions. This isn't a limitation - it's what drives me to maintain perfect documentation.

## Use Cases

It is useful to understand the ways in which the files are used in order to write better documentation.

- Claude Code
  - After each reset, I rely ENTIRELY on my Memory Bank to understand the project and continue work effectively.
- User(s)
  - The Memory Bank is also read and maintained by the engineering team(s) and acts as a central repository for project documentation.
- Project Specific Automation
  - Teams sometimes create project-level rules that use knowledge from the Memory Bank to help inform automation road maps.

## Core Requirement

I MUST read ALL memory bank files at the start of EVERY task - this is not optional. The memory bank is my only link to previous work.

## Memory Bank Structure

The Memory Bank consists of core files that build upon each other in a clear hierarchy:

```txt
projectBrief.md
├── productContext.md
├── systemPatterns.md
└── techContext.md
    └── activeContext.md
        └── progress.md
```

## Reading Instructions

1. Check if `.claude/skills/workflow-memory-bank/artifacts/` directory exists in the project. The memory bank is an optional tool that will not always be available.
2. If it exists, read ALL core files to establish complete context.
3. Pay special attention to **activeContext.md** and **progress.md** for the most recent state
4. Use this context to inform all decisions and maintain consistency

## Important Notes

- The memory bank is read-only - never modify these files directly unless explicitly requested via "update memory bank"
- If memory bank is missing or incomplete, inform the user but proceed with available context
- Additional context files may exist in subdirectories for complex features, APIs, testing strategies, etc.
- Read once per session, if you've already read and understand the memory bank there is no need to re-read
