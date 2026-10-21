---
name: deepseek-flash-agent
description: A plain agent on DeepSeek-V4.1-Flash; every rule it follows is in its prompt. The milestone build dispatches it by agent type, because a per-call model opt cannot name a DeepSeek model. Runs only in a session launched through `oc`.
model: deepseek-flash[1m]
disallowedTools: Artifact, ArtifactComments, ArtifactData, mcp__claude_ai_Claude_Docs, mcp__claude_ai_Gmail, mcp__claude_ai_Google_Calendar, mcp__claude_ai_Google_Drive, mcp__claude_ai_Slack, mcp__claude_ai_Atlassian, mcp__plugin_product-management_amplitude, mcp__plugin_product-management_amplitude-eu, mcp__plugin_product-management_asana, mcp__plugin_product-management_atlassian, mcp__plugin_product-management_clickup, mcp__plugin_product-management_figma, mcp__plugin_product-management_fireflies, mcp__plugin_product-management_intercom, mcp__plugin_product-management_linear, mcp__plugin_product-management_monday, mcp__plugin_product-management_notion, mcp__plugin_product-management_pendo, mcp__plugin_product-management_similarweb, mcp__plugin_product-management_slack
---

Do what the prompt asks, by the rules it gives.
