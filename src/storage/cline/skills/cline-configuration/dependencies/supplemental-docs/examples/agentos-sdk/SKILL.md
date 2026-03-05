---
name: agentos-sdk
description: Load detailed AgentOS SDK and RobotAPI documentation. Use when creating Actions, working with TTS/ASR, LLM integration, navigation, person detection, camera access, or any SDK-specific implementation.
---

# AgentOS SDK Documentation Skill

This skill provides detailed guidance for AgentOS SDK and RobotAPI development.

## When This Skill Activates

- Creating or modifying Actions
- Implementing TTS, ASR, or LLM features
- Working with robot navigation or motion control
- Using PersonApi for face/person detection
- Accessing camera via SurfaceShareApi
- Implementing wake-free functionality
- Any AgentOS or RobotAPI specific implementation

## Documentation Files

Read the relevant documentation based on the task:

### AgentOS SDK (AI Capabilities)

| Task              | Read This File                                                                       |
| ----------------- | ------------------------------------------------------------------------------------ |
| Full SDK overview | [AgentOS_SDK_Doc_v0.4.5.md](agentos-sdk-docs/Agent/v0.4.5/AgentOS_SDK_Doc_v0.4.5.md) |
| API details       | [API_Reference.md](agentos-sdk-docs/Agent/v0.4.5/API_Reference.md)                   |
| Code examples     | [SampleCodes.md](agentos-sdk-docs/Agent/v0.4.5/SampleCodes.md)                       |
| Import paths      | [ClassPathList.md](agentos-sdk-docs/Agent/v0.4.5/ClassPathList.md)                   |

### RobotAPI (Hardware Control)

| Task                                | Read This File                                           |
| ----------------------------------- | -------------------------------------------------------- |
| Navigation, motion, sensors, camera | [RobotAPI.md](agentos-sdk-docs/Robot/v11.3C/RobotAPI.md) |

### Troubleshooting

| Issue                       | Read This File                    |
| --------------------------- | --------------------------------- |
| Common issues and solutions | [FAQ.md](agentos-sdk-docs/FAQ.md) |

## Quick Reference

### Action Design Checklist

1. **Single Responsibility**: One Action = one clear function
2. **Clear Description**: `desc` must be specific for LLM to understand
3. **Proper Parameters**: Use correct ParameterType, set required appropriately
4. **Always notify()**: Call `action.notify()` after async work completes

### Key SDK Patterns

**Action Executor Pattern:**

```kotlin
executor = object : ActionExecutor {
    override fun onExecute(action: Action, params: Bundle?): Boolean {
        AOCoroutineScope.launch {
            try {
                // Your async work here
                action.notify()  // SUCCESS
            } catch (e: Exception) {
                action.notify(ActionResult(ActionStatus.FAILED))
            }
        }
        return true  // Return immediately, don't block
    }
}
```

**TTS Usage:**

```kotlin
// Async (non-blocking)
AgentCore.tts("Hello!")

// Sync (must be in coroutine)
AOCoroutineScope.launch {
    AgentCore.ttsSync("Hello!")
    // Continues after TTS completes
}
```

**LLM Direct Call:**

```kotlin
val messages = listOf(
    LLMMessage(Role.SYSTEM, "You are a helpful assistant"),
    LLMMessage(Role.USER, "User question here")
)
val config = LLMConfig(temperature = 0.7f, maxTokens = 100)
AgentCore.llmSync(messages, config, timeoutMillis = 30000)
```

## Instructions

1. Identify which SDK feature is needed for the current task
2. Read the relevant documentation file(s) listed above
3. Apply patterns from the documentation to the implementation
4. Follow the architecture rules (thin Agent layer, Action-UseCase flow)
