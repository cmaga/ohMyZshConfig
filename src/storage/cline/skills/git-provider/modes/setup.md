# Git Provider Setup

Interactive setup for CLI installation and authentication.

## Installation

### GitHub CLI

```bash
# macOS
brew install gh

# Windows
winget install --id GitHub.cli

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh
```

### Bitbucket CLI

```bash
# macOS
brew install gildas/tap/bitbucket-cli
```

**Bitbucket Environment Variables:**

```bash
export BITBUCKET_USERNAME="your-username"
export BITBUCKET_APP_PASSWORD="your-app-password"
```

Create App Password at: https://bitbucket.org/account/settings/app-passwords/

- Required permissions: Repositories (Read/Write), Pull requests (Read/Write)

---

# GitHub Authentication

Interactive flow for `gh auth login`. Use when auth fails or when adding a new account.

## Pre-Check

```bash
gh auth status 2>&1
```

If this shows authenticated accounts, the user may want to add another account rather than set up fresh.

## Interactive Flow

Ask the user these questions using `AskUserQuestion`:

### 1. GitHub Host

**Question:** "Which GitHub instance are you authenticating with?"

| Option                 | Description                                                            |
| ---------------------- | ---------------------------------------------------------------------- |
| `github.com` (default) | Standard GitHub - personal repos, open source                          |
| Enterprise URL         | Your company's GitHub Enterprise Server (e.g., `github.mycompany.com`) |

**Field Explanation:** The hostname determines which GitHub server receives your authentication. Most users use `github.com`. Enterprise users have a separate GitHub instance hosted by their organization with its own URL.

### 2. Git Protocol

**Question:** "Which protocol should git use for operations (clone, push, pull)?"

| Option            | Description                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| SSH (recommended) | Uses SSH keys for authentication. More secure, no password prompts after setup. Requires SSH key. |
| HTTPS             | Uses token-based auth. Simpler setup, works through firewalls that block SSH.                     |

**Field Explanation:**

- **SSH**: Creates a secure tunnel using cryptographic keys. Your private key stays on your machine, public key is uploaded to GitHub. Once set up, you never enter passwords.
- **HTTPS**: Uses your OAuth token for each git operation. May require credential helper to avoid repeated prompts. Better for restrictive corporate networks.

### 3. SSH Key Generation (if SSH selected)

**Question:** "Generate and upload a new SSH key to GitHub?"

| Option    | Description                                                                  |
| --------- | ---------------------------------------------------------------------------- |
| Yes       | Creates a new ed25519 key pair and uploads public key to your GitHub account |
| No (skip) | Use existing SSH key already configured on this machine                      |

**Field Explanation:** SSH keys come in pairs - a private key (secret, stays on your machine) and a public key (shared with GitHub). If you already have `~/.ssh/id_ed25519` or `~/.ssh/id_rsa` configured with GitHub, skip this step.

### 4. Account Label (for directory mapping)

**Question:** "What GitHub username is this account?"

Examples: `cmaga`, `cmagana-gsi`, `cmagana-kratos`

**Field Explanation:** This is the GitHub username that will appear in `gh auth status`. Used to match against the directory mapping table in `SKILL.md`.

## Execution

Based on collected answers, construct and run:

```bash
# Example with all options
gh auth login \
  --hostname github.com \
  --git-protocol ssh \
  --web

# Example skipping SSH key generation
gh auth login \
  --hostname github.com \
  --git-protocol https \
  --skip-ssh-key \
  --web
```

The `--web` flag opens a browser for OAuth. The user completes auth in the browser, then returns to the terminal.

## Post-Setup

After successful auth:

1. Verify with `gh auth status`
2. If this account should be used for specific directories, update the mapping table in `SKILL.md`

## Adding Additional Accounts

To add another account to the same host:

```bash
gh auth login --hostname github.com
```

The CLI will detect an existing account and add the new one alongside it. Use `gh auth switch` to change active account.

## Troubleshooting

| Issue                                 | Solution                                                                                  |
| ------------------------------------- | ----------------------------------------------------------------------------------------- |
| "authentication required" after login | Token may lack required scopes. Re-run `gh auth login` with `--scopes repo,read:org,gist` |
| SSH key permission denied             | Check `~/.ssh/config` has correct key, or re-run setup with SSH key generation            |
| Can't reach enterprise host           | Verify VPN connection, check hostname spelling                                            |
| Token stored in plain text warning    | System keyring unavailable. Consider `--insecure-storage` flag or fix keyring             |
