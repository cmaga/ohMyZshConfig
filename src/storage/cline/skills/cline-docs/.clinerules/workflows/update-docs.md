# Workflow: Update Cline Documentation

This workflow updates the cline-docs skill knowledge base when the Cline repository changes.

## Quick Start

1. Run sync script: `zsh scripts/sync-cline-repo.zsh`
2. If versions match, no updates needed
3. If different, follow the update procedure below

## Version Check

Current version is stored in `.clinerules/cline-version.json`. Compare against the Cline repo HEAD:

```bash
cd ~/.cline/repos/cline && git rev-parse HEAD
```

If SHAs match, exit - no updates needed.

## Source File Mapping

| Doc File           | Primary Sources                 | Secondary Sources                                                                         |
| ------------------ | ------------------------------- | ----------------------------------------------------------------------------------------- |
| architecture.md    | `.clinerules/cline-overview.md` | `.clinerules/general.md`, `.clinerules/protobuf-development.md`, `.clinerules/storage.md` |
| core-workflows.md  | `docs/core-workflows/*.mdx`     | -                                                                                         |
| customization.md   | `docs/customization/*.mdx`      | -                                                                                         |
| features.md        | `docs/features/*.mdx`           | -                                                                                         |
| mcp.md             | `docs/mcp/*.mdx`                | -                                                                                         |
| providers.md       | `docs/provider-config/*.mdx`    | `.clinerules/general.md` (Adding API Provider section)                                    |
| cli.md             | `docs/cline-cli/*.mdx`          | `.clinerules/cli.md`                                                                      |
| troubleshooting.md | `docs/troubleshooting/*.mdx`    | -                                                                                         |
| tools.md           | `docs/tools-reference/*.mdx`    | -                                                                                         |

## Update Procedure

### Step 1: Identify Changed Files

```bash
cd ~/.cline/repos/cline
STORED_SHA=$(jq -r '.cline_version' /path/to/cline-docs/.clinerules/cline-version.json)
git diff --name-only $STORED_SHA HEAD -- docs/ .clinerules/
```

### Step 2: Map Changes to Docs

For each changed source file, identify the corresponding doc file using the mapping table above.

### Step 3: Update Docs

Apply changes using these conventions:

**Structure:**

1. Mental model first - what the concept IS and its purpose
2. Core patterns - the 80% case, happy path
3. Edge cases - exceptions, gotchas, special handling
4. Cross-references - link related concepts

**Format:**

- Tables over prose for comparisons, options, parameters
- Code blocks for commands, paths, config examples
- Bullet lists for sequential steps, feature lists
- Descriptive H2/H3 headers for navigation

**Keep:**

- Actionable information (how to do X)
- Configuration patterns and examples
- Error conditions and fixes
- Relationships between concepts
- File paths and directory structures

**Remove:**

- Marketing language
- Redundant explanations
- Overly verbose examples
- Screenshots (describe if important)

### Step 4: Update Version

After all docs are updated, update `.clinerules/cline-version.json` with the new SHA:

```zsh
cd ~/.cline/repos/cline
NEW_SHA=$(git rev-parse HEAD)
# Update the JSON file with new SHA
jq --arg sha "$NEW_SHA" '.cline_version = $sha' .clinerules/cline-version.json > tmp.json && mv tmp.json .clinerules/cline-version.json
```

### Step 5: Verify

1. Confirm SKILL.md routing is still correct
2. Test representative questions from each category
3. Check cross-references still work

## Rollback

If updates cause issues, revert to previous version:

```bash
cd ~/.cline/repos/cline
git checkout $PREVIOUS_SHA
```

Then re-run the update procedure.
