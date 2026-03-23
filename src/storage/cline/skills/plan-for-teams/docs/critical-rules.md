# Plan for Teams — Critical Rules

1. **The plan is self-contained.** The Claude Code lead has NO context from the
   Cline conversation. If it's not in the plan, it doesn't exist.

2. **File ownership must be explicit.** No two agents should touch the same file.
   If a file must be touched by multiple agents, it belongs to the earlier wave.

3. **Contracts are mandatory for multi-wave plans.** Without them, parallel agents
   build against assumptions and integration fails.

4. **Spawn prompts include everything.** Each agent section in the plan must have
   enough detail that the lead can construct a complete spawn prompt from it alone.

5. **Sonnet for implementers, Opus for lead.** The lead runs on Opus (coordination
   needs strong reasoning). Teammates run on Sonnet (focused execution is cheaper).
   The reviewer agent should run on Opus.

6. **Always include CLAUDE.md reference.** Remind the lead that teammates auto-load
   CLAUDE.md, so project conventions don't need to be repeated in spawn prompts.
