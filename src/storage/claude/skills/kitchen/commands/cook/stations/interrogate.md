# Interrogate

Adversaries try to break a change or a design, and only findings proven by a run survive. Use for "interrogate", "adversarial review", "multi-model review", "challenge this", "stress test this code", "find blind spots", or "tear this apart".

Report the findings. Do not apply fixes.

## Frame

The scope is what the caller names. Otherwise it is the branch diff from its merge base with the base branch, through the working tree. The base branch is what `kitchen.zsh order base <KEY>` prints, with `-` for the key outside an order. Restate the intent in your own words, from the user's message, the order's intent and done-when, the commits, and the PR description. When the intent is still unclear, it is a call only the user can make ([SKILL.md](../../../SKILL.md#autonomy)).

## Fan out

The adversaries default to two, one on the adversary role and one on the other family role ([SKILL.md](../../../SKILL.md#subagents)); a seat that cannot start runs on its role's fallback, and you say so. A scope that changes only tests or prose gets the adversary role alone. Spawn them in one message, each as its role's agent with `isolation: "worktree"`, copy the scope's uncommitted changes into each worktree, and give each the scope, the intent, and this brief:

> Break this change. Prove each finding with a run against the real code, such as a failing test, a repro script, or command output that shows the wrong behavior. For a design or plan, run a prototype or probe the current tree. Keep repros in your own worktree. Report each finding with a title, the exact command, the output it printed, and the output the intent requires. Leave out anything you did not run. That covers style, naming, structure, and risks that need a future change to matter. Note the time when you start; 30 minutes later, stop and report what you have proven. No findings is a valid result.

An adversary that returns nothing is a dropout: go on with the rest and say so.

## Verify

Rerun each finding's command yourself. Keep a finding when the output shows the failure and the failure breaks the intent. Drop the rest. Merge findings that share a root cause. Adversaries find different failures, so the verdict keeps every verified finding, not one adversary's list.

## Output

- **Intent**: the restatement.
- **Findings**: for each verified finding, the command, its output, how it breaks the intent, and the adversaries that found it. Say "no verified findings" when none survive.
- **Dropped**: for each adversary, the count of dropped findings and why.
