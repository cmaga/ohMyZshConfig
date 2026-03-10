# Cleanup Dangling Files Workflow

Identify and remove orphaned files left behind from previous deployment versions after running `make deploy`.

## Background

When the project structure changes between versions, old files may persist in deployment destinations even though they're no longer in the source. This workflow compares source directories against deployed destinations to find and clean up these dangling files.

---

## Deployment Mappings

| Source Directory               | Destination                                 |
| ------------------------------ | ------------------------------------------- |
| `src/storage/scripts/`         | `~/.oh-my-zsh/custom/scripts/`              |
| `src/storage/git/`             | `~/.gitconfig` + `~/.oh-my-zsh/custom/git/` |
| `src/storage/cline/rules/`     | `~/Documents/Cline/Rules/`                  |
| `src/storage/cline/workflows/` | `~/Documents/Cline/Workflows/`              |
| `src/storage/cline/hooks/`     | `~/Documents/Cline/Hooks/`                  |
| `src/storage/cline/skills/`    | `~/.cline/skills/`                          |

---

## Step 1: Inventory Source Files

List all files that SHOULD exist in each deployment destination:

```zsh
# Scripts (only .zsh and .sh files matter)
ls src/storage/scripts/

# Git configs (excluding .gitconfig which goes to ~/)
ls src/storage/git/ | grep -v '^\.gitconfig$'

# Cline Rules
ls src/storage/cline/rules/

# Cline Workflows
ls src/storage/cline/workflows/

# Cline Hooks
ls src/storage/cline/hooks/

# Cline Skills (directory names only)
ls src/storage/cline/skills/
```

---

## Step 2: Audit Deployed Files

List all files currently in each deployment destination:

```zsh
# Scripts
ls ~/.oh-my-zsh/custom/scripts/

# Git configs
ls ~/.oh-my-zsh/custom/git/

# Cline Rules
ls ~/Documents/Cline/Rules/

# Cline Workflows
ls ~/Documents/Cline/Workflows/

# Cline Hooks
ls ~/Documents/Cline/Hooks/

# Cline Skills
ls ~/.cline/skills/
```

---

## Step 3: Identify Dangling Files

Compare the outputs from Steps 1 and 2. Any file in the destination that doesn't have a corresponding source file is a dangling file.

**Common dangling file patterns:**

- Old scripts that were refactored into deployment scripts
- Workflows/hooks that were removed or consolidated
- Skills that were renamed or removed
- Subdirectories from old organizational structures

---

## Step 4: Generate Cleanup Commands

For each dangling file identified, generate a removal command:

```zsh
# Example cleanup commands (adjust based on findings)

# Remove dangling scripts
rm ~/.oh-my-zsh/custom/scripts/<dangling-file>
rm -rf ~/.oh-my-zsh/custom/scripts/<dangling-directory>/

# Remove dangling workflows
rm ~/Documents/Cline/Workflows/<dangling-file>

# Remove dangling hooks
rm ~/Documents/Cline/Hooks/<dangling-file>

# Remove dangling skills
rm -rf ~/.cline/skills/<dangling-skill>/
```

---

## Step 5: Execute Cleanup

Review the generated commands carefully, then execute them.

**Safety Notes:**

- Always review before deleting
- Files in `~/.oh-my-zsh/custom/` are safe to delete (they're managed by this project)
- Files in `~/Documents/Cline/` are safe to delete (they're managed by this project)
- Files in `~/.cline/skills/` are safe to delete (they're managed by this project)
- When in doubt, move to a backup location instead of deleting

---

## Quick Diff Commands

One-liner commands to quickly identify dangling files:

```zsh
# Scripts - show files in dest not in source
comm -23 <(ls ~/.oh-my-zsh/custom/scripts/ | sort) <(ls src/storage/scripts/ | sort)

# Git configs - show files in dest not in source
comm -23 <(ls ~/.oh-my-zsh/custom/git/ | sort) <(ls src/storage/git/ | grep -v '^\.gitconfig$' | sort)

# Cline Rules
comm -23 <(ls ~/Documents/Cline/Rules/ | sort) <(ls src/storage/cline/rules/ | sort)

# Cline Workflows
comm -23 <(ls ~/Documents/Cline/Workflows/ | sort) <(ls src/storage/cline/workflows/ | sort)

# Cline Hooks
comm -23 <(ls ~/Documents/Cline/Hooks/ 2>/dev/null | sort) <(ls src/storage/cline/hooks/ 2>/dev/null | sort)

# Cline Skills
comm -23 <(ls ~/.cline/skills/ | sort) <(ls src/storage/cline/skills/ | sort)
```

---

## When to Run This Workflow

- After a major refactor that reorganizes the source structure
- After removing files from source that were previously deployed
- When `make deploy` succeeds but you suspect old files remain
- As part of periodic maintenance
