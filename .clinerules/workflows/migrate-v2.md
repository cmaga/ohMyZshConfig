# ohMyZshConfig v2 Migration Workflow

Minimum changes required to get `make deploy` working on a machine with pre-v2 naming conventions.

## Background

Version 2 introduced standardized naming conventions:

| Type                | Old Examples               | New Standard                |
| ------------------- | -------------------------- | --------------------------- |
| Company Codes       | work, geisel, kratos       | `gsi`, `ms`                 |
| Dev Directories     | `~/dev/work`               | `~/dev/gsi`                 |
| SSH Host Aliases    | `github.com-work`          | `github.com-gsi`            |
| Git Config Profiles | `gitconfig-work`           | `gitconfig-gsi`             |
| SSH Keys            | `id_ed25519_github-geisel` | `id_ed25519_github.com-gsi` |

---

## Step 1: Audit Current State

Investigate what exists on this machine:

- What directories exist under `~/dev/`?
- What SSH host aliases are configured in `~/.ssh/config`?
- What SSH keys exist in `~/.ssh/keys/`?
- What git profiles exist in `~/.oh-my-zsh/custom/git/`?
- What are the includeIf paths in `~/.gitconfig`?

---

## Step 2: Create Migration Plan

Based on the audit, map old names to new names.

**Example Migration Plan:**

```
Directories:
  ~/dev/work → ~/dev/gsi
  ~/dev/kratos → ~/dev/ms

SSH Host Aliases (in ~/.ssh/config - MUST include both the host name and identity file):
  Host: github.com-work → github.com-gsi
    IdentityFile: ~/.ssh/keys/id_ed25519_github-work → ~/.ssh/keys/id_ed25519_github.com-gsi
  Host: github.com-geisel → github.com-gsi
    IdentityFile: ~/.ssh/keys/id_ed25519_github-geisel → ~/.ssh/keys/id_ed25519_github.com-gsi
  Host: github.com-kratos → github.com-ms
    IdentityFile: ~/.ssh/keys/id_ed25519_github-kratos → ~/.ssh/keys/id_ed25519_github.com-ms
  Host: bitbucket.org-work → bitbucket.org-gsi
    IdentityFile: ~/.ssh/keys/id_ed25519_bitbucket-work → ~/.ssh/keys/id_ed25519_bitbucket.org-gsi

Git Config Profiles (in ~/.oh-my-zsh/custom/git/):
  gitconfig-work → gitconfig-gsi
  gitconfig-kratos → gitconfig-ms
```

Confirm this plan before proceeding.

---

## Step 3: Execute Plan

Execute the renames identified in Step 2.

**CRITICAL WARNING - Directory Renames:**

When renaming directories like `~/dev/work` to `~/dev/gsi`, **rename the directory itself** rather than moving individual files:

```bash
# CORRECT - rename the directory
mv ~/dev/work ~/dev/gsi

# WRONG - moving files risks data loss
mv ~/dev/work/* ~/dev/gsi/
```

This is the only real data loss risk in this migration. Renaming preserves everything including hidden files, git history, etc.

**After manual renames are complete:**

Report success or failure. If all renames completed successfully, the migration is done and the user can run `make deploy` when ready.

**Note:** Git remotes in existing repos may break after SSH host alias renames. This is minor - fix as needed when you encounter it.
