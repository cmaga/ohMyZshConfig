# Mode: Initialization

Use this mode when setting up Cline for a project for the first time (no `.clinerules/` directory exists).

## Step 1: Read Memory Bank

Read all files in the **project's** `./docs/memory-bank/` directory to understand the project's tech stack, architecture, conventions, and current state.

## Step 2: Gather Development Context

Use `ask_followup_question` to progressively gather context not found in the memory bank. **Ask questions one topic at a time** in a conversational manner.

**Important:** This step is ONLY for gathering information. Do not suggest specific configurations yet - save all suggestions for Step 3.

### Progressive Questioning Approach:

**Stage 1: Essential Context (Start Here)**
Ask first to understand the basics:

- "Are you working on this project solo or as part of a team? And what's your current development workflow like (e.g., using tickets, PRs, specific branching strategy)?"

**Stage 2: Pain Points (Based on Stage 1 response)**
If they mention specific workflow elements, ask about related challenges:

- "What are your biggest pain points when working with Cline on this project?"

**Stage 3: Automation Vision (After understanding current state)**
Once you understand their current workflow, explore automation goals:

- "What repetitive tasks would you most like to automate with Cline?"
- If relevant: "What does your ideal automated workflow look like?"

**Stage 4: Optional Deep Dive (Only if user is engaged)**
If the user is providing detailed responses and seems engaged, you may ask about:

- Quality gates or checks they always want Cline to pass
- Specific coding conventions not in the memory bank
- Testing requirements or deployment processes

#### Important Guidelines

- **Keep it conversational** - Don't present a wall of questions
- **Make it clear questions are optional** - Start with "To set up your Cline configuration optimally, I'd like to understand your development context better"
- **Allow skipping** - If user seems eager to proceed, offer to use defaults
- **Adapt based on responses** - Skip questions if information is already provided
- **Use options when helpful** - Provide multiple choice for common patterns

Continue the conversation until you have enough understanding to create a useful initial configuration, but don't force extensive questioning if the user wants to proceed quickly.

## Step 3: Plan Configuration

After gathering all context, now plan what configurations to create:

1. **Analyze the gathered information** from the memory bank and user interview
2. **Propose initial configurations** for Phase 1:
   - What rules should be created (consider conditional rules for path-specific guidance)
   - What patterns should be excluded in .clineignore (dependencies, build artifacts, etc.)
   - What skills would be helpful (ensure NO skills modify ./docs/memory-bank/)
   - What workflows to automate repetitive tasks
   - What hooks for quality gates (8 types available: TaskStart, TaskResume, TaskCancel, TaskComplete, PreToolUse, PostToolUse, UserPromptSubmit, PreCompact)
3. **Present the proposal** to the user for approval:
   - List each configuration with its purpose
   - Explain how they address the user's pain points
   - Ask for confirmation before proceeding

**Note:** Ensure no configurations modify ./docs/memory-bank/ - it is read-only user documentation.

## Step 4: Create Directory Structure

Create the initial structure in the **project root**:

```txt
.clineignore              (file access control - see Cline docs)
.clinerules/
├── automation/
│   ├── ROADMAP.md       (automation roadmap - see templates/roadmap.md)
│   └── PROGRESS.md      (session tracking - see templates/progress-tracker.md)
├── (rule files at root level)
├── skills/
│   └── (skill directories with SKILL.md)
├── workflows/
│   └── (workflow .md files)
└── hooks/
    └── (hook scripts)
```

Note: ROADMAP.md and PROGRESS.md are placed in `automation/` subdirectory so Cline doesn't interpret them as rules.

## Step 5: Generate Automation Roadmap

Create `.clinerules/automation/ROADMAP.md` using [templates/roadmap.md](../templates/roadmap.md), customized based on interview answers.

## Step 6: Generate Initial Configuration

Generate **Phase 1** tool configurations based on memory bank and interview context:

- **Create .clineignore** with appropriate patterns for the project (node_modules, build outputs, etc.)
- **Create rules** (consider using conditional rules with YAML frontmatter for path-specific activation)
- **Create skills** for common project-specific tasks
- **Create workflows** for repetitive processes
- **Create hooks** for quality gates (choose from 8 available hook types)

## Step 7: Create Progress Tracker

Create `.clinerules/automation/PROGRESS.md` using [templates/progress-tracker.md](../templates/progress-tracker.md) to track this session and future sessions.

## Step 8: Report Summary

Report back with a simple summary of 1-3 sentences covering what was created.

## Guidelines

- **Memory Bank is Read-Only**: Never suggest or create configurations that modify ./docs/memory-bank/. The memory bank is user-maintained documentation that Cline only reads for context.
- **Separate Gathering from Planning**: During Step 2 (Gather Development Context), focus only on understanding the user's needs. Save all configuration suggestions for Step 3.
- **Progressive Disclosure**: Don't overwhelm users during the interview phase. Ask questions progressively and allow them to skip to defaults if desired.
- **Phase-Based Approach**: Start with minimal Phase 1 configurations. More advanced automation should be added in later phases as the user becomes comfortable.
