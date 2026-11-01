# How

Answer "how does X work": code walkthroughs before changing something, and placement, ownership, and layering questions ("where should this live", "which package owns this", "is this the right layer"). For motivation, use the [why](why.md) station.

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

Every spawn is an `Explore` agent whose brief says "do not edit files". Explorers take the explore role's model and every explainer the judgment role's ([SKILL.md](../../../SKILL.md#subagents)).

## 1. Assess complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. Spawn one explainer that explores and explains in one pass, built from [the explainer prompt](how/explainer-prompt.md) without the explorer-findings section. Go to step 4.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): go to step 2.

When in doubt, take the simple path.

## 2. Explore (complex only)

Decompose the question into 2 to 4 angles, each a distinct slice of the subsystem. Spawn all explorers in a single message, each with [the explorer prompt](how/explorer-prompt.md) and its angle filled in.

## 3. Synthesize (complex only)

Once all explorers have returned, spawn one explainer with [the explainer prompt](how/explainer-prompt.md) and every explorer's findings filled in.

## 4. Present

Present the explainer's output. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

## Output format

The explanation uses the sections defined in [the explainer prompt](how/explainer-prompt.md), dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
