# Prototype

A throwaway sketch to make a design or behavioral decision cheaply, or to settle an empirical fork by observing it instead of asking the user ("prototype", "mock it up", "try this layout", "sketch it to decide").

**You own the design decision, not the code. The prototype is a throwaway instrument. The real build follows the [feature](feature.md) recipe.**

The one recipe where the [laziness protocol](../../../dependencies/principles/laziness-protocol.md)'s "smallest change" and the verification bar invert. Speed over polish, code quality does not matter, no planning. The rigor is in picking the right design cheaply. Propose variations the user didn't ask for, throw an approach away and try another.

1. Scope the decision the prototype exists to make: which layout, which interaction, which density, or for an empirical fork which behavior, timing, or approach. No decision means no prototype. Route to the feature recipe.
2. Gather references when the design space is open. Search for prior art, summarize a moodboard of themes, palettes, and layouts, and with the user here let them pick directions before building. Skip when the direction is set.
3. Build throwaway in its own directory under the session's scratchpad directory, separate from production source. For a visual decision, vanilla HTML/CSS/JS or the lightest stack that renders the idea, CDN deps, a dev server with hot reload. For a behavioral or timing decision, the smallest script that exercises the question. No production framework, no tests, no abstractions.
4. When comparing alternatives, build them behind one switcher (buttons or a keypress), each variant labeled. This is the [exhaust the design space](../../../dependencies/principles/exhaust-the-design-space.md) principle made cheap.
5. Verify on the matching surface. For a visual decision, screenshot each variant through Playwright MCP and drive the interaction. For a behavioral or timing decision, observe the thing you are deciding by logging the timing, printing the output, or watching the render. The observation is the test here, not an assertion.
6. Present alternatives, tradeoffs, and a recommendation. The output is the decision plus the throwaway artifact, not shippable code. Hand the chosen direction to the feature recipe (or the [architect](../stations/architect.md) station for the shape) for the real build. With an order, settle the pick per [SKILL.md](../../../SKILL.md#autonomy) when it is a product or preference call, post the reply as a comment on the ticket through the `ticket-provider` skill with the screenshots attached, and run `kitchen.zsh order close <KEY>`.

**Reply:** the variants explored, the evidence (screenshots for a visual decision, the observed output or timing for a behavioral one), tradeoffs, your recommendation, and the scratch path. Say plainly that the prototype is throwaway.
