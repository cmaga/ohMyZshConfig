# Lever inventory

Last updated: 2026-07-16

```mermaid
pie title Max saving per lever (pt of total draw)
    "Session model" : 59
    "Session effort" : 27
    "Worker model" : 12.1
    "Fan-out model" : 24
    "Review model" : 7.6
    "Worker effort" : 2.8
    "Review effort" : 1.6
```

| # | Lever | Where | Options | Cost (pt of total draw) | Impact (0-100) |
|---|---|---|---|---|---|
| 1 | Session model | `/model`, `--model`, `ANTHROPIC_MODEL` (live) | fable<br>opus<br>sonnet<br>haiku | fable -0<br>opus -11pt<br>sonnet -35pt<br>haiku -59pt | 100 |
| 2 | Session effort | settings.json, `--effort`, `CLAUDE_CODE_EFFORT_LEVEL` (live) | max<br>xhigh<br>high<br>medium<br>low | max -0<br>xhigh -12pt<br>high -27pt<br>medium -27pt<br>low -27pt | 50 |
| 3 | Review model | `model:` frontmatter in `agents/code-review-agent.md`, `plan-review-agent.md`, `qa-planner-agent.md`, `security-expert-agent.md` | fable<br>opus<br>sonnet<br>haiku | fable -0<br>opus -4.2pt<br>sonnet -5.9pt<br>haiku -7.6pt | 60 |
| 4 | Review effort | `effort:` frontmatter in the same review agent files | max<br>xhigh<br>high<br>medium<br>low | max -0<br>xhigh -0.7pt<br>high -1.6pt<br>medium -1.6pt<br>low -1.6pt | 35 |
| 5 | Worker model | `agents/worker-agent.md` `model:` | fable<br>opus<br>sonnet<br>haiku | fable -0<br>opus -6.7pt<br>sonnet -9.4pt<br>haiku -12.1pt | 25 |
| 6 | Worker effort | `agents/worker-agent.md` `effort:` | max<br>xhigh<br>high<br>medium<br>low | max -0<br>xhigh -1.3pt<br>high -2.8pt<br>medium -2.8pt<br>low -2.8pt | 10 |
| 7 | Fan-out model | `dev-workflow/SKILL.md` `agent()` `model` opt | inherit (session)<br>fable<br>opus<br>sonnet<br>haiku | inherit -<br>fable -0<br>opus -13pt<br>sonnet -19pt<br>haiku -24pt | 10 |

Impact rationale per lever: [lever-impact.md](lever-impact.md)

Excluded — do not re-add: fast mode, advisor model, context ceiling, deep-tier dispatch, per-card model, skill frontmatter overrides.
