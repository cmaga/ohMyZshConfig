# MCP (Model Context Protocol)

## Overview

MCP standardizes how applications provide context to LLMs. Servers act as intermediaries between LLMs and external tools/data sources.

**Key Concepts:**
- **Tools**: Functions the LLM can execute
- **Resources**: Read-only data access
- **Hosts**: Discover and load server capabilities

## Use Cases

- Web services and API integration (GitHub, Slack, weather data)
- Browser automation (testing, scraping)
- Database queries and reports
- Project/task management (Jira, issue tracking)
- Codebase documentation generation

## Getting Started

Cline has no pre-installed MCP servers. Options:

1. **Cline Marketplace** - One-click installation
2. **Community repositories** - GitHub collections
3. **Ask Cline** - Build or find servers
4. **Build your own** - Using MCP SDK

## Marketplace Installation

1. Click Extensions button (square icon) in Cline toolbar
2. Browse servers by category
3. Click install, enter API key if required
4. Server added to settings automatically

### Behind the Scenes

1. Server code cloned to `~/Documents/Cline/MCP/`
2. Dependencies installed, server built
3. Config updated in `cline_mcp_settings.json`
4. Server launched as separate process
5. Tools available via `use_mcp_tool`, resources via `access_mcp_resource`

## Server Configuration

Settings location: `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`

### STDIO Transport (Local)

```json
{
  "mcpServers": {
    "local-server": {
      "command": "node",
      "args": ["/path/to/server.js"],
      "env": {
        "API_KEY": "your_api_key"
      },
      "alwaysAllow": ["tool1", "tool2"],
      "disabled": false
    }
  }
}
```

### SSE Transport (Remote)

```json
{
  "mcpServers": {
    "remote-server": {
      "url": "https://your-server-url.com/mcp",
      "headers": {
        "Authorization": "Bearer your-token"
      },
      "alwaysAllow": ["tool3"],
      "disabled": false
    }
  }
}
```

## Managing Servers

Access via MCP Servers icon in Cline navigation:

| Action | How |
|--------|-----|
| Enable/Disable | Toggle switch |
| Restart | Click "Restart Server" |
| Delete | Click trash icon |
| Network Timeout | 30 seconds to 1 hour (default 1 min) |

## MCP Rules

Define when to use each server in `.clinerules`:

```json
{
  "mcpRules": {
    "webInteraction": {
      "servers": ["firecrawl-mcp-server", "fetch-mcp"],
      "triggers": ["web", "scrape", "browse", "website"],
      "description": "Tools for web browsing and scraping"
    }
  },
  "defaultBehavior": {
    "priorityOrder": ["webInteraction"],
    "fallbackBehavior": "Ask user which tool"
  }
}
```

## Adding Servers with Cline

Provide GitHub URL, Cline handles the rest:

```text
User: "Add the MCP server from https://github.com/modelcontextprotocol/servers/tree/main/src/brave-search"

Cline: "Cloning. Should I run 'npm run build'?"

User: "Yes"

Cline: "Build complete. This server needs an API key."
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Server not responding | Check process running, verify network |
| Permission errors | Verify API keys and credentials |
| Tool not available | Confirm server implements tool |
| Slow performance | Increase network timeout |

### Removing a Server

1. Open `cline_mcp_settings.json`
2. Delete server entry from `mcpServers` object
3. Save and restart Cline

### System Requirements

- Node.js 18.x+ (for JS/TS servers)
- Python 3.10+ (for Python servers)
- UV package manager (for Python dependency isolation)

## Resources

- Official servers: https://github.com/modelcontextprotocol/servers
- Community collection: https://github.com/punkpeye/awesome-mcp-servers
- Directories: mcpservers.org, mcp.so, glama.ai/mcp/servers

## Cross-References

- MCP in workflows → See [customization.md](customization.md)
- CLI MCP config → See [cli.md](cli.md)
- Auto-approve MCP → See [features.md](features.md)