# API Providers

## Supported Providers

| Provider | Type | Notes |
|----------|------|-------|
| Anthropic | Direct API | Claude models |
| OpenAI | Direct API | GPT models |
| OpenAI Codex | Responses API | ChatGPT subscription, native tool calling |
| OpenRouter | Meta-provider | Multiple model providers |
| AWS Bedrock | Cloud | Enterprise, requires AWS credentials |
| Google Gemini | Direct API | Gemini models |
| GCP Vertex AI | Cloud | Enterprise Google |
| DeepSeek | Direct API | DeepSeek models |
| X AI | Direct API | Grok models |
| Cerebras | Direct API | High-performance inference |
| Ollama | Local | Run models locally |
| LM Studio | Local | Local model hosting |
| OpenAI Compatible | Custom | Any compatible API |

## Configuration Location

- **VSCode**: Settings panel in Cline sidebar
- **CLI**: `cline auth` or `cline config`
- **Storage**: `~/.cline/data/secrets.json` (API keys)

## Adding a New Provider (Development)

When adding a new API provider to the codebase, update these files:

### Required Updates

1. **Proto layer** (or provider silently resets to Anthropic):
   - `proto/cline/models.proto` - Add to `ApiProvider` enum
   - `src/shared/proto-conversions/models/api-configuration-conversion.ts` - Both conversion functions

2. **Core**:
   - `src/shared/api.ts` - Add to `ApiProvider` union, define models
   - `src/shared/providers/providers.json` - Add to dropdown
   - `src/core/api/index.ts` - Register in `createHandlerForProvider()`

3. **Webview**:
   - `webview-ui/src/components/settings/utils/providerUtils.ts` - `getModelsForProvider()`, `normalizeApiConfiguration()`
   - `webview-ui/src/utils/validate.ts` - Add validation case
   - `webview-ui/src/components/settings/ApiOptions.tsx` - Render component

4. **CLI** (if applicable):
   - `cli/src/components/ModelPicker.tsx` - Add to `providerModels` map

### Responses API Providers

Providers using OpenAI's Responses API require native tool calling:

1. Add provider to `isNextGenModelProvider()` in `src/utils/model-utils.ts`
2. Set `apiFormat: ApiFormat.OPENAI_RESPONSES` on models in `src/shared/api.ts`

Without these, tools get called multiple times or arguments get malformed.

## Local Models

### Ollama

- Install from ollama.ai
- Run `ollama pull <model>`
- Configure in Cline with localhost URL

### LM Studio

- Download and run LM Studio
- Start local server
- Configure in Cline with localhost URL

### Hardware Requirements

| Config | RAM | Performance |
|--------|-----|-------------|
| Entry-level (4-bit) | 32GB | Functional |
| Better quality (8-bit) | 64GB | Good |
| Cloud-competitive | 128GB+ | Excellent |

Local models: 5-20 tokens/second vs hundreds from cloud.

## Model Selection

### By Task Size

| Task | Recommended |
|------|-------------|
| Quick fixes, typos | Smaller/faster model |
| Standard development | Claude Sonnet, GPT-4o |
| Complex architecture | Claude Opus, GPT-5 |

### Plan/Act Mode Models

Enable "Use different models for Plan and Act" in settings:

| Use Case | Plan Mode | Act Mode |
|----------|-----------|----------|
| Cost optimization | Smaller model | Faster model |
| Maximum quality | Claude Opus | Claude Sonnet |
| Speed-focused | Gemini Flash | Cerebras |

## Cross-References

- MCP for extending capabilities → See [mcp.md](mcp.md)
- CLI provider setup → See [cli.md](cli.md)
- Architecture details → See [architecture.md](architecture.md)