#!/usr/bin/env python3
"""Lists error lines that recur across sessions' tool results, with the skills those sessions ran.

A session that recovers from a failing command on its own files no lesson, so friction a skill
causes can recur for months unrecorded. This reads every transcript under ~/.claude/projects
modified in the last --days, takes each tool result's error-looking lines (a pipe can hide the
exit code, so the text is read, not the error flag), normalizes numbers, ids and paths, and
prints each line seen in at least --min-sessions sessions: how many sessions and projects, the
command's first word, and which skills those sessions invoked. Attribution is the reviewer's call.

Usage: friction-scan.py [--days 30] [--min-sessions 3] [--top 25]
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import time
from pathlib import Path

PROJECTS = Path.home() / ".claude" / "projects"
ERROR = re.compile(
    r"\b(error|failed|fatal|refus\w*|denied|not found|no such|unrecognized|invalid|"
    r"cannot|can't|unable|traceback|exception|may not have access|forbidden|unauthori[sz]ed|"
    r"timed out)\b",
    re.IGNORECASE,
)
# Not a diagnostic: a test run's summary, or a line of file content (indented code, diff and grep
# -n lines, markdown, quotes) that merely contains an error word.
NOT_A_DIAGNOSTIC = re.compile(
    r"\b\d+ (passed|failed)\b|=====|^FAILED |^ERROR tests/|^\s|^[-+@#>*|`]|^\d+[:-]"
)
# Tools that show content rather than run anything; what they print is the file, not friction.
CONTENT_TOOLS = {"Read", "Grep", "Glob", "cat", "sed", "grep", "ugrep", "rg", "head", "tail", "awk", "less"}
LEADING_CD = re.compile(r"^(cd\s+\S+\s*(&&|;)\s*)+")
NORMALIZE = (
    (re.compile(r"/(Users|private|tmp|var|opt)/\S+"), "<path>"),
    (re.compile(r"\b[0-9a-f]{7,64}\b"), "<id>"),
    (re.compile(r"\b(toolu|msg|req)_\w+"), "<id>"),
    (re.compile(r"\d+(\.\d+)?"), "N"),
    (re.compile(r"\s+"), " "),
)


def session_of(path: Path) -> str:
    # A subagent's transcript sits under <session>/subagents/, at any depth; its failures are its
    # session's.
    parts = path.parts
    return parts[parts.index("subagents") - 1] if "subagents" in parts else path.stem


def normalize(line: str) -> str:
    for pattern, replacement in NORMALIZE:
        line = pattern.sub(replacement, line)
    return line.strip()[:140]


def text_of(content: object) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(part.get("text", "") for part in content if isinstance(part, dict))
    return ""


def scan(days: int) -> tuple[dict, dict, dict]:
    since = time.time() - days * 86400
    sightings: dict[tuple[str, str], set[str]] = collections.defaultdict(set)
    projects: dict[tuple[str, str], set[str]] = collections.defaultdict(set)
    skills: dict[str, set[str]] = collections.defaultdict(set)
    for path in PROJECTS.glob("*/**/*.jsonl"):
        if path.stat().st_mtime < since:
            continue
        session, project = session_of(path), path.relative_to(PROJECTS).parts[0]
        commands: dict[str, str] = {}
        for raw in path.open(encoding="utf-8", errors="replace"):
            try:
                content = (json.loads(raw).get("message") or {}).get("content")
            except (json.JSONDecodeError, AttributeError):
                continue
            if not isinstance(content, list):
                continue
            for part in content:
                if not isinstance(part, dict):
                    continue
                if part.get("type") == "tool_use":
                    tool_input = part.get("input") or {}
                    if part.get("name") == "Skill":
                        skills[session].add(str(tool_input.get("skill", "?")))
                    command = LEADING_CD.sub("", str(tool_input.get("command", "")).strip())
                    commands[part.get("id", "")] = command.split()[0] if command else part.get("name", "?")
                elif part.get("type") == "tool_result":
                    tool = commands.get(part.get("tool_use_id", ""), "?")
                    if tool in CONTENT_TOOLS:
                        continue
                    for line in text_of(part.get("content")).splitlines()[:40]:
                        if len(line) < 300 and ERROR.search(line) and not NOT_A_DIAGNOSTIC.search(line):
                            key = (tool, normalize(line))
                            sightings[key].add(session)
                            projects[key].add(project)
    return sightings, projects, skills


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--min-sessions", type=int, default=3)
    parser.add_argument("--top", type=int, default=25)
    args = parser.parse_args()
    sightings, projects, skills = scan(args.days)
    # One block per command: the sessions any of its error lines reached, then its commonest lines.
    by_tool: dict[str, list[tuple[str, set[str]]]] = collections.defaultdict(list)
    for (tool, line), sessions in sightings.items():
        by_tool[tool].append((line, sessions))
    blocks = []
    for tool, lines in by_tool.items():
        sessions = set().union(*(s for _, s in lines))
        if len(sessions) >= args.min_sessions:
            blocks.append((tool, sessions, sorted(lines, key=lambda item: -len(item[1]))))
    blocks.sort(key=lambda block: -len(block[1]))
    for tool, sessions, lines in blocks[: args.top]:
        ran = collections.Counter(skill for session in sessions for skill in skills.get(session, ()))
        top = ", ".join(f"{skill} {n}" for skill, n in ran.most_common(4)) or "no skill invoked"
        reach = {project for line, _ in lines for project in projects[(tool, line)]}
        print(f"{tool}: errors in {len(sessions)} sessions across {len(reach)} projects; skills run: {top}")
        for line, line_sessions in lines[:3]:
            print(f"    {len(line_sessions)} | {line}")
    if not blocks:
        print(f"no command errs in {args.min_sessions}+ sessions in the last {args.days} days")


if __name__ == "__main__":
    main()
