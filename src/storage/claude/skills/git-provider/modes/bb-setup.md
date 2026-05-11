---
name: bb-setup
description: Install and authenticate the Bitbucket CLI (gildas/bitbucket-cli) via profiles stored in the system keychain.
---

# Bitbucket Authentication Setup

Add or repair a `bb` profile so the git-provider skill can hit `bb pr …` against a Bitbucket Cloud workspace.

> The `bb` CLI does **not** use `BITBUCKET_USERNAME` / `BITBUCKET_APP_PASSWORD` env vars. Credentials live in profiles at `~/Library/Application Support/bitbucket/config-cli.yml`, with secrets in the macOS/Linux keychain (or Windows Credential Manager).

## Install

```bash
brew install gildas/tap/bitbucket-cli
bb --version
```

## Pre-Check

```bash
bb profile list
bb profile which
```

- If no profiles exist → run the **Add Profile** flow below.
- If a profile exists but `bb pr list` / `bb repo get` errors with `may not have access to this repository … make sure you are authenticated`, the profile's credentials are missing scope or pointed at the wrong workspace → run **Update Profile** below.

## Add Profile

Ask the user which credential type they want to use:

| Option                            | Description                                                                                                       |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Workspace/Repo Access Token       | Recommended. Bitbucket-issued token scoped to a single workspace or repo. No password rotation, finer-grained.    |
| App Password + Username           | Legacy. User-scoped, requires both `--user` and `--password`. Use when access tokens aren't available.            |

### Option A — Access Token

1. **Create an access token** at:
   - Workspace token: `https://bitbucket.org/{workspace}/workspace/settings/access-tokens` *(replace `{workspace}`)*
   - Repository token: `https://bitbucket.org/{workspace}/{repo}/admin/access-tokens`

   Required scopes: `pullrequest`, `pullrequest:write`, `repository`, `repository:write`.

2. **Create the profile:**

   ```bash
   bb profile create \
     --name "{profile-name}" \
     --access-token "{token}" \
     --default-workspace "{workspace}" \
     --default
   ```

   Token is stored in the keychain via the `bitbucket-cli` vault key by default.

### Option B — App Password

1. **Create an app password** at `https://bitbucket.org/account/settings/app-passwords/`.

   Required permissions: Repositories (Read/Write), Pull requests (Read/Write).

2. **Create the profile:**

   ```bash
   bb profile create \
     --name "{profile-name}" \
     --user "{bitbucket-username}" \
     --password "{app-password}" \
     --default-workspace "{workspace}" \
     --default
   ```

## Update Profile

If a profile exists but lacks access to the current repo, the cleanest path is to delete and recreate it:

```bash
bb profile delete {profile-name}
# then re-run Add Profile above
```

## Verify

```bash
# Profile-level: workspace token has access to its workspace
bb workspace get {workspace} -o json | jq -r '.slug'

# Repo-level: from inside the target git repo, bb auto-detects via `git remote`.
# `bb branch list` is the cheapest call that requires repo-scope auth.
bb branch list -o json --page-length 1 | jq -r '.[0].name // "(no branches)"'
```

Notes:
- `bb user get` and `bb repo get` both require an explicit arg; don't use them as auth probes.
- Access tokens are not tied to a user, so `bb` profiles created via `--access-token` have a blank `USER` column in `bb profile list`. That's normal.

If both verify steps succeed, return to the parent skill flow.

## Troubleshooting

| Symptom                                                                | Fix                                                                                              |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `may not have access to this repository`                               | Token/app-password lacks repo scope, or wrong `--default-workspace`. Recreate via Update Profile. |
| `bb user get` works but `bb repo get` fails inside the repo            | Workspace mismatch. The repo's workspace differs from the profile's `--default-workspace`.       |
| `bb profile list` shows USER blank with an `ATCTT…` token              | Access-token profile. Normal — `USER` is only set for app-password profiles.                     |
| `bb` not found after `brew install`                                    | Add Homebrew to PATH or `brew link gildas/tap/bitbucket-cli`.                                    |
| Keychain prompts on every command                                      | Allow `bb` to always access the `bitbucket-cli` keychain item, or recreate with `--no-vault`.    |
