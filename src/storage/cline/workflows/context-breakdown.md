# Context Breakdown

Analyze and estimate the token composition of the current Cline session. Identify what consumes your context window and how to reduce it.

## Step 1: Record baseline metrics

Read the token counts from the most recent API response metrics visible in the chat UI:

- `cached` token count (reused context from prior turn)
- `prompt` token count (new tokens this turn)
- Total = cached + prompt

State these numbers clearly. They are the ground truth for percentage calculations.

## Step 2: Identify prompt sections

Scan your full system prompt and list every major section you can see. Use this checklist:

| Category                 | What to look for                                                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| **System prompt core**   | Tool definitions (execute_command, read_file, etc.), tool use guidelines, editing rules, capabilities, mode instructions, objectives |
| **MCP server schemas**   | Each server listed under "Connected MCP Servers" with its tool input schemas                                                         |
| **Global rules**         | Content from `~/Documents/Cline/Rules/` (.clinerules)                                                                                |
| **Project rules**        | Content from project-level `.clinerules/` directory                                                                                  |
| **Skills metadata**      | The SKILLS section listing available skill names and descriptions                                                                    |
| **Environment details**  | File tree, workspace config, detected CLI tools, active terminals, current mode                                                      |
| **Conversation history** | All prior user and assistant messages in this session                                                                                |

## Step 3: Estimate tokens per category

For each category identified in Step 2:

1. Estimate the character count of that section
2. Convert using: ~4 chars/token for English prose, ~3 chars/token for JSON/structured content
3. Calculate percentage of total prompt tokens

Present results in this format:

```
| Category              | Est. Tokens | % of Total | Notes                          |
|-----------------------|-------------|------------|--------------------------------|
| System prompt core    | ~X,XXX      | XX%        |                                |
| MCP servers           | ~X,XXX      | XX%        | N servers, M total tools       |
| Global rules          | ~X,XXX      | XX%        |                                |
| Project rules         | ~X,XXX      | XX%        |                                |
| Skills metadata       | ~X,XXX      | XX%        |                                |
| Environment details   | ~X,XXX      | XX%        | file tree depth matters        |
| Conversation history  | ~X,XXX      | XX%        | grows each turn                |
| **Total estimated**   | ~X,XXX      | 100%       |                                |
| **Actual (from API)** | X,XXX       | --         | cached + prompt from metrics   |
```

Flag any large discrepancy between estimated total and actual total.

## Step 4: Recommend optimizations

Based on the breakdown, suggest concrete actions ordered by impact:

- **MCP servers**: List any connected servers not relevant to the current task. Each unused server's schema wastes tokens every turn.
- **File tree**: If environment details are large, suggest adding entries to `.clineignore` to exclude irrelevant directories (node_modules, dist, .git, etc.).
- **Conversation history**: If history exceeds 50% of context, suggest starting a new task with a focused summary.
- **Rules**: Flag any rules that duplicate default Cline behavior or overlap with each other.
- **Skills**: Note that skill metadata is lightweight (~100 tokens each) and rarely worth optimizing.

## Step 5: Present summary

End with a one-paragraph summary: what is the biggest context consumer, what single action would free the most tokens, and what the estimated savings would be.

**Transparency note:** State clearly that all token counts are estimates based on character-length heuristics. The API metrics are the source of truth for total usage.
