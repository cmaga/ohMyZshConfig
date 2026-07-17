---
name: playwright-mcp-setup
description: Configure a project's Playwright MCP server for the most efficient per-project setup — concurrent browsers across worktrees, persistent auth, and browser options matched to the project. Auto-triggers when Playwright is first invoked in a project with no MCP config for it, or when the test browser is locked by another session (indicates broken setup).
disable-model-invocation: false
---

# Playwright MCP Setup

Configure a project's `playwright` MCP server for the most efficient per-project setup: verification keeps its login, runs concurrently across worktrees and sessions, and uses browser options matched to the project. This is a tailoring flow, not a fixed recipe — read the guide, fit it to the project, prove it works.

## Workflow

1. **Understand the guide.** Read [reference/playwright-mcp-guide.md](reference/playwright-mcp-guide.md) end to end — the complete menu of what's configurable (profile mode, auth seeding, engine/emulation, network, output, concurrency) and the mechanics behind each choice. There is no one-size config; you tailor from this menu. The single non-negotiable is `--isolated` — it is what makes concurrent browsers possible.

2. **Understand how the project runs locally, then pick settings.** From the code — README, `package.json` scripts, `CLAUDE.md`, compose files — establish the dev command, host, per-worktree port scheme, framework, and any responsive/mobile surface. Never assume. Decide which guide options fit (engine, `--viewport-size`/`--device`, `--output-dir`, `--headless`), then write `<repo>/.mcp.json` with `--isolated` plus those options:

   ```json
   {
     "mcpServers": {
       "playwright": {
         "type": "stdio",
         "command": "npx",
         "args": [
           "-y",
           "@playwright/mcp@latest",
           "--isolated",
           "--storage-state=${HOME}/.claude-artifacts/skills/playwright-mcp-setup/<project>.json"
         ]
       }
     }
   }
   ```

   Use `${HOME}` (braced) — `.mcp.json` expands only the `${VAR}` form; the global `~/.claude.json` expands nothing (guide: Config precedence). Shared/team repo: swap the literal path for `${PLAYWRIGHT_MCP_AUTH:-<absolute default>}`. If the global `~/.claude.json` pins a `--user-data-dir`, it single-instances every project without its own `.mcp.json` — flag it and switch it to `--isolated` with the user's ok.

3. **Tailor the login.** Determine the auth provider and whether the app gates its useful surfaces behind login. If it doesn't, drop `--storage-state` — `--isolated` alone gives concurrency. If it does, this is the project-specific crux: export a storage-state seed and keep `--storage-state` wired.

   ```sh
   mkdir -p "$HOME/.claude-artifacts/skills/playwright-mcp-setup"
   npx -y playwright open --save-storage="$HOME/.claude-artifacts/skills/playwright-mcp-setup/<project>.json" <running-app-url>
   ```

   Sign in inside the opened browser, then close it — the file is written on close. `chmod 600` it. Already have a signed-in profile (e.g. from a prior `--user-data-dir`)? Extract the seed from it instead — no login needed, but first confirm that profile is genuinely signed in (guide: Seeding, "from an existing signed-in profile"). The port is irrelevant: cookies are host-keyed, so one seed signs in every worktree's port (guide: Ports and worktrees). Cookie names alone don't prove auth — a signed-out profile carries the same names; the only real proof is the step 5 drive.

4. **Clarify — only if the code left something load-bearing unresolved.** e.g. which login identity to seed, a non-standard port scheme, whether a given surface actually needs auth. Ask nothing the code already answers.

5. **Prove it — concurrency and auth together.** Improvise a quick check, no second worktree needed: a throwaway Playwright snippet that launches two browsers off the seed (`storageState`) and opens a login-gated route in each. Wait with `domcontentloaded` and poll the final URL / a known selector — never `networkidle`, which never settles on auth apps that poll (Clerk, Auth0). Both land on the gated route (not the sign-in page) and neither throws "already in use" → the setup is correct. If both hit sign-in, the seed is signed out — re-seed from a genuinely authenticated profile.

Reconcile docs when this replaces a prior approach.
