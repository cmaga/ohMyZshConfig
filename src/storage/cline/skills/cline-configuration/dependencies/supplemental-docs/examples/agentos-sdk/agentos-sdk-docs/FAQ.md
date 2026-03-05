# FAQ

## Table of Contents

- [FAQ](#faq)
  - [Table of Contents](#table-of-contents)
  - [Concepts You Need to Know](#concepts-you-need-to-know)
    - [Application Authorization](#application-authorization)
    - [Application Suspension](#application-suspension)
    - [Application Resume from Suspension](#application-resume-from-suspension)
  - [Enabling Developer Mode](#enabling-developer-mode)
    - [Background](#background)
    - [How to Enable](#how-to-enable)
    - [Getting the Dynamic Password](#getting-the-dynamic-password)
  - [How to Retrieve Robot Raw Logs](#how-to-retrieve-robot-raw-logs)
    - [1. View All Saved Logs on the Robot](#1-view-all-saved-logs-on-the-robot)
    - [2. Pull Logs for a Specific Time Period](#2-pull-logs-for-a-specific-time-period)
  - [Common ADB Commands](#common-adb-commands)
    - [1. adb devices](#1-adb-devices)
    - [2. adb shell](#2-adb-shell)
    - [3. adb push](#3-adb-push)
    - [4. adb pull](#4-adb-pull)
    - [5. adb install](#5-adb-install)
  - [Common Issues and Solutions](#common-issues-and-solutions)
    - [No Response to Voice Interaction](#no-response-to-voice-interaction)
    - [PageAgent Lifecycle Management for Non-Activity/Fragment Development](#pageagent-lifecycle-management-for-non-activityfragment-development)
    - [Do I Need to Re-implement Features When Migrating from RobotOS to AgentOS?](#do-i-need-to-re-implement-features-when-migrating-from-robotos-to-agentos)
    - [Will AgentOS Automatically Call Xiaobao Application Features?](#will-agentos-automatically-call-xiaobao-application-features)
    - [What If Persona and PageAgent Cannot Meet Business Requirements?](#what-if-persona-and-pageagent-cannot-meet-business-requirements)
      - [Basic Optimization Solutions](#basic-optimization-solutions)
      - [Dynamic Information Update](#dynamic-information-update)
      - [Complex Conversation Scenarios](#complex-conversation-scenarios)

## Concepts You Need to Know

### Application Authorization

An app can only be successfully authorized to use the SDK when it has successfully connected to RobotOS and its interface is displayed in the foreground. When the app interface goes to the background, the app is immediately suspended.

### Application Suspension

During robot operation, certain system events may occur, such as emergency stop, low battery, OTA update, hardware exceptions, etc. When these system events occur, RobotOS takes over the business, and the foreground business APK will be suspended, receiving an onSuspend event. The business APK will no longer have the ability to use APIs.

### Application Resume from Suspension

Corresponding to suspension events, when system events disappear, RobotOS returns business control to the current app, and the current APK resumes the ability to use RobotAPI.

## Enabling Developer Mode

### Background

To ensure robot system security, future versions will have USB debugging (wired ADB) disabled by default. The affected robots and versions are:

- **Leopard Secretary**: V6.9 and later versions
- **Mini**: V6.13 and later versions

### How to Enable

Factory versions have ADB disabled by default. It can only be temporarily enabled through the following method:

1. At any time (including during self-check exceptions), pull down with a single finger >> tap the time area multiple times rapidly

2. A dynamic password input page will pop up. This page displays the system date and time. For obtaining the dynamic password, see the [Getting the Dynamic Password](#getting-the-dynamic-password) section
   - **Dynamic password entered correctly**: Proceed to step three to configure ADB settings
   - **Dynamic password entered incorrectly**: Input content is cleared, stay on the current page

3. When "Enable Debugging" is turned on, a second menu "Persistent Debugging" appears. Note that "Enable Debugging" will reset to default after restart
   - "Persistent Debugging" menu is not displayed by default; it only appears after "Enable Debugging" is turned on
   - "Persistent Debugging" is disabled by default when displayed and needs to be manually enabled
   - When "Enable Debugging" is turned off again, "Persistent Debugging" is automatically disabled and the menu is hidden
   - The above settings take effect after restart

   For developer convenience, three additional quick functions are provided: "Open MIMI", "Enable System Navigation Bar", "Open Settings"

4. Newly manufactured robots all support WiFi ADB debugging. WiFi ADB can also be enabled here for convenient debugging.

### Getting the Dynamic Password

Provide the SN number and contact your pre-sales/after-sales technical support

If you need to view a video on enabling developer mode, please visit: [Detailed Tutorial on Enabling Developer Mode](https://doc.orionstar.com/blog/knowledge-base/%e6%89%93%e5%bc%80%e5%bc%80%e5%8f%91%e8%80%85%e6%a8%a1%e5%bc%8f/#undefined)

## How to Retrieve Robot Raw Logs

### 1. View All Saved Logs on the Robot

Use the following commands to enter the robot shell and view the log directory:

```bash
adb shell
cd /sdcard/logs/offlineLogs/821/
ls -l
```

### 2. Pull Logs for a Specific Time Period

After exiting adb shell, use the adb pull command to retrieve logs for the required time period:

```bash
adb pull /sdcard/logs/offlineLogs/821/logcat.log-2020-05-22-11-00-07-062.tgz
```

> **Note**: Log file names include specific timestamps. Please select the corresponding log files based on the actual time period needed.

## Common ADB Commands

Robot development, whether using OPK or APK, is based on Android development. Therefore, we first need to ensure the Android environment is working properly. ADB commands are particularly important in the Android environment. Here are some commonly used ADB commands:

### 1. adb devices

This command is used to query currently connected device IDs. When the computer is properly connected to the robot, it will return a list of robots, for example:

```bash
black_mac:dexlib mac$ adb devices
List of devices attached
KTS17Q080284    device
```

If no list of connected robots is returned, debugging is not possible. First, check whether the USB cable is connected to the robot and secure. If you encounter other issues, please search "adb devices not returning correct results" online.

### 2. adb shell

This command is used to enter the robot's terminal shell. Here are some commonly used adb shell commands:

**View robot SN code:**

```bash
adb shell getprop|grep serial
```

### 3. adb push

This command is used to push files to the robot. It is used during manual robot upgrades when we need to push the upgrade package to the corresponding folder on the robot.

```bash
adb push xxx.opk /system/vendor/opk/
```

**Manual OTA upgrade:**

With ADB commands working properly and connected to the robot, execute the following commands:

```bash
# Open OTA service
adb shell am start -n com.ainirobot.ota/.MainActivity

# Push the OTA package, xxx is the file path of the OTA package
adb push xxxx /sdcard/ota/download/update.zip
```

After the package is pushed, click "Start Upgrade" on the robot's page

### 4. adb pull

This command is used to retrieve files from the robot. It is used when we need to get robot logs.

**Get the robot's recent logs:**

```bash
adb pull /sdcard/logs/offlineLogs/821/
```

**Get robot logs for a specific time:**

1. Use this command to view all saved logs on the robot:

```bash
adb shell
cd /sdcard/logs/offlineLogs/821/
ls -l
```

1. After exiting adb shell, use adb pull to retrieve logs for the required time period:

```bash
adb pull /sdcard/logs/offlineLogs/821/logcat.log-2020-05-22-11-00-07-062
```

### 5. adb install

This command is used to install applications on the robot, typically for installing developed APK packages.

**Install APK:**

```bash
adb install -r -d xx.apk  # xx.apk is the absolute path to your file
```

> **More ADB commands**: Please search "ADB usage tutorial" online for more detailed information.

## Common Issues and Solutions

### No Response to Voice Interaction

**Problem Description**: When interacting with the robot through voice input, the system does not respond or cannot properly execute the expected Action.

**Troubleshooting Steps**:

1. **Network Connection Verification**: Confirm the device is connected to the network. ASR service depends on network connection for speech recognition processing. You can test network status through the robot's network detection feature.
2. **System Status Check**: Verify the robot is not currently in charging, OTA upgrade, or other system event states, as these states will cause the application to be suspended.
3. **Microphone Status Confirmation**:
   - Verify the microphone hardware status is enabled
   - Confirm the current application is a secondary development application or Xiaobao application (only these two types of applications have the microphone enabled by default)
   - Check if any microphone-related disable APIs have been called in the code
4. **User Interaction Position**: Ensure the user is positioned directly in front of the robot, facing the robot, and within the effective recognition range
5. **Wake-Free Feature Status**: If the application is calling the camera, you can test by disabling the wake-free feature or turning off the camera call. After confirming it is a wake-free issue, it is recommended to temporarily disable the wake-free feature to avoid conflict with camera calls, or use camera data stream sharing to avoid resource contention.
6. **ASR/TTS Service Status**: Confirm that the ASR (Automatic Speech Recognition) and TTS (Text-to-Speech) service subtitle bar listeners are enabled.
7. **Action Registration Verification**: Ensure the application has registered at least one SAY Action to avoid no response due to failed LLM Action planning.

### PageAgent Lifecycle Management for Non-Activity/Fragment Development

**Problem Description**: When developing with cross-platform frameworks like Flutter or custom UI frameworks, PageAgent cannot be directly constructed using Activity/Fragment, and PageAgent lifecycle needs to be managed manually.

**Solution**:

1. **Manually Create PageAgent**: Use the pageId constructor to create a PageAgent instance, not dependent on Activity/Fragment lifecycle.
2. **Lifecycle Management**: Developers need to manually call PageAgent lifecycle methods at appropriate times:
   - **When page is displayed**: Call `begin()` method to activate PageAgent, making registered Actions take effect
   - **When page is hidden**: Call `end()` method to pause PageAgent, stopping Action responses
   - **When page is destroyed**: Call `destroy()` method to release PageAgent resources
3. **State Synchronization**: Ensure PageAgent lifecycle state remains consistent with actual page visibility to avoid responding to voice interaction when the page is not visible.

**Code Example**:

```kotlin
// Create PageAgent instance, need to provide a unique pageId
val pageAgent = PageAgent("your_page_id")

// Register Actions (before begin())
pageAgent.registerAction(yourAction)

// Activate when page is displayed
pageAgent.begin()

// Pause when page is hidden
pageAgent.end()

// Release when page is destroyed
pageAgent.destroy()
```

**Important Notes**:

- Must strictly call corresponding methods according to the actual lifecycle of the page
- Avoid keeping PageAgent active after the page has been destroyed
- Ensure Action registration is completed before PageAgent activation
- **Page Switching Management**: When switching pages, you must promptly end the previous PageAgent, then create and activate the new page's PageAgent

### Do I Need to Re-implement Features When Migrating from RobotOS to AgentOS?

**Yes, business logic migration is required.**

- **Trigger Method Change**: RobotOS through domain and skill matching → AgentOS through Action matching
- **Code Migration**: Migrate original business logic code to Action callbacks
- **Example**: Navigation function was previously executed after skill matching, now needs to execute the same logic in the navigation Action callback

### Will AgentOS Automatically Call Xiaobao Application Features?

**No, it will not automatically call. Developers need to implement themselves.**

- **Core Principle**: AgentOS will not automatically call Xiaobao application or system components
- **Development Requirement**: All features need to be implemented in Actions by developers
- **Example**: Calendar query requires developers to call calendar APIs and handle results, rather than calling built-in Xiaobao components
- **Jump Support**: You can use `AgentCore.jumpToXiaobao()` method to jump to the Xiaobao application home page

### What If Persona and PageAgent Cannot Meet Business Requirements?

**Prioritize optimizing persona and Action design. Use advanced interfaces when necessary.**

#### Basic Optimization Solutions

- **Persona Optimization**: Improve persona information to enhance intelligent interaction effects
- **Action Design**: Optimize Action logic to meet business function requirements

#### Dynamic Information Update

- **Interface**: `uploadInterfaceInfo()`
- **Use Cases**: UI changes, task progress updates, new information that needs to be notified to the LLM
- **Function**: Real-time update of application status, keeping LLM information synchronized

#### Complex Conversation Scenarios

- **Interfaces**: `llmSync()` and `llm()`
- **Use Cases**: Complex conversations, custom intelligent interaction requirements
- **Implementation**:

```kotlin
val introQuery = "Brief self-introduction, no more than 30 characters"

// Build message list
val messages = mutableListOf<LLMMessage>()

// Add system prompt
messages.add(
    LLMMessage(
        LLMRole.SYSTEM,
        """You are now playing the role of: ${roleData.name}
        |Character setting: ${roleData.persona}
        |Behavior guidelines: ${roleData.objective}
        |
        |Now you need to give a brief self-introduction, requirements:
        |1. Fully immerse in the character, show character features
        |2. Self-introduction should be natural and friendly, no more than 30 characters
        |3. Reflect the character's personality and traits
        |4. Do not reveal AI identity
        |5. Let users feel the character's charm""".trimMargin()
    )
)

// Add user request
val userMessage = LLMMessage(LLMRole.USER, introQuery)
messages.add(userMessage)

val config = LLMConfig(
    temperature = 0.8f,
    maxTokens = 80  // Limit initial introduction length
)

// Generate response (streaming playback, robot's response will be received in onTranscribe)
AgentCore.llmSync(messages, config, 20 * 1000)
```
