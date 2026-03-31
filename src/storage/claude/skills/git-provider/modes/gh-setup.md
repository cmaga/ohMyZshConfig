# GitHub Authentication Setup

Add or manage GitHub CLI authentication.

## Pre-Check

```bash
gh auth status 2>&1
```

**Allowed accounts:** `cmaga`, `cmagana-gsi`, `cmagana-ms`

- If all 3 exist → setup complete
- If any missing → ask which to add (show only missing options)

## Add Account

**Account name must match `git config user.name` for the target directory.**

1. **Log into the correct GitHub account in your browser**
   - Ensure you're signed into the account you want to add
   - Account username should match your git config user.name (e.g., `cmagana-gsi` for `~/dev/gsi/`)

2. **Generate a Personal Access Token:**

   https://github.com/settings/tokens/new

   Required scopes: `repo`, `read:org`, `gist`

3. **Copy the token and run:**

   ```bash
   gh auth login --hostname github.com --with-token
   ```

   Paste the token when prompted.

4. **Set git protocol to SSH:**
   ```bash
   gh config set git_protocol ssh --host github.com
   ```

## Verify

```bash
gh auth status
```

Should show the new account alongside any existing ones.
