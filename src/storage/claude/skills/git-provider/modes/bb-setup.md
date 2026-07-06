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

> **Naming convention:** name the profile after its workspace slug (workspace `gsi` → profile `gsi`). The parent skill's Bitbucket pre-flight auto-selects a profile by running `bb profile use <workspace>`, so the names must match for multi-workspace setups to route correctly.

Pick a credential type by what admin rights the user has:

| Option                       | When to use                                                                                                          |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Atlassian API token (scoped) | **Default.** User-scoped, needs no workspace/repo admin. This is the replacement for app passwords.                  |
| Workspace/Repo Access Token  | When the user is an admin of the workspace (or the specific repo). Not tied to a user; finer-grained.               |

> **App passwords are deprecated** — no new ones can be created (since 2025-09-09) and existing ones stop working 2026-06-09. Do not use them.

Both examples omit `--default`: the parent skill's pre-flight runs `bb profile use <workspace>` on every call, so the active profile is chosen per-repo. Setting `--default` here would only fight that.

### Option A — Atlassian API token with scopes (recommended, no admin needed)

1. **Create the token** at `https://id.atlassian.com/manage-profile/security/api-tokens`:
   - Click **"Create API token with scopes"** — **not** the plain "Create API token" button (that makes a Jira/Confluence token that 401s on Bitbucket).
   - Name + expiry → **Next**.
   - Select **Bitbucket** as the app → **Next**.
   - Scopes: `read:repository:bitbucket`, `write:repository:bitbucket`, `read:pullrequest:bitbucket`, `write:pullrequest:bitbucket` → **Next** → **Create**.
   - Copy the token (`ATATT…`, shown once).

2. **Create the profile.** The API basic-auth username is the **Atlassian account email**, not the Bitbucket username:

   ```bash
   bb profile create \
     --name "{workspace}" \
     --user "{atlassian-email}" \
     --password "{api-token}" \
     --default-workspace "{workspace}"
   ```

   Validate before trusting it (email + token via basic auth):

   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" -u "{atlassian-email}:{api-token}" \
     "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo}"   # 200 = good
   ```

   > API tokens expire. When one lapses `bb` returns 401 — regenerate via the same "with scopes" flow and `bb profile update {workspace} --password "{new-token}"`.

### Option B — Workspace/Repo Access Token (requires admin)

1. **Create an access token** at:
   - Workspace token *(needs workspace admin)*: `https://bitbucket.org/{workspace}/workspace/settings/access-tokens`
   - Repository token *(needs repo admin)*: `https://bitbucket.org/{workspace}/{repo}/admin/access-tokens`

   Required scopes: `pullrequest`, `pullrequest:write`, `repository`, `repository:write`.

2. **Create the profile:**

   ```bash
   bb profile create \
     --name "{workspace}" \
     --access-token "{token}" \
     --default-workspace "{workspace}"
   ```

   Token (`ATCTT…`) is stored in the keychain via the `bitbucket-cli` vault key by default.

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
- Access tokens (`ATCTT…`, Option B) are not tied to a user, so those profiles have a blank `USER` column in `bb profile list`. API-token and app-password profiles (Option A) show the email/username in `USER`. Both are normal.

If both verify steps succeed, return to the parent skill flow.

## Troubleshooting

| Symptom                                                                | Fix                                                                                              |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `may not have access to this repository`                               | Token lacks repo scope, or wrong `--default-workspace`. Recreate via Update Profile.             |
| `401` with an `ATATT…` token that works against Jira                   | The token has no Bitbucket scopes — it's a plain/Jira token. Recreate via **"Create API token with scopes"** → select **Bitbucket** (Option A). |
| `401` on a profile that used to work                                   | The API token expired. Regenerate and `bb profile update {workspace} --password "{new-token}"`. |
| App-password page warns it's being removed                             | Expected — app passwords are deprecated (gone 2026-06-09). Use Option A (API token with scopes). |
| `bb user get` works but `bb repo get` fails inside the repo            | Workspace mismatch. The repo's workspace differs from the profile's `--default-workspace`.       |
| `git push/pull`: `Could not resolve hostname bitbucket.org-{alias}`    | Git transport, not `bb`. The remote uses an SSH host alias missing from `~/.ssh/config`. Point the remote at a defined alias: `git remote set-url origin git@{defined-alias}:{workspace}/{repo}.git`, or add the `Host` block. |
| `bb` not found after `brew install`                                    | Add Homebrew to PATH or `brew link gildas/tap/bitbucket-cli`.                                    |
| Keychain prompts on every command                                      | Allow `bb` to always access the `bitbucket-cli` keychain item, or recreate with `--no-vault`.    |
