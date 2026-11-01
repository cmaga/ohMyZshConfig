---
name: skill-eval
description: Runs a skill's saved eval cases with `claude plugin eval`, loading the skill the way a session does, and checks that the skill fired before reading any score. Use when the user asks to eval, benchmark, or run the saved cases of a skill in this repo.
---

# Skill eval

`claude plugin eval` loads only plugins. Pointed at a plain skill's folder, it loads the folder as a plugin, so every markdown file under a nested `commands/` becomes a slash command and the skill is lost among them. [scripts/eval.sh](scripts/eval.sh) copies the skill into a temporary plugin as `skills/<name>/` and its cases into `evals/`, gives the plugin a SessionStart hook ([scripts/run-env.sh](scripts/run-env.sh)) that sets up each run's shell, runs the eval there with auto memory off and no limit on how long a run waits for its background agents (print mode otherwise stops them 10 minutes after the main loop goes idle), and copies the results back.

## Run

Deploy leaves eval cases behind, so point the script at the skill's source folder:

    CLAUDE_CODE_EFFORT_LEVEL=xhigh bash ~/.claude/skills/skill-eval/scripts/eval.sh ~/dev/personal/ohMyZshConfig/src/storage/claude/skills/<name> --scaffold --allow-tools Write Edit Bash Agent ToolSearch WebSearch WebFetch --model opus --judge-model opus

- Every run costs usage, three per case in each arm by default, so start one only when the user asks. `--case <glob>` and `--runs <n>` narrow it.
- Runs go one at a time unless you pass `-j <n>` (up to 8). One at a time, a suite takes as long as all its runs together; a kitchen run can take 40 minutes.
- `--model opus` and `CLAUDE_CODE_EFFORT_LEVEL=xhigh` run each case on the session model and effort your roster sets. At the default effort, runs skipped the kitchen's steps that xhigh followed. The default judge, a small model, failed correct answers that were worded differently from the rubric, so the judge is `opus` too.
- Other options pass through to `claude plugin eval`. Give `--json` and `--report` absolute paths.
- Results land in the skill's eval folder under `results/<timestamp>/`, which git ignores.
- A run's shell can miss your shell functions, such as a lazily loaded nvm `node`. Put such a tool's directory on `PATH` when you start the script.

## Cases

Cases live in the skill's `evals/` or `dependencies/evals/`, one folder each with `prompt.md`, `case.yaml`, and `graders/`. Word each prompt the way a user would type it, never naming the skill.

Beside its cases, a case set can ship:

- `skills.txt` and `agents.txt`: other skills and agents of this repo the cases use, one name per line, loaded beside the skill. A run names a loaded agent `<skill>:<agent>`.
- `bin/`: stand-in commands, put first on each run's PATH.
- `session-start.sh`: run outside the sandbox as each run starts, to start what a stand-in talks to. The sandbox blocks sockets, localhost included, so a stand-in reaches it through files in the run's home.
- `stop.sh`: run outside the sandbox each time a run's session stops, before the graders read its files: the place for a check the run must not see, writing a file a grader reads with `{source: file, path}`. A file written at session end comes too late for the graders.

The hook also pins each run's `git` and its transport helpers to the ones your shell finds: the sandbox cannot reach Homebrew's git through its symlink, and `/usr/bin/git` fails there.

An `llm` grader on the trace sees only its first and last 12 messages, so check a step taken mid-run with a `tool_used` or `regex` grader, which see every message.

Every case carries this grader as `graders/00-skill-fired.md`, with the skill's name in place of `<name>`:

    ---
    type: tool_used
    tool: Skill
    input_match: '"skill"\s*:\s*"(?:[\w-]+:)?<name>"'
    ---

## Read the results

Read the skill-fired grader first. Where it failed, the with-skill arm ran without the skill and its score measures nothing: fix the skill's `description` and run again before reading any other grader.

The result's grader evidence leaves out the middle of each run. To read a whole run, pass `--keep-temp`; each run's `tracePath` then stays on disk.
