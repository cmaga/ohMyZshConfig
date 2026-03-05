# AgentOS SDK Development Documentation

## Version Compatibility and Integration Guide

**This document provides a complete AgentOS SDK integration solution. You must strictly select the corresponding SDK version based on the target device model and system version.**

### Version Correspondence

- **Mini Robot**: Latest version → AgentOS SDK v0.4.5 (Recommended)
- **Leopard Secretary 2 Robot**: Latest version → AgentOS SDK v0.4.5 (Recommended)

⚠️ **Important Note**: It is recommended to use the latest ROM version for optimal performance and stability

### Platform Compatibility Matrix

#### 🤖 Leopard Secretary 2 Robot

| System Version | ROM Version      | AgentOS Version | SDK Version | Maintenance Status              |
| -------------- | ---------------- | --------------- | ----------- | ------------------------------- |
| Release Latest | V11.7            | v1.7.0          | v0.4.5      | ✅ Latest Version (Recommended) |
| Release Latest | V11.6.2025092601 | v1.6.0.250925.C | v0.4.4      | ✅ Stable Version               |
| Release        | V11.4.2025082001 | V1.4.0.250818.C | v0.3.7      | ⚠️ Legacy Version               |

#### 🔹 Mini Robot

| System Version   | ROM Version      | AgentOS Version | SDK Version | Maintenance Status              |
| ---------------- | ---------------- | --------------- | ----------- | ------------------------------- |
| Release Latest   | V11.7            | v1.7.0          | v0.4.5      | ✅ Latest Version (Recommended) |
| Release Latest   | V11.6.2025100912 | V1.6.0.250925C  | v0.4.4      | ✅ Stable Version               |
| Release Enhanced | V10.3.2025071101 | V1.3.0.250630.C | v0.3.5      | ⚠️ Legacy Version               |

> **💡 Tip**: It is recommended to use the latest Release system for complete feature support and optimal performance

### Production Environment Recommended Configuration

- **Leopard Secretary 2 Robot**: **AgentOS SDK v0.4.5** + Latest Release System (v1.7.0)
- **Mini Robot**: **AgentOS SDK v0.4.5** + Latest Release System (v1.7.0)

---

### ⚠️ Integration Notes

Version mismatch may cause API call exceptions or runtime errors. Please ensure you select the matching SDK version based on the target device's system version to ensure application stability and compatibility.

---

## SDK Overview

AgentOS SDK is the official development toolkit for OrionStar intelligent robots, providing a complete application development solution. The SDK integrates large language model capabilities, robot hardware control interfaces, voice interaction systems, and other enterprise-grade functional modules, supporting rapid construction of intelligent robot applications.

## Quick Start

### Development Environment Requirements

- **Programming Language**: Java / Kotlin
- **Build Tool**: Gradle
- **Development Platform**: Android Studio
- **Target Platform**: Android

### Core Documentation

#### AgentOS SDK Documentation

- **SDK Development Documentation**: [AgentOS_SDK_Doc_v0.4.5.md](Agent/v0.4.5/AgentOS_SDK_Doc_v0.4.5.md)
  - Large model related capability interfaces: conversation management, speech synthesis, intelligent interaction, etc.
  - New wake word mode control functionality
  - Applicable to the latest versions of Leopard Secretary 2 and Mini robots
- **API Reference**: [v0.4.5 Version](Agent/v0.4.5/API_Reference.md)
  - Complete API reference documentation, including all core classes, interfaces, methods, properties, constructors, parameter descriptions, return values, usage examples, and other detailed explanations
- **Class Path Reference**: [v0.4.5 Version](Agent/v0.4.5/ClassPathList.md)
  - Complete package paths for all key classes in the project
- **Sample Code**: [v0.4.5 Version](Agent/v0.4.5/SampleCodes.md)
  - Typical implementation examples for various functional modules
- **SDK Development Documentation (English)**: [AgentOS_SDK_Doc_v0.4.5_en.md](Agent/v0.4.5/AgentOS_SDK_Doc_v0.4.5_en.md)
  - Comprehensive guide for LLM capabilities, conversation management, TTS, intelligent interaction, wake-free functionality, and more
  - Applicable to the latest versions of Leopard Secretary 2 and Mini robots

#### Robot Native Interfaces

- **RobotOS API**: [RobotAPI.md](Robot/v11.3C/RobotAPI.md)
  - Robot native control interfaces: motion control, navigation, sensors, camera, charging, localization, etc.
  - **Important Update for v0.4.4+**: SDK automatically integrates RobotService dependency, no need to manually add jar packages
- **RobotOS API (English)**: [RobotAPI_en.md](Robot/v11.3C/RobotAPI_en.md)
  - Complete reference for robot native control interfaces: motion control, navigation, sensors, camera, charging, localization, and more
  - **Important Update for v0.4.4+**: SDK automatically integrates RobotService dependency, no need to manually add jar packages

#### Cloud Service Interfaces

- **OpenAPI Documentation**: [https://openapi.orionstar.com/opendocs/zh/index](https://openapi.orionstar.com/opendocs/zh/index)
  - Robot cloud management platform: covering enterprise information management, visitor systems, remote control, data statistics, and other API services

### AI-Assisted Development

#### Cursor AI Integration

- **Complete Guide**: [AGENTOS_CURSOR_AI_GUIDE.md](https://github.com/orionagent/agentos-sdk/blob/main/AGENTOS_CURSOR_AI_GUIDE.md)
  - Detailed Cursor AI integration steps
  - AgentOS SDK dedicated development rules configuration
  - AI-assisted development best practices
- **Configuration Package**: [cursor-rules-dependencies.zip](https://github.com/orionagent/agentos-sdk/blob/main/cursor-rules-dependencies.zip)
  - Contains complete Cursor Rules configuration
  - Supports intelligent code generation and error detection
  - Provides professional AgentOS SDK development suggestions

---

## Development Standards

### Technical Architecture and Collaboration

#### SDK Responsibility Division

- **AgentOS SDK**: Responsible for large model integration, intelligent conversation, Action planning and execution, voice interaction (ASR/TTS), wake-free, and other AI capabilities
- **RobotAPI**: Responsible for robot low-level control, including motion control, navigation, sensors, vision, maps, charging, and other hardware capabilities
- **Collaboration**: AgentOS SDK and RobotAPI work together, with AgentOS SDK handling the intelligent interaction layer and RobotAPI handling the hardware control layer

---

#### ⚠️ Important: Voice and NLP Function Migration

On the AgentOS system, RobotAPI's original ASR, TTS, NLP, and other voice capabilities have been discontinued. All voice and NLP related functions need to be migrated to AgentOS SDK.

**Migration Guide**: For detailed functional differences and migration solutions, please refer to [RobotAPI.md](Robot/v11.3C/RobotAPI.md)

### Development Process

#### Standard Development Steps

1. **Environment Preparation**: Install Android Studio, configure development environment
2. **Documentation Learning**: Read AgentOS SDK documentation and robot native interface documentation
3. **Sample Reference**: Refer to sample code ([v0.4.5 Version](Agent/v0.4.5/SampleCodes.md))
4. **API Reference**: Understand detailed class and method usage through API reference documentation ([v0.4.5 Version](Agent/v0.4.5/API_Reference.md))
5. **Feature Integration**: Integrate AgentOS SDK and robot native APIs as needed
6. **Test Verification**: Test and verify feature implementation

#### Best Practices

- **Low-level Control**: Properly use robot native interfaces for low-level control
- **Asynchronous Programming**: Follow asynchronous programming patterns to avoid blocking the main thread
- **Exception Handling**: Implement proper exception handling and resource management

---

## Other Resources

- **FAQ**: [FAQ.md](FAQ.md)
- **Cursor AI Development Guide**: [AGENTOS_CURSOR_AI_GUIDE.md](https://github.com/orionagent/agentos-sdk/blob/main/AGENTOS_CURSOR_AI_GUIDE.md)
- **AI Development Rules**: [AI_Rules/](AI_Rules/)

---

## Version Information

- **Recommended SDK Version**: AgentOS SDK v0.4.5 (Universal for Leopard Secretary 2 & Mini robots)
- **Robot API Version**: v11.3C
- **Documentation Update Date**: November 19, 2025
