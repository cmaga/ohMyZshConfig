# Playwright MCP: how it works and how to configure it

Reference for the `playwright-mcp-setup` skill — the complete menu of what's configurable, plus the mechanics behind each choice. Read it before tailoring a project's config; `SKILL.md` is the procedure that applies it.

## The two profile modes

`@playwright/mcp` runs the browser in one of two modes. This single choice is the root of every persistence-vs-concurrency question.

- **Persistent (default)** — an on-disk Chromium profile. The login survives across sessions, but only ONE browser can use it at a time (`SingletonLock`).
- **Isolated (`--isolated`)** — an in-memory profile, discarded on close. Unlimited concurrent browsers; seed a login by injecting `--storage-state=<file>` (saved cookies + localStorage) at boot.

A shared on-disk profile and concurrency are mutually exclusive by Chromium design, not an MCP limitation.

### Why the default persistent profile fragments across worktrees

The default profile location is hashed by the MCP client's workspace root: `mcp-{channel}-{workspace-hash}` (under `~/Library/Caches/ms-playwright/` on macOS). A dev workflow that creates a new git worktree per ticket launches the MCP from a different root each time, so every worktree gets a fresh, unauthenticated profile. The symptom — "Playwright makes me sign in every session" — is workspace fragmentation, not a session-lifetime bug.

### Why pinning `--user-data-dir` trades one problem for a worse one

A fixed `--user-data-dir=<absolute path>` makes every worktree share one profile, so the login persists. But that one on-disk profile is now `SingletonLock`-ed: the second session or worktree that launches hits **"Browser is already in use, use --isolated"**. This is the misconfiguration that blocks driving multiple browsers — you buy persistence at the cost of all concurrency.

## The baseline: isolated + storage-state

Every project starts from `--isolated` (concurrency) seeded by `--storage-state=<file>` (a saved cookies + localStorage snapshot). Every worktree boots already signed in from one shared auth file, and any number run at once. Everything else in this guide is tailoring on top of that baseline.

Dev logins are long-lived (e.g. Clerk dev sessions last ~1 year), so re-exporting the seed is a rare chore, not ongoing upkeep. Confirm the real lifetime from the app's persistence-cookie expiry if it matters.

## Config precedence and env expansion

Two places configure the `playwright` MCP server; per-project wins.

- **`~/.claude.json` → top-level `mcpServers.playwright`** — the global default for every project. No env expansion: `~` and `${HOME}` stay literal, so spell out absolute paths (this is why a global override reads `/Users/you/...`, not `${HOME}/...`).
- **`<repo>/.mcp.json` → `mcpServers.playwright`** — this project only; overrides the global. Expands `${VAR}` and `${VAR:-default}`, so `--storage-state=${HOME}/...` or `${PLAYWRIGHT_MCP_AUTH:-<abs>}` work.

Keep the global default `--isolated` with no profile dir, so un-configured projects stay concurrent; a project that needs a login adds its own `.mcp.json`.

## Every configurable option

`npx -y @playwright/mcp@latest --help` is the authoritative list; `--config <file>` mirrors these as JSON. For the concurrency + auth baseline you need only `--isolated` and `--storage-state` — the rest is situational.

**Profile & auth**

- `--isolated` — in-memory profile; the flag that enables concurrency.
- `--storage-state <path>` — load cookies + localStorage into an isolated session at boot.
- `--user-data-dir <path>` — persistent on-disk profile (single-instance; avoid for concurrent setups). Defaults to a temp dir when unset.
- `--save-session` — write the MCP session into the output dir for later inspection.
- `--shared-browser-context` — reuse one browser context across all connected HTTP clients (SSE transport).

**Browser engine & emulation**

- `--browser <chrome|firefox|webkit|msedge>` — engine or Chrome channel.
- `--executable-path <path>` — a specific browser binary.
- `--device "<name>"` — emulate a named device, e.g. `"iPhone 15"`.
- `--mobile` — generic mobile device (Pixel 10 Chromium / iPhone 17 WebKit); lighter pages, fewer tokens. Not combinable with `--device`.
- `--viewport-size <WxH>` — fixed viewport, e.g. `1280x720`.
- `--user-agent <string>` — override the UA string.
- `--test-id-attribute <attr>` — attribute for test-id locators (default `data-testid`).

**Network & security**

- `--allowed-origins <o;o>` / `--blocked-origins <o;o>` — semicolon-separated request allow/blocklist (blocklist evaluated first; not a security boundary).
- `--block-service-workers` — block service workers.
- `--ignore-https-errors` — proceed past TLS errors (self-signed dev certs).
- `--proxy-server <url>` / `--proxy-bypass <domains>` — route or exempt traffic through a proxy.
- `--grant-permissions <p...>` — pre-grant browser permissions, e.g. `geolocation`, `clipboard-read`.
- `--allow-unrestricted-file-access` — lift the workspace-root file sandbox and allow `file://` navigation.
- `--sandbox` / `--no-sandbox` — force the Chromium sandbox on/off.
- `--allowed-hosts <h...>` — hosts the MCP server itself may serve from (SSE transport).

**Attach to an existing browser** (instead of launching one)

- `--cdp-endpoint <url>` + `--cdp-header <h...>` + `--cdp-timeout <ms>` — attach over the Chrome DevTools Protocol.
- `--endpoint <url>` — attach to a bound browser endpoint.
- `--extension` — drive a running Chrome/Edge via the Playwright browser extension.

**Response content & capabilities**

- `--caps <vision,pdf,devtools>` — enable extra tool groups.
- `--image-responses <allow|omit>` — include or drop screenshots in responses (omit saves tokens).
- `--snapshot-mode <full|none>` — accessibility-snapshot detail per response.
- `--console-level <error|warning|info|debug>` — minimum console severity returned.
- `--secrets <path>` — dotenv file of secrets to redact from responses.
- `--init-page <ts...>` / `--init-script <js...>` — run TypeScript on the page object / inject a script before every page load.
- `--codegen <typescript|none>` — language for generated code.

**Server & transport** (only when running over HTTP/SSE, not the default stdio)

- `--port <n>` / `--host <h>` — bind an SSE server.

**Output & diagnostics**

- `--output-dir <path>` — where screenshots, console, network, and session dumps land (default `<repo>/.playwright-mcp/`).
- `--output-mode <file|stdout>` — write artifacts to files or inline them (default stdout).
- `--output-max-size <bytes>` — evict old output past this size.

**Timeouts**

- `--timeout-action <ms>` (default 5000) / `--timeout-navigation <ms>` (default 60000).

**Config file**

- `--config <path>` — a JSON file mirroring the flags as nested objects: `browser: { browserName, isolated, userDataDir, launchOptions, contextOptions, initScript }`, `server: { port, host, allowedHosts }`, plus `outputDir`, `saveSession`, `capabilities`, `secrets`, `timeouts`, `imageResponses`, `sharedBrowserContext`. Use it when the arg list grows unwieldy; CLI args override the file.

## Seeding the storage-state file

Produce a Playwright `storageState` JSON (cookies + localStorage) — any tool that emits one works.

**Interactive (fresh login).** Sign in once in a throwaway browser:

```sh
mkdir -p "$HOME/.claude-artifacts/skills/playwright-mcp-setup"
npx -y playwright open --save-storage="$HOME/.claude-artifacts/skills/playwright-mcp-setup/<project>.json" <running-app-url>
```

Sign in inside the opened browser, then close it — the file is written on close.

**From an existing signed-in profile (no login).** If a persistent profile is already signed in — e.g. a prior `--user-data-dir` setup — extract its state instead of logging in again.

First confirm the profile is actually signed in — an expired profile looks identical on disk but yields a seed that silently lands every verify run on the sign-in page. Check the provider's signed-in signal, not mere cookie presence: for Clerk, `__client_uat` must be a non-zero timestamp (`0` = signed out); a live `__session` is short-lived and usually absent on disk, so don't look for it.

Then copy the profile (to sidestep its `SingletonLock`) and dump `storageState`. This captures the durable on-disk cookies — including the httpOnly refresh/client cookies page JS can't read — which is what a signed-in seed needs: providers that mint a short-lived session token client-side (Clerk, Auth0) re-mint it on first load from those durable cookies. If the app writes its durable cookie only after a page load, `goto(<gated route>)` and let it settle before dumping.

```sh
export OUT="$HOME/.claude-artifacts/skills/playwright-mcp-setup/<project>.json"
export TMP=$(mktemp -d); mkdir -p "$(dirname "$OUT")"
cp -R "<user-data-dir>/." "$TMP/" && rm -f "$TMP"/Singleton*
node -e 'const{chromium}=require("playwright");(async()=>{const c=await chromium.launchPersistentContext(process.env.TMP,{channel:"chrome",headless:true});await c.storageState({path:process.env.OUT});await c.close();})();'
rm -rf "$TMP"
```

Launch with the same browser/`channel` that created the profile — `channel: "chrome"` for the MCP default (your installed Google Chrome). A mismatched engine can't decrypt the profile's OS-keychain-encrypted cookies. Run it where `playwright` is importable (the project, or a dir with `npm i playwright`).

**OAuth-only identity (no interactive login possible).** If the seed identity signs in only through an OAuth provider — no password set — neither path above works: the provider (Google, notably) refuses OAuth inside an automation-controlled browser with "This browser or app may not be secure," and an `--isolated` setup has no persistent profile to extract from. Confirm the dead end before working around it — query the provider for the identity's auth factors (Clerk: `GET /v1/users`, check `password_enabled` and whether the email verified `from_oauth_google`). Then mint a session out-of-band: most providers expose a backend sign-in-token / ticket API that a browser redeems into a full session with no credentials.

```sh
# Clerk: mint a token from the Backend API, redeem it as a ticket in the browser.
# POST https://api.clerk.com/v1/sign_in_tokens  {user_id, expires_in_seconds}  (Bearer <secret key>)
# then navigate to  <sign-in-route>?__clerk_ticket=<token>  — the stock <SignIn /> redeems it.
```

Drive it in a throwaway Playwright browser, poll the provider's signed-in signal (Clerk: `__client_uat` non-zero) rather than `networkidle`, then `context.storageState({path})`. No repo code, no route, no stored credentials — the token is a one-off backend call minted and spent in seconds. This is not the same as shipping a dev-only sign-in route into the app; nothing is added to the codebase.

Either way: `chmod 600` the file. The `<project>.json` then feeds every worktree's `--storage-state`.

### An authenticated seed is necessary, not sufficient

A valid session only clears the login wall. If the app has a **post-auth gate** — a terms/policy acceptance interstitial, an onboarding step, an email-verification wall — a freshly seeded identity still gets redirected there, because that gate is server-side row state (a DB column), invisible in the cookie seed and unaffected by re-seeding. Clear it once per identity through the app (accept the terms, finish onboarding) or by writing the row directly; then the seed sails through. Diagnose by *where* the drive lands: the sign-in route means the seed is stale; any other interstitial means auth succeeded and an app gate stopped you — re-seeding is the wrong fix.

## Ports and worktrees

The `.mcp.json` holds no app URL — the MCP only launches a browser; Claude navigates it at drive time. So every worktree, whatever port its dev server binds, shares the one config and the one seed. The running port is a runtime detail: read it from the dev server's startup output or the worktree's env when you drive, never pin it.

The storage-state seed is port-independent for cookie-based auth: cookies are keyed by host, so a seed captured on `localhost:3000` authenticates `localhost:3147` just the same. Only session state kept in `localStorage` is origin-scoped (scheme + host + port) and would need a per-port seed.

## Playwright MCP vs Claude's built-in Chrome

Two browser tools are available; use the right one.

- **Playwright MCP** — verifying the feature you are building: driving the local dev app, asserting a route renders, walking a form flow, reading console/network on your change. Isolated + concurrent, so many worktrees verify in parallel. This is the dev-workflow verify browser.
- **Claude's built-in Chrome (`claude-in-chrome`)** — every other browsing task: looking something up, reading a dashboard or ticket, checking external docs. It rides your real Chrome session, so your logins are already there and it does not consume a Playwright instance.

Rule of thumb: exercising the code under test → Playwright MCP; anything else → built-in Chrome.

## Troubleshooting

- **"Browser is already in use, use --isolated"** — a persistent profile is locked by another instance. Switch that server to `--isolated`; seed the login with `--storage-state`.
- **A verify run lands on the login page** — storage-state missing/expired, or isolated with no seed. Re-export the seed (SKILL.md step 3).
- **A verify run lands on a terms/onboarding page (not login)** — auth succeeded; a post-auth gate is blocking. That gate is server-side row state, not seed state — re-seeding won't touch it. Clear it once per identity (guide: "An authenticated seed is necessary, not sufficient").
- **"This browser or app may not be secure" on the OAuth provider** — Google and others block OAuth in automation-controlled browsers, so an interactive login can't complete. Seed via a backend sign-in token instead (guide: "OAuth-only identity").
- **`${HOME}` appears literally in the browser path** — it's set in `~/.claude.json`, which doesn't expand env vars. Use an absolute path there, or move the override to `.mcp.json`.
- **Login persists but only one browser works** — a fixed `--user-data-dir`. Remove it; use `--isolated` + `--storage-state`.
