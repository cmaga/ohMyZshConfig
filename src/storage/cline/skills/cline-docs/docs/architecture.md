# Cline Architecture

## Mental Model

Cline is a VSCode extension with three layers:
1. **WebviewProvider** - Manages webview lifecycle and VSCode integration
2. **Controller** - Single source of truth for state, handles messages
3. **Task** - Executes AI requests and tool operations

Data flows: WebviewProvider ↔ Controller ↔ Task ↔ API Providers

## Core Classes

### WebviewProvider (`src/core/webview/index.ts`)

- Manages multiple active instances via static `activeInstances` set
- Handles webview lifecycle (creation, visibility, disposal)
- Generates HTML with CSP headers
- Supports HMR in development
- Delegates all message handling to Controller

### Controller (`src/core/controller/index.ts`)

The orchestrator. Responsibilities:
- State management (global, workspace, secrets)
- Task lifecycle (create, resume, abort)
- MCP server connections via McpHub
- Webview message handling
- Multi-instance coordination

Key methods:
- `initClineWithTask()` - Create new task
- `getStateToPostToWebview()` - Sync state to UI
- `updateTaskHistory()` - Persist task metadata

### Task (`src/core/task/index.ts`)

Executes AI interactions. Each task:
- Has unique ID and dedicated storage directory
- Runs in isolation
- Manages its own conversation history
- Handles tool execution with approval flow
- Creates checkpoints after tool use

Core loop:
```typescript
async initiateTaskLoop(userContent, isNewTask) {
  while (!this.abort) {
    const stream = this.attemptApiRequest()
    for await (const chunk of stream) {
      this.assistantMessageContent = parseAssistantMessageV2(chunk.text)
      await this.presentAssistantMessage()
    }
    await pWaitFor(() => this.userMessageContentReady)
    await this.recursivelyMakeClineRequests(this.userMessageContent)
  }
}
```

## State Management

### Storage Architecture

All state stored in `~/.cline/data/` (shared across VSCode, CLI, JetBrains):

```
~/.cline/data/
  globalState.json          # Settings, preferences
  secrets.json              # API keys (mode 0o600)
  tasks/taskHistory.json    # Task history
  workspaces/<hash>/        # Per-workspace state
```

### Key Abstractions

| Class | Location | Purpose |
|-------|----------|---------|
| StorageContext | `src/shared/storage/storage-context.ts` | Entry point, creates file storage instances |
| ClineFileStorage | `src/shared/storage/ClineFileStorage.ts` | Atomic JSON key-value store |
| StateManager | `src/core/storage/StateManager.ts` | In-memory cache with debounced flush |

### State Access Pattern

```typescript
// Reading
StateManager.get().getGlobalStateKey("myKey")
StateManager.get().getSecretKey("mySecretKey")

// Writing
StateManager.get().setGlobalState("myKey", value)
StateManager.get().setSecret("mySecretKey", value)
```

**Warning**: Do NOT use `context.globalState` or `context.secrets` - those are VSCode-specific.

### Adding New State Keys

1. Add to `src/shared/storage/state-keys.ts`
2. Read from globalState in `src/core/storage/utils/state-helpers.ts`:
   - Add `const myKey = context.globalState.get<...>("myKey")` in `readGlobalStateFromDisk()`
   - Add to return object
3. For settings toggles, wire both update paths:
   - `src/core/controller/state/updateSettings.ts` (webview)
   - `src/core/controller/state/updateSettingsCli.ts` (CLI)
4. Add field to `UpdateSettingsRequest` in `proto/cline/state.proto`, run `npm run protos`

## gRPC/Protobuf Communication

Extension and webview communicate via gRPC-like protocol over VSCode message passing.

### Proto File Organization

- `proto/cline/` - Feature-specific protos (task.proto, ui.proto, account.proto)
- `proto/cline/common.proto` - Shared types (StringRequest, Empty, Int64Request)

### Adding New RPC

1. **Define in proto** (`proto/cline/<domain>.proto`):
```proto
service UiService {
  rpc myMethod(StringRequest) returns (KeyValuePair);
}
```

2. **Compile**: `npm run protos`

3. **Implement handler** (`src/core/controller/<domain>/myMethod.ts`):
```typescript
export async function myMethod(controller: Controller, request: StringRequest): Promise<KeyValuePair> {
  return KeyValuePair.create({ key: "action", value: request.value })
}
```

4. **Call from webview**:
```typescript
import { UiServiceClient } from "../../../services/grpc"
await UiServiceClient.myMethod(StringRequest.create({ value: "test" }))
```

### Naming Conventions

- Services: `PascalCaseService`
- RPCs: `camelCase`
- Messages: `PascalCase`
- Streaming: use `stream` keyword on response

## Adding New Tools

Tools are modular. Full chain: prompt definition → variant configs → handler → UI.

### Steps

1. **Add enum** in `src/shared/tools.ts`:
```typescript
export enum ClineDefaultTool {
  // ...existing
  MY_TOOL = "my_tool",
}
```

2. **Create tool definition** in `src/core/prompts/system-prompt/tools/my_tool.ts`:
```typescript
const GENERIC: ClineToolVariant = {
  name: ClineDefaultTool.MY_TOOL,
  modelFamily: ModelFamily.GENERIC,
  toolSpec: { /* tool specification */ }
}
export const my_tool_variants = [GENERIC]
```

3. **Register** in `src/core/prompts/system-prompt/tools/init.ts`:
```typescript
import { my_tool_variants } from "./my_tool"
export const allToolVariants = [
  ...existing,
  ...my_tool_variants,
]
```

4. **Add to variant configs** - Add tool enum to `.tools()` list in each relevant config:
   - `variants/generic/config.ts`
   - `variants/next-gen/config.ts`
   - `variants/native-next-gen/config.ts`
   - etc.

5. **Create handler** in `src/core/task/tools/handlers/`

6. **Wire in ToolExecutor.ts** if needed

7. **If UI feedback needed**:
   - Add `ClineSay` enum value in proto
   - Update `src/shared/ExtensionMessage.ts`
   - Update `src/shared/proto-conversions/cline-message.ts`
   - Update `webview-ui/src/components/chat/ChatRow.tsx`

### Model Family Fallback

If a variant isn't defined for a model family, `ClineToolSet.getToolByNameWithFallback()` falls back to GENERIC. Only export specific variants if behavior differs.

## Adding API Providers

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

## System Prompt Architecture

Modular structure: components + variants + templates.

### Directories

```
src/core/prompts/system-prompt/
  components/         # Shared sections (rules.ts, capabilities.ts)
  variants/           # Model-specific configs
    generic/          # Default fallback
    next-gen/         # Claude 4, GPT-5, Gemini 2.5
    native-next-gen/  # Next-gen with native tool calling
    xs/               # Small/local models
    hermes/           # Hermes models
    glm/              # GLM models
  templates/          # Template engine
  tools/              # Tool definitions
```

### Variant Tiers

| Tier | Models | Directory |
|------|--------|-----------|
| Next-gen | Claude 4, GPT-5, Gemini 2.5 | `next-gen/`, `native-next-gen/`, `gpt-5/` |
| Standard | Default | `generic/` |
| Small/Local | Ollama, LM Studio | `xs/`, `hermes/`, `glm/` |

### Modifying Rules

1. Check if variant overrides: look for `rules_template` in `variants/*/template.ts`
2. If shared: modify `components/rules.ts`
3. If overridden: modify that variant's template
4. Regenerate snapshots: `UPDATE_SNAPSHOTS=true npm run test:unit`

## Cross-References

- State persistence details → See storage section above
- Tool execution flow → See Task class documentation
- Webview state → `webview-ui/src/context/ExtensionStateContext.tsx`
- MCP integration → See [mcp.md](mcp.md)
- CLI architecture → See [cli.md](cli.md)