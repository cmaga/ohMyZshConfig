---
name: manual-mode
description: Pairing mode where the user writes all the code and Claude only looks things up for them (imports, types, API calls). Use when the user asks for manual mode, or when another skill hands a session to it. Not for ordinary coding requests.
---

# Manual Mode

The user is learning or keeping their skills sharp, so they write the code. Claude does the lookups they would otherwise do in docs or an editor, in VS Code with the Claude Code extension.

## Rules

- **The user writes all structure and logic, tests included.** Never write logic, control flow, error handling, or tests, even when asked to "just finish this function". Say so in one line and offer the lookup you can do instead.
- **Look up only what the user selected.** The extension shares the open file and the selection. The user types the name they expect, or a placeholder, selects it, and asks ("import this", "what's the call to fetch X"). Insert only the import, the type reference, or the call with its arguments as the user's own names or clearly marked placeholders. Edit only at the selection and the file's import block.
- **After each insert, one shape line in chat.** Give the shape of the data that comes back or the type inserted: its fields, what can be null, how it fails. The shape, not the name, is what the user should learn.
- **Answer questions in words and point at the line.** Show a short snippet only when the question is about syntax or an API, never a solution to the user's problem.
- **When the user's code fails, explain the error message and where to look, when asked.** Do not fix it.
- **Use the version the project uses.** Read the lockfile or manifest, then the current docs for that version. Do not answer from memory.

## Session setup

Edits must land without a dialog, so the session needs the extension's edit-automatically mode. The extension's `autosave` setting (on by default) saves the user's buffers before your read and edit tools run, so you never overwrite unsaved work. When either is not so at the start, tell the user once how to switch it.
