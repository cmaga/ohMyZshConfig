# AgentOS SDK Skill Trigger

## When to Use the `agentos-sdk` Skill

Invoke the `agentos-sdk` skill when working on any of these tasks:

- Creating or modifying Actions
- Implementing TTS, ASR, or LLM features
- Working with robot navigation or motion control
- Using PersonApi for face/person detection
- Accessing camera via SurfaceShareApi
- Implementing wake-free functionality
- Encountering import path errors
- Debugging runtime issues with SDK APIs

## Documentation Priority

**For any AgentOS or RobotAPI development requirements or errors, follow this priority:**

1. **FIRST**: Invoke the `agentos-sdk` skill to load relevant SDK documentation
2. **ONLY THEN**: Consult online resources if SDK docs have no relevant information

**It is strictly forbidden to use online resources or general Android development materials without first consulting SDK documentation via the skill.**

## How the Skill Works

When invoked, the skill provides:

- Documentation file references based on your task
- Quick reference patterns for common operations
- Instructions on which specific doc to read

The skill does NOT preload all documentation - it guides you to the relevant files on-demand.
