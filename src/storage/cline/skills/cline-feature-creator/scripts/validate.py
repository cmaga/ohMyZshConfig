#!/usr/bin/env python3
"""Structural validation for Cline skills.

Usage: python validate.py <path-to-skill-directory>

Checks:
  - SKILL.md exists
  - Frontmatter has name and description fields
  - Directory name matches name field
  - SKILL.md body is under 500 lines
  - No bullets nested deeper than 2 levels
  - All markdown link targets exist as files
  - No hedging phrases (try to, consider, you might want to)
"""

import os
import re
import sys


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def parse_frontmatter(content):
    """Extract YAML frontmatter from markdown content using regex (no PyYAML dependency)."""
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if not match:
        return None, content
    fm_text = match.group(1)
    fm = {}
    for line in fm_text.splitlines():
        kv = re.match(r"^(\w[\w-]*):\s*(.*)", line)
        if kv:
            fm[kv.group(1)] = kv.group(2).strip()
    body = content[match.end():]
    return fm, body


def check_skill_md_exists(skill_dir):
    path = os.path.join(skill_dir, "SKILL.md")
    if not os.path.isfile(path):
        return [f"FAIL: SKILL.md not found in {skill_dir}"]
    return []


def check_frontmatter(skill_dir):
    errors = []
    content = read_file(os.path.join(skill_dir, "SKILL.md"))
    fm, _ = parse_frontmatter(content)

    if fm is None:
        errors.append("FAIL: No YAML frontmatter found in SKILL.md")
        return errors

    if "name" not in fm:
        errors.append("FAIL: Missing 'name' field in frontmatter")
    if "description" not in fm:
        errors.append("FAIL: Missing 'description' field in frontmatter")

    return errors


def check_name_match(skill_dir):
    errors = []
    dir_name = os.path.basename(os.path.normpath(skill_dir))
    content = read_file(os.path.join(skill_dir, "SKILL.md"))
    fm, _ = parse_frontmatter(content)

    if fm and "name" in fm:
        if fm["name"] != dir_name:
            errors.append(
                f"FAIL: Directory name '{dir_name}' does not match "
                f"frontmatter name '{fm['name']}'"
            )
    return errors


def check_line_count(skill_dir):
    errors = []
    content = read_file(os.path.join(skill_dir, "SKILL.md"))
    _, body = parse_frontmatter(content)
    line_count = len(body.strip().splitlines())

    if line_count > 500:
        errors.append(
            f"WARN: SKILL.md body is {line_count} lines (recommended: under 500)"
        )
    return errors


def check_nesting_depth(skill_dir):
    errors = []
    content = read_file(os.path.join(skill_dir, "SKILL.md"))
    _, body = parse_frontmatter(content)

    for i, line in enumerate(body.splitlines(), start=1):
        # Count leading spaces before a bullet marker
        match = re.match(r"^(\s+)[-*+]", line)
        if match:
            indent = len(match.group(1))
            # 2 spaces per level, depth > 2 means indent >= 6
            if indent >= 6:
                errors.append(
                    f"WARN: Line {i} has bullet nesting deeper than 2 levels"
                )
    return errors


def check_file_references(skill_dir):
    errors = []
    content = read_file(os.path.join(skill_dir, "SKILL.md"))
    _, body = parse_frontmatter(content)

    # Find markdown links: [text](path)
    links = re.findall(r"\[.*?\]\((.*?)\)", body)
    for link in links:
        # Skip URLs and anchors
        if link.startswith("http") or link.startswith("#"):
            continue
        # Resolve relative to skill directory
        target = os.path.normpath(os.path.join(skill_dir, link))
        if not os.path.exists(target):
            errors.append(f"WARN: Reference target not found: {link}")

    return errors


def check_hedging(skill_dir):
    errors = []
    content = read_file(os.path.join(skill_dir, "SKILL.md"))
    _, body = parse_frontmatter(content)

    hedging_phrases = [
        r"\btry to\b",
        r"\byou might want to\b",
        r"\bconsider\b",
        r"\bperhaps\b",
        r"\bmaybe you could\b",
    ]

    for i, line in enumerate(body.splitlines(), start=1):
        for pattern in hedging_phrases:
            if re.search(pattern, line, re.IGNORECASE):
                errors.append(
                    f"WARN: Line {i} contains hedging phrase: "
                    f"'{re.search(pattern, line, re.IGNORECASE).group()}'"
                )
    return errors


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path-to-skill-directory>")
        sys.exit(1)

    skill_dir = sys.argv[1]
    if not os.path.isdir(skill_dir):
        print(f"Error: {skill_dir} is not a directory")
        sys.exit(1)

    all_errors = []

    # Run checks in order
    all_errors.extend(check_skill_md_exists(skill_dir))
    if all_errors:
        # Can't continue without SKILL.md
        for e in all_errors:
            print(e)
        sys.exit(1)

    all_errors.extend(check_frontmatter(skill_dir))
    all_errors.extend(check_name_match(skill_dir))
    all_errors.extend(check_line_count(skill_dir))
    all_errors.extend(check_nesting_depth(skill_dir))
    all_errors.extend(check_file_references(skill_dir))
    all_errors.extend(check_hedging(skill_dir))

    if not all_errors:
        print("PASS: All structural checks passed")
        sys.exit(0)

    fails = [e for e in all_errors if e.startswith("FAIL")]
    warns = [e for e in all_errors if e.startswith("WARN")]

    for e in all_errors:
        print(e)

    print(f"\nSummary: {len(fails)} failures, {len(warns)} warnings")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
