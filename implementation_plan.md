# Implementation Plan

[Overview]
Reorganize the ohMyZshConfig project to clearly separate storage (configs to deploy) from deployment (scripts that do the deploying), and introduce a shared library for common script utilities.

This reorganization addresses two main concerns: (1) confusion about which files are configs vs scripts vs deployment tools, and (2) script duplication of common patterns like colors, logging, and platform detection. The new structure will make it immediately clear what each file's purpose is and reduce boilerplate across scripts.

The final structure will be:

```
ohMyZshConfig/
├── Makefile                    # Command interface (stays at root)
├── plugins.txt                 # Plugin manifest (stays at root)
├── hooks/                      # Git hooks (stays at root)
├── .clinerules/                # Project rules (stays at root)
├── .cline-project/             # Memory bank (stays at root)
├── src/
│   ├── storage/                # What gets deployed
│   │   ├── zsh/
│   │   │   ├── .zshrc
│   │   │   └── aliases.zsh
│   │   ├── git/
│   │   │   ├── .gitconfig
│   │   │   ├── gitconfig-gsi
│   │   │   └── gitconfig-ms
│   │   ├── cline/
│   │   │   ├── rules/
│   │   │   ├── workflows/
│   │   │   ├── hooks/
│   │   │   └── skills/
│   │   └── scripts/            # User utilities (deployed to ~/.oh-my-zsh/custom/scripts/)
│   │       ├── ssh-key-generator.zsh
│   │       └── company-setup.zsh
│   └── deployment/             # How it gets deployed
│       ├── lib/
│       │   └── common.zsh      # Shared utilities (colors, logging, platform detection)
│       ├── bootstrap/
│       │   ├── macos/
│       │   │   └── bootstrap.sh
│       │   ├── linux/
│       │   │   └── bootstrap.sh
│       │   └── windows/
│       │       ├── windows-bootstrap-1.ps1
│       │       └── windows-bootstrap-2.sh
│       ├── system-setup.zsh
│       ├── plugin-manager.zsh
│       ├── deploy-cline.zsh
│       └── deploy.zsh          # Renamed from update-zsh-config.zsh
```

[Types]
No type system changes required - this is a shell script project.

[Files]
File operations will move existing files to new locations and create one new file.

**New Files:**

- `src/deployment/lib/common.zsh` - Shared library with colors, logging functions, and platform detection

**Files to Move:**
| Current Location | New Location |
|------------------|--------------|
| `.zshrc` | `src/storage/zsh/.zshrc` |
| `aliases.zsh` | `src/storage/zsh/aliases.zsh` |
| `configurations/git/.gitconfig` | `src/storage/git/.gitconfig` |
| `configurations/git/gitconfig-gsi` | `src/storage/git/gitconfig-gsi` |
| `configurations/git/gitconfig-ms` | `src/storage/git/gitconfig-ms` |
| `configurations/cline/` | `src/storage/cline/` |
| `scripts/ssh-key-generator.zsh` | `src/storage/scripts/ssh-key-generator.zsh` |
| `scripts/company-setup.zsh` | `src/storage/scripts/company-setup.zsh` |
| `scripts/system-setup.zsh` | `src/deployment/system-setup.zsh` |
| `scripts/plugin-manager.zsh` | `src/deployment/plugin-manager.zsh` |
| `scripts/deploy-cline.zsh` | `src/deployment/deploy-cline.zsh` |
| `scripts/setup/macos/bootstrap.sh` | `src/deployment/bootstrap/macos/bootstrap.sh` |
| `scripts/setup/linux/bootstrap.sh` | `src/deployment/bootstrap/linux/bootstrap.sh` |
| `scripts/setup/windows/` | `src/deployment/bootstrap/windows/` |
| `update-zsh-config.zsh` | `src/deployment/deploy.zsh` |

**Files to Modify:**

- `Makefile` - Update all script paths to new locations
- `src/deployment/deploy.zsh` - Update paths, source common.zsh
- `src/deployment/deploy-cline.zsh` - Update paths, source common.zsh
- `src/deployment/system-setup.zsh` - Source common.zsh, remove duplicate color/logging code
- `src/deployment/plugin-manager.zsh` - Source common.zsh, remove duplicate color/logging code
- `src/storage/scripts/company-setup.zsh` - Update path to ssh-key-generator.zsh
- `ReadMe.md` - Update documentation to reflect new structure

**Files to Delete:**

- `configurations/` directory (after moving contents)
- `scripts/` directory (after moving contents)

[Functions]
No new functions required outside of the shared library.

**New Functions (in `src/deployment/lib/common.zsh`):**

- `log()` - Print green success message
- `warn()` - Print yellow warning message
- `error()` - Print red error message and exit
- `info()` - Print blue info message
- `detect_os()` - Returns "macos", "linux", "windows", or "unknown"
- `detect_package_manager()` - Returns "brew", "apt", "dnf", "yum", "pacman", "zypper", or "unknown"
- `get_script_dir()` - Returns directory containing the current script
- `get_project_root()` - Returns the project root directory

**Functions to Remove (from individual scripts):**

- Remove duplicate `log`, `warn`, `error`, `info` definitions from:
  - `deploy.zsh`
  - `deploy-cline.zsh`
  - `system-setup.zsh`
  - `plugin-manager.zsh`
- Remove duplicate `print_status`, `print_color` definitions
- Remove duplicate `detect_package_manager` from `system-setup.zsh`

[Classes]
No classes - this is a shell script project.

[Dependencies]
No new dependencies required.

[Testing]
Manual testing required after reorganization.

**Test Commands:**

1. `make lint` - Verify all scripts pass syntax check
2. `make setup` - Test full setup flow (on a fresh VM or container if possible)
3. `make deploy` - Test deployment to existing setup
4. `make deploy-cline` - Test Cline-only deployment
5. `make update` - Test plugin management

**Verification Checklist:**

- [ ] All scripts are executable (`chmod +x`)
- [ ] Colors display correctly (ANSI-C quoting preserved)
- [ ] Paths resolve correctly from any working directory
- [ ] Deployment targets are unchanged (files end up in same places)
- [ ] No regression in existing functionality

[Implementation Order]
Implementation should proceed in phases to minimize risk and allow incremental testing.

1. **Create directory structure** - Create `src/storage/`, `src/deployment/`, and subdirectories
2. **Create shared library** - Write `src/deployment/lib/common.zsh` with all shared utilities
3. **Move storage files** - Move zsh, git, cline configs and user scripts to `src/storage/`
4. **Move deployment scripts** - Move setup scripts to `src/deployment/`, bootstrap to `src/deployment/bootstrap/`
5. **Update deployment scripts** - Refactor each script to source `common.zsh` and use new paths
6. **Update Makefile** - Update all script paths to new locations
7. **Update utility scripts** - Fix any internal references (e.g., company-setup.zsh -> ssh-key-generator.zsh)
8. **Clean up old directories** - Remove empty `scripts/` and `configurations/` directories
9. **Update documentation** - Update ReadMe.md and memory bank files
10. **Test all commands** - Run `make lint`, `make deploy`, verify functionality
