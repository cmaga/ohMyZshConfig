# Creating .clineignore

The `.clineignore` file controls which files Cline can access. It works like `.gitignore` and lives in the project root.

## When to Use

- Reduce starting context token count (can drop from 200k+ to under 50k)
- Exclude large files Cline doesn't need (CSVs, databases, binary assets)
- Hide build artifacts and generated code
- Exclude dependency directories

## Location

Always at the project root: `.clineignore`

## Pattern Syntax

| Pattern            | Matches                            |
| ------------------ | ---------------------------------- |
| `node_modules/`    | node_modules directory at root     |
| `**/node_modules/` | node_modules at any depth          |
| `*.csv`            | All CSV files                      |
| `/build/`          | build directory at root only       |
| `!important.csv`   | Exception: do not ignore this file |

## Common Starter Template

```text
# Dependencies
node_modules/
**/node_modules/

# Build outputs
/build/
/dist/
/.next/
/out/

# Large data files
*.csv
*.xlsx
*.sqlite
*.db

# Generated code
*.min.js
*.map

# Binary assets
*.png
*.jpg
*.gif
*.ico
*.woff
*.woff2

# IDE / OS files
.DS_Store
*.swp
```

## Behavior

- Excluded files do not appear in file listings
- Excluded from automatic context gathering
- Users can still access excluded files explicitly via `@/path/to/file`
- Changes take effect immediately

## Customization by Project Type

### Node.js / Frontend

```text
node_modules/
/dist/
/build/
/.next/
*.min.js
*.map
package-lock.json
```

### Python

```text
__pycache__/
*.pyc
.venv/
/dist/
*.egg-info/
.mypy_cache/
```

### Java / JVM

```text
/target/
/build/
*.class
*.jar
.gradle/
```

### Monorepo

```text
**/node_modules/
**/dist/
**/build/
**/coverage/
```

## Verification

After creating `.clineignore`, verify:

1. File is at the project root
2. Start a new Cline task and check the token count in the task header
3. Confirm excluded files don't appear in file listings
4. Confirm critical files are NOT excluded (use `!` exceptions if needed)
