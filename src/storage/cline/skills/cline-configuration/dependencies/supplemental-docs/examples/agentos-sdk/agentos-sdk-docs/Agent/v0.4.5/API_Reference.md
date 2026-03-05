# AgentOS SDK v0.4.5 API Reference Documentation

> **Version Information**
> Current SDK Version: 0.4.5
> Dependency: `implementation 'com.orionstar.agent:sdk:0.4.5-SNAPSHOT'`

## Table of Contents

### Core Classes

- [AppAgent](#appagent) - Application-level Agent, manages global Actions and application lifecycle
- [PageAgent](#pageagent) - Page-level Agent, manages page Actions and page lifecycle
- [AgentCore](#agentcore) - Agent core functionality class, provides static methods
- [Action](#action) - Action definition class, encapsulates all Action properties
- [ActionExecutor](#actionexecutor) - Action executor interface
- [Actions](#actions) - System built-in Action constants class
- [Parameter](#parameter) - Action parameter definition class
- [ParameterType](#parametertype) - Parameter type enumeration

### Base Classes

- [Agent](#agent) - Agent base class, parent class of AppAgent and PageAgent

### Listener Interfaces

- [OnTranscribeListener](#ontranscribelistener) - ASR and TTS result listener interface
- [OnAgentStatusChangedListener](#onagentstatus-changedlistener) - Agent status change listener interface
- [OnActionStatusChangedListener](#onactionstatuschangedlistener) - System Action status change listener interface
- [TTSCallback](#ttscallback) - TTS playback callback interface
- [LLMCallback](#llmcallback) - LLM call callback interface
- [ITaskCallback](#itaskcallback) - Task execution callback interface

### Data Classes

- [Transcription](#transcription) - Voice transcription result class
- [LLMMessage](#llmmessage) - LLM message class
- [LLMConfig](#llmconfig) - LLM configuration class
- [LLMResponse](#llmresponse) - LLM response result class
- [TokenCost](#tokencost) - Token consumption statistics class
- [ActionResult](#actionresult) - Action execution result class
- [TaskResult](#taskresult) - Task execution result class

### Enumeration Classes

- [Role](#role) - Message role enumeration
- [ActionStatus](#actionstatus) - Action execution status enumeration

### Annotation Classes

- [AgentAction](#agentaction) - Action annotation, used to mark Action methods
- [ActionParameter](#actionparameter) - Parameter annotation, used to mark Action parameters

### Utility Classes

- [AOCoroutineScope](#aocoroutinescope) - Agent coroutine scope

---

## Core Classes

### AppAgent

Application-level Agent, manages the entire application's Agent lifecycle and global Actions. There can only be one AppAgent instance per app.

**Package Path:** `com.ainirobot.agent.AppAgent`

**Constructor:**

```kotlin
AppAgent(context: Application)
```

**Parameter Description:**

- `context: Application` - Android application instance

**Core Methods:**

#### onCreate()

```kotlin
abstract fun onCreate()
```

AppAgent initialization callback, used to configure Agent's basic properties and dynamically register Actions.

#### onExecuteAction()

```kotlin
abstract fun onExecuteAction(action: Action, params: Bundle?): Boolean
```

Handles execution of statically registered Actions. Only Actions statically registered in actionRegistry.json will trigger this method.

**Parameter Description:**

- `action: Action` - The Action object to execute
- `params: Bundle?` - Action execution parameters, can be null

**Return Value:**

- `Boolean` - true indicates processing complete, false indicates no self-handling needed

#### setPersona()

```kotlin
override fun setPersona(persona: String): AppAgent
```

Sets the AI assistant's character persona.

**Parameter Description:**

- `persona: String` - Character persona description

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

#### setStyle()

```kotlin
override fun setStyle(style: String): AppAgent
```

Sets the conversation style.

**Parameter Description:**

- `style: String` - Conversation style description

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

#### setObjective()

```kotlin
override fun setObjective(objective: String): AppAgent
```

Sets the task objective.

**Parameter Description:**

- `objective: String` - Task objective description

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

#### setOnAgentStatusChangedListener()

```kotlin
override fun setOnAgentStatusChangedListener(listener: OnAgentStatusChangedListener): AppAgent
```

Sets the Agent status change listener.

**Parameter Description:**

- `listener: OnAgentStatusChangedListener` - Status change listener

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

#### setOnTranscribeListener()

```kotlin
override fun setOnTranscribeListener(listener: OnTranscribeListener): AppAgent
```

Sets the ASR and TTS listener.

**Parameter Description:**

- `listener: OnTranscribeListener` - Transcription result listener

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

#### setOnActionStatusChangedListener()

```kotlin
override fun setOnActionStatusChangedListener(listener: OnActionStatusChangedListener): AppAgent
```

Sets the system Action status change listener.

**Parameter Description:**

- `listener: OnActionStatusChangedListener` - System Action status change listener

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

#### registerAction()

```kotlin
override fun registerAction(action: Action): AppAgent
override fun registerAction(actionName: String): AppAgent
```

Dynamically registers an Action.

**Parameter Description:**

- `action: Action` - The Action object to register
- `actionName: String` - External Action name (overloaded method)

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

#### registerActionNames()

```kotlin
override fun registerActionNames(actionNames: List<String>): AppAgent
```

Batch registers external Action names.

**Parameter Description:**

- `actionNames: List<String>` - List of external Action names

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

#### registerActions()

```kotlin
override fun registerActions(actionList: List<Action>): AppAgent
```

Batch registers Actions.

**Parameter Description:**

- `actionList: List<Action>` - Action list

**Return Value:**

- `AppAgent` - Returns self, supports method chaining

---

### PageAgent

Page-level Agent, manages single page Agent functionality and page-level Actions. Each page can only have one PageAgent instance.

**Package Path:** `com.ainirobot.agent.PageAgent`

**Constructors:**

```kotlin
PageAgent(pageId: String)
PageAgent(activity: Activity)
PageAgent(fragment: Fragment)
```

**Parameter Description:**

- `pageId: String` - Page unique identifier (primary constructor)
- `activity: Activity` - Android Activity instance
- `fragment: Fragment` - Android Fragment instance

**Core Methods:**

#### setPersona()

```kotlin
override fun setPersona(persona: String): PageAgent
```

Sets this Agent's character persona.

**Parameter Description:**

- `persona: String` - Persona description

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### setStyle()

```kotlin
override fun setStyle(style: String): PageAgent
```

Sets this Agent's conversation style.

**Parameter Description:**

- `style: String` - Conversation style

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### setObjective()

```kotlin
override fun setObjective(objective: String): PageAgent
```

Sets this Agent's planning objective.

**Parameter Description:**

- `objective: String` - Planning objective

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### setOnAgentStatusChangedListener()

```kotlin
override fun setOnAgentStatusChangedListener(listener: OnAgentStatusChangedListener): PageAgent
```

Sets the Agent status change listener.

**Parameter Description:**

- `listener: OnAgentStatusChangedListener` - Status change listener

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### setOnTranscribeListener()

```kotlin
override fun setOnTranscribeListener(listener: OnTranscribeListener): PageAgent
```

Sets the ASR and TTS listener.

**Parameter Description:**

- `listener: OnTranscribeListener` - Transcription result listener

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### registerAction()

```kotlin
override fun registerAction(action: Action): PageAgent
override fun registerAction(actionName: String): PageAgent
```

Registers page-level Action.

**Parameter Description:**

- `action: Action` - The Action object to register
- `actionName: String` - External Action name (overloaded method)

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### registerActionNames()

```kotlin
override fun registerActionNames(actionNames: List<String>): PageAgent
```

Batch registers external Action names.

**Parameter Description:**

- `actionNames: List<String>` - List of external Action names

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### registerActions()

```kotlin
override fun registerActions(actionList: List<Action>): PageAgent
```

Batch registers Actions.

**Parameter Description:**

- `actionList: List<Action>` - Action list

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### blockAction()

```kotlin
fun blockAction(actionName: String): PageAgent
```

Excludes a specified global Action.

**Parameter Description:**

- `actionName: String` - Name of Action to exclude

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### blockActions()

```kotlin
fun blockActions(actionNames: List<String>): PageAgent
```

Excludes multiple global Actions.

**Parameter Description:**

- `actionNames: List<String>` - List of Action names to exclude

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### blockAllActions()

```kotlin
fun blockAllActions(): PageAgent
```

Excludes all global Actions, only Actions registered on current page take effect.

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### setOnTranscribeListener()

```kotlin
fun setOnTranscribeListener(listener: OnTranscribeListener): PageAgent
```

Sets the ASR and TTS listener.

**Parameter Description:**

- `listener: OnTranscribeListener` - Transcription result listener

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### setOnAgentStatusChangedListener()

```kotlin
fun setOnAgentStatusChangedListener(listener: OnAgentStatusChangedListener): PageAgent
```

Sets the Agent status change listener.

**Parameter Description:**

- `listener: OnAgentStatusChangedListener` - Status change listener

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

#### setOnActionStatusChangedListener()

```kotlin
fun setOnActionStatusChangedListener(listener: OnActionStatusChangedListener): PageAgent
```

Sets the system Action status change listener.

**Parameter Description:**

- `listener: OnActionStatusChangedListener` - System Action status change listener

**Return Value:**

- `PageAgent` - Returns self, supports method chaining

---

### AgentCore

Agent core functionality class, provides TTS playback, microphone control, LLM calls, and other static methods.

**Package Path:** `com.ainirobot.agent.AgentCore`

**Properties:**

#### appId

```kotlin
val appId: String
```

Current application's appId, read-only property.

#### debugMode

```kotlin
var debugMode: Boolean
```

Whether debug mode is enabled, enabled by default.

#### isMicrophoneMuted

```kotlin
var isMicrophoneMuted: Boolean
```

Microphone mute status control.

**Description:**

- `true` - Muted
- `false` - Unmuted

#### isEnableVoiceBar

```kotlin
var isEnableVoiceBar: Boolean
```

Whether voice bar is enabled, enabled by default.

#### isEnableWakeFree

```kotlin
var isEnableWakeFree: Boolean
```

Whether wake-free feature is enabled, default true.

#### isDisablePlan

```kotlin
var isDisablePlan: Boolean
```

Whether to disable LLM planning, when disabled no more LLM planning will be performed, default false.

**Methods:**

#### ttsSync()

```kotlin
suspend fun ttsSync(text: String, timeoutMillis: Long = 180000): TaskResult<String>
```

TTS synchronous playback interface, must be called within a coroutine.

**Parameter Description:**

- `text: String` - Text to play
- `timeoutMillis: Long` - Timeout in milliseconds, default 180 seconds

**Return Value:**

- `TaskResult<String>` - Task execution result, status=1 indicates success, status=2 indicates failure

#### tts()

```kotlin
fun tts(text: String, timeoutMillis: Long = 180000, callback: TTSCallback? = null)
```

TTS asynchronous playback interface.

**Parameter Description:**

- `text: String` - Text to play
- `timeoutMillis: Long` - Timeout in milliseconds, default 180 seconds
- `callback: TTSCallback?` - Callback, can be null

#### stopTTS()

```kotlin
fun stopTTS()
```

Force interrupt TTS playback.

#### llmSync()

```kotlin
suspend fun llmSync(
    messages: List<LLMMessage>,
    config: LLMConfig,
    timeoutMillis: Long = 180000,
    isStreaming: Boolean = true
): TaskResult<LLMResponse>
```

LLM synchronous call interface, must be called within a coroutine.

**Parameter Description:**

- `messages: List<LLMMessage>` - LLM chat message list
- `config: LLMConfig` - LLM configuration
- `timeoutMillis: Long` - Timeout in milliseconds, default 180 seconds
- `isStreaming: Boolean` - Whether to use streaming output, default true

**Return Value:**

- `TaskResult<LLMResponse>` - Task execution result, status=1 indicates success, status=2 indicates failure

#### llm()

```kotlin
fun llm(
    messages: List<LLMMessage>,
    config: LLMConfig,
    timeoutMillis: Long = 180000,
    isStreaming: Boolean = true,
    callback: LLMCallback? = null
)
```

LLM asynchronous call interface.

**Parameter Description:**

- `messages: List<LLMMessage>` - LLM chat message list
- `config: LLMConfig` - LLM configuration
- `timeoutMillis: Long` - Timeout in milliseconds, default 180 seconds
- `isStreaming: Boolean` - Whether to use streaming output, default true
- `callback: LLMCallback?` - Callback, can be null

#### query()

```kotlin
fun query(text: String)
```

Trigger LLM planning Action through text-form user question.

**Parameter Description:**

- `text: String` - Text of user's question, e.g.: "What's the weather today?"

#### uploadInterfaceInfo()

```kotlin
fun uploadInterfaceInfo(interfaceInfo: String)
```

Upload page information to help the LLM understand current page content.

**Parameter Description:**

- `interfaceInfo: String` - Page information description, preferably with page component hierarchy, but content should not be too long

#### clearContext()

```kotlin
fun clearContext()
```

Clear LLM conversation context history.

#### jumpToXiaobao()

```kotlin
fun jumpToXiaobao(context: Context)
```

Jump to Xiaobao application.

**Parameter Description:**

- `context: Context` - Context, used to start Activity

#### enableWakeupMode()

```kotlin
fun enableWakeupMode(enabled: Boolean)
```

Enable or disable wake word mode.

**Parameter Description:**

- `enabled: Boolean` - true to enable wake word mode, false to disable (default)

**Description:**

- When enabled, wake word must be used to start pickup recognition
- When disabled, VAD detecting voice starts recognition immediately

#### setWakeupVadTimeout()

```kotlin
fun setWakeupVadTimeout(timeout: Long)
```

Set pickup timeout after VAD ends.

**Parameter Description:**

- `timeout: Long` - Timeout in milliseconds, range: 1000ms ~ 10000ms, default 3000ms

**Description:**

- Controls how long to continue pickup after user finishes speaking
- Continuing to speak within timeout does not require re-waking

#### setWakeupQuestionTimeout()

```kotlin
fun setWakeupQuestionTimeout(timeout: Long)
```

Set pickup window duration after AI asks a question.

**Parameter Description:**

- `timeout: Long` - Timeout in milliseconds, range: 3000ms ~ 30000ms, default 10000ms

**Description:**

- When AI speech ends with Chinese question mark "?", pickup window automatically opens
- User can respond directly without wake word
- 1.5 second delay confirmation to avoid false detection

---

### Action

Action definition class, encapsulates Action's name, description, parameters, and executor.

**Package Path:** `com.ainirobot.agent.action.Action`

**Constructors:**

**Full Constructor:**

```kotlin
Action(
    name: String,
    appId: String,
    displayName: String,
    desc: String,
    parameters: List<Parameter>?,
    executor: ActionExecutor?
)
```

**Internal Action Constructor:**

```kotlin
Action(
    name: String,
    displayName: String,
    desc: String,
    parameters: List<Parameter>?,
    executor: ActionExecutor?
)
```

**External Action Constructor (name only):**

```kotlin
Action(name: String)
```

**Parameter Description:**

- `name: String` - Action full name, recommended format: com.company.action.ACTION_NAME
- `appId: String` - Current application's appId (full constructor)
- `displayName: String` - Display name, may be used for display on UI
- `desc: String` - Action description, used to let the LLM understand when to call this action
- `parameters: List<Parameter>?` - Parameter descriptions expected when action is planned, can be null
- `executor: ActionExecutor?` - Executor corresponding to the action, can be null

**Description:**

- Internal Action constructor automatically uses current application's appId
- External Action constructor is mainly used to register existing external Actions, such as system Actions or statically registered Actions from other applications

**Properties:**

#### sid

```kotlin
var sid: String
```

Planned action's ID, used to identify action uniqueness. Same action returns different actionId for each planning.

#### userQuery

```kotlin
var userQuery: String
```

User question that triggered the planning.

**Methods:**

#### notify()

```kotlin
fun notify(
    result: ActionResult = ActionResult(ActionStatus.SUCCEEDED),
    isTriggerFollowUp: Boolean = false
)
```

Sync execution result after Action execution completes.

**Parameter Description:**

- `result: ActionResult` - Action execution result, default is success
- `isTriggerFollowUp: Boolean` - Proactively guide user to next step after Action execution completes, disabled by default

---

### ActionExecutor

Action executor interface, defines Action execution logic callback method.

**Package Path:** `com.ainirobot.agent.action.ActionExecutor`

**Methods:**

#### onExecute()

```kotlin
fun onExecute(action: Action, params: Bundle?): Boolean
```

Action execution callback method.

**Parameter Description:**

- `action: Action` - Action object to execute
- `params: Bundle?` - Action execution parameters, can be null

**Return Value:**

- `Boolean` - true indicates processing complete, false indicates no self-handling needed

**Important Notes:**

- This method cannot execute time-consuming operations
- Time-consuming operations should be placed in coroutines or threads
- Must call action.notify() method after execution completes

---

### Actions

System built-in Action constants class, provides system predefined Action name constants.

**Package Path:** `com.ainirobot.agent.action.Actions`

**System-handled Actions:**

#### SET_VOLUME

```kotlin
const val SET_VOLUME = "orion.agent.action.SET_VOLUME"
```

Adjust system volume.

#### SAY

```kotlin
const val SAY = "orion.agent.action.SAY"
```

Robot fallback conversation.

#### CANCEL

```kotlin
const val CANCEL = "orion.agent.action.CANCEL"
```

Cancel, default handling simulates Back key press.

#### BACK

```kotlin
const val BACK = "orion.agent.action.BACK"
```

Back, default handling simulates Back key press.

#### EXIT

```kotlin
const val EXIT = "orion.agent.action.EXIT"
```

Exit, default handling simulates Back key press.

#### KNOWLEDGE_QA

```kotlin
const val KNOWLEDGE_QA = "orion.agent.action.KNOWLEDGE_QA"
```

Knowledge base Q&A.

#### GENERATE_MESSAGE

```kotlin
const val GENERATE_MESSAGE = "orion.agent.action.GENERATE_MESSAGE"
```

Say a welcome or farewell message to user.

#### ADJUST_SPEED

```kotlin
const val ADJUST_SPEED = "orion.agent.action.ADJUST_SPEED"
```

Adjust robot speed.

**User-handled Actions:**

#### CONFIRM

```kotlin
const val CONFIRM = "orion.agent.action.CONFIRM"
```

Confirm, needs user handling.

#### CLICK

```kotlin
const val CLICK = "orion.agent.action.CLICK"
```

Click, needs user handling.

---

### Parameter

Action parameter definition class, describes parameter information required by Action.

**Package Path:** `com.ainirobot.agent.base.Parameter`

**Constructor:**

```kotlin
Parameter(
    name: String,
    type: ParameterType,
    desc: String,
    required: Boolean,
    enumValues: List<String>? = null
)
```

**Parameter Description:**

- `name: String` - Parameter name, recommend using English, multiple words connected with underscores
- `type: ParameterType` - Parameter type
- `desc: String` - Parameter description, should accurately reflect this parameter's definition
- `required: Boolean` - Whether this is a required parameter
- `enumValues: List<String>?` - When type is ENUM, pass this parameter as enum value selection list

---

### ParameterType

Parameter type enumeration, defines data types supported by Action parameters.

**Package Path:** `com.ainirobot.agent.base.ParameterType`

**Enum Values:**

#### STRING

String type.

#### INT

Integer type.

#### FLOAT

Floating point type.

#### BOOLEAN

Boolean type.

#### ENUM

Enum type, needs to be used with Parameter's enumValues.

#### NUMBER_ARRAY

Number array type.

#### STRING_ARRAY

String array type.

---

## Base Classes

### Agent

Agent base class, parent class of AppAgent and PageAgent, defines Agent's common methods and properties.

**Package Path:** `com.ainirobot.agent.Agent`

**Common Methods:**

#### setPersona()

```kotlin
open fun setPersona(persona: String): Agent
```

Sets this Agent's character persona.

**Parameter Description:**

- `persona: String` - Persona description, e.g.: "Your name is Xiaobao, you are a chat robot"

**Return Value:**

- `Agent` - Returns self, supports method chaining

#### setStyle()

```kotlin
open fun setStyle(style: String): Agent
```

Sets this Agent's conversation style.

**Parameter Description:**

- `style: String` - Conversation style, e.g.: professional, friendly, humorous

**Return Value:**

- `Agent` - Returns self, supports method chaining

#### setObjective()

```kotlin
open fun setObjective(objective: String): Agent
```

Sets this Agent's planning objective.

**Parameter Description:**

- `objective: String` - Planning objective, should be clear and specific for the LLM to understand

**Return Value:**

- `Agent` - Returns self, supports method chaining

#### setOnAgentStatusChangedListener()

```kotlin
open fun setOnAgentStatusChangedListener(listener: OnAgentStatusChangedListener): Agent
```

Sets the Agent status change listener.

**Parameter Description:**

- `listener: OnAgentStatusChangedListener` - Status change listener

**Return Value:**

- `Agent` - Returns self, supports method chaining

#### setOnTranscribeListener()

```kotlin
open fun setOnTranscribeListener(listener: OnTranscribeListener): Agent
```

Sets the TTS and ASR recognition result listener.

**Parameter Description:**

- `listener: OnTranscribeListener` - Transcription result listener

**Return Value:**

- `Agent` - Returns self, supports method chaining

#### setOnActionStatusChangedListener()

```kotlin
open fun setOnActionStatusChangedListener(listener: OnActionStatusChangedListener): Agent
```

Sets the system Action status change listener.

**Parameter Description:**

- `listener: OnActionStatusChangedListener` - System Action status change listener

**Return Value:**

- `Agent` - Returns self, supports method chaining

#### removeAction()

```kotlin
fun removeAction(name: String): Action?
```

Removes an Action.

**Parameter Description:**

- `name: String` - Action name

**Return Value:**

- `Action?` - Removed Action, returns null if not exists

**Note:** If removing Action after application or page initialization, Agent may need to be re-initialized.

#### getAction()

```kotlin
fun getAction(name: String): Action?
```

Gets an Action.

**Parameter Description:**

- `name: String` - Action full name

**Return Value:**

- `Action?` - Corresponding Action, returns null if not exists

#### registerActionNames()

```kotlin
open fun registerActionNames(actionNames: List<String>): Agent
```

Batch registers external Action names.

**Parameter Description:**

- `actionNames: List<String>` - List of external Action names

**Return Value:**

- `Agent` - Returns self, supports method chaining

#### registerAction()

```kotlin
open fun registerAction(action: Action): Agent
open fun registerAction(actionName: String): Agent
```

Registers an Action.

**Parameter Description:**

- `action: Action` - Action object to register
- `actionName: String` - External Action name (overloaded method)

**Return Value:**

- `Agent` - Returns self, supports method chaining

#### registerActions()

```kotlin
open fun registerActions(actionList: List<Action>): Agent
```

Batch registers Actions.

**Parameter Description:**

- `actionList: List<Action>` - Action list

**Return Value:**

- `Agent` - Returns self, supports method chaining

---

## Listener Interfaces

### OnTranscribeListener

ASR and TTS result listener interface, used to get speech recognition and speech synthesis results.

**Package Path:** `com.ainirobot.agent.OnTranscribeListener`

**Methods:**

#### onASRResult()

```kotlin
fun onASRResult(transcription: Transcription): Boolean
```

ASR recognition result callback.

**Parameter Description:**

- `transcription: Transcription` - Transcription result object

**Return Value:**

- `Boolean` - true indicates consuming this result, system will no longer display subtitles; false indicates no effect on subsequent processing

#### onTTSResult()

```kotlin
fun onTTSResult(transcription: Transcription): Boolean
```

TTS playback result callback.

**Parameter Description:**

- `transcription: Transcription` - Transcription result object

**Return Value:**

- `Boolean` - true indicates consuming this result, system will no longer display subtitles; false indicates no effect on subsequent processing

---

### OnAgentStatusChangedListener

Agent status change listener interface, used to monitor Agent's running status.

**Package Path:** `com.ainirobot.agent.OnAgentStatusChangedListener`

**Methods:**

#### onStatusChanged()

```kotlin
fun onStatusChanged(status: String, message: String?): Boolean
```

Agent status change callback.

**Parameter Description:**

- `status: String` - Status value, includes: listening (listening), thinking (thinking), processing (processing), reset_status (status reset)
- `message: String?` - Status message, may have value when status is processing, e.g.: "Selecting tool...", "Getting weather...", etc.

**Return Value:**

- `Boolean` - true indicates not wanting to display status on default voice bar; false indicates keeping system display status UI

---

### OnActionStatusChangedListener

System Action status change listener interface, used to monitor execution status changes of system built-in Actions.

**Package Path:** `com.ainirobot.agent.OnActionStatusChangedListener`

**Methods:**

#### onStatusChanged()

```kotlin
fun onStatusChanged(actionName: String?, status: String?, message: String?): Boolean
```

System Action status change callback.

**Parameter Description:**

- `actionName: String?` - System Action name, can be null
- `status: String?` - Action execution status, includes: succeeded (success), failed (failed), timeout (timeout), interrupted (interrupted), recalled (recalled), unsupported (unsupported)
- `message: String?` - Status related message information, can be null

**Return Value:**

- `Boolean` - true indicates consuming this status change event; false indicates not consuming, continue passing to other listeners

**Important Notes:**

- Only monitors status changes of system built-in Actions
- Does not include custom Actions by secondary developers
- Callback executes in child thread
- Requires SDK v0.4.4 and later versions
- Event passing: When PageAgent returns false, AppAgent can also receive callback

---

### TTSCallback

TTS playback callback interface, inherits from ITaskCallback<String>.

**Package Path:** `com.ainirobot.agent.TTSCallback`

**Interface Definition:**

```kotlin
interface TTSCallback : ITaskCallback<String>
```

### LLMCallback

LLM call callback interface, inherits from ITaskCallback<LLMResponse>.

**Package Path:** `com.ainirobot.agent.LLMCallback`

**Interface Definition:**

```kotlin
interface LLMCallback : ITaskCallback<LLMResponse>
```

### ITaskCallback

Task execution callback interface, a generic sealed interface.

**Package Path:** `com.ainirobot.agent.ITaskCallback`

**Interface Definition:**

```kotlin
sealed interface ITaskCallback<T> {
    fun onTaskEnd(status: Int, result: T?)
}
```

**Method Description:**

#### onTaskEnd()

```kotlin
fun onTaskEnd(status: Int, result: T?)
```

Task execution complete callback.

**Parameter Description:**

- `status: Int` - Execution status, 1 indicates success, 2 indicates failure
- `result: T?` - Execution result, can be null

---

## Data Classes

### Transcription

Voice transcription result class, contains ASR recognition and TTS playback result information.

**Package Path:** `com.ainirobot.agent.base.Transcription`

**Constructor:**

```kotlin
Transcription(
    sid: String,
    text: String,
    speaker: String,
    final: Boolean,
    error: String,
    extra: Bundle? = null
)
```

**Properties:**

#### sid

```kotlin
val sid: String
```

Session ID.

#### text

```kotlin
val text: String
```

Text content.

#### speaker

```kotlin
val speaker: String
```

Speaker identifier.

#### final

```kotlin
val final: Boolean
```

Determines whether it's streaming result or final result, true is final result, false is intermediate result.

#### error

```kotlin
val error: String
```

Error message.

#### extra

```kotlin
val extra: Bundle?
```

Extra information, can be null.

#### isUserSpeaking

```kotlin
val isUserSpeaking: Boolean
```

Determines whether it's ASR or TTS content, true is ASR result (speaker == "human_user"), false is TTS result.

---

### LLMMessage

LLM message class, encapsulates message content for interaction with LLM.

**Package Path:** `com.ainirobot.agent.base.llm.LLMMessage`

**Constructor:**

```kotlin
LLMMessage(role: Role, content: String)
```

**Parameter Description:**

- `role: Role` - Message role
- `content: String` - Message content

**Properties:**

#### role

```kotlin
val role: Role
```

Message role.

#### content

```kotlin
val content: String
```

Message content.

---

### LLMConfig

LLM configuration class, used to configure LLM parameters and settings.

**Package Path:** `com.ainirobot.agent.base.llm.LLMConfig`

**Constructor:**

```kotlin
LLMConfig(
    temperature: Float = 1.0f,
    maxTokens: Int? = null,
    timeout: Int = 6,
    fileSearch: Boolean = false,
    businessInfo: String? = null
)
```

**Properties:**

#### temperature

```kotlin
val temperature: Float
```

Temperature parameter, controls randomness of generated text, default 1.0f.

#### maxTokens

```kotlin
val maxTokens: Int?
```

Maximum token count, can be null.

#### timeout

```kotlin
val timeout: Int
```

Timeout (seconds), default 6 seconds.

#### fileSearch

```kotlin
val fileSearch: Boolean
```

Whether to enable file search, default false.

#### businessInfo

```kotlin
val businessInfo: String?
```

Business information, can be null.

---

### LLMResponse

LLM response result class, contains complete response information from LLM call.

**Package Path:** `com.ainirobot.agent.assit.LLMResponse`

**Properties:**

#### tokenCost

```kotlin
val tokenCost: TokenCost
```

Token consumption statistics.

#### elapsedTime

```kotlin
val elapsedTime: Float
```

Request elapsed time (seconds).

#### message

```kotlin
val message: LLMMessage
```

Returned message content.

#### status

```kotlin
val status: String
```

Execution status, "succeeded" indicates success, "failed" indicates failure.

#### error

```kotlin
val error: String
```

Error message, contains specific error description when status is "failed".

---

### TokenCost

Token consumption statistics class, used to record Token usage from LLM calls.

**Package Path:** `com.ainirobot.agent.assit.TokenCost`

**Constructor:**

```kotlin
TokenCost(
    promptTokens: Int,
    completionTokens: Int,
    totalTokens: Int
)
```

**Properties:**

#### promptTokens

```kotlin
val promptTokens: Int
```

Input prompt Token count.

#### completionTokens

```kotlin
val completionTokens: Int
```

Completion reply Token count.

#### totalTokens

```kotlin
val totalTokens: Int
```

Total Token count.

---

### ActionResult

Action execution result class, encapsulates Action execution status and result information.

**Package Path:** `com.ainirobot.agent.base.ActionResult`

**Constructor:**

```kotlin
ActionResult(
    status: ActionStatus,
    result: Bundle? = null,
    extra: Bundle? = null,
    sid: String = "",
    appId: String = ""
)
```

**Parameter Description:**

- `status: ActionStatus` - Action execution status
- `result: Bundle?` - Execution result data, can be null
- `extra: Bundle?` - Extra information, can be null
- `sid: String` - Session ID, default empty string
- `appId: String` - Application ID, default empty string

**Properties:**

#### status

```kotlin
val status: ActionStatus
```

Action execution status.

#### result

```kotlin
val result: Bundle?
```

Execution result data.

#### extra

```kotlin
val extra: Bundle?
```

Extra information.

#### sid

```kotlin
var sid: String
```

Session ID.

#### appId

```kotlin
var appId: String
```

Application ID.

---

### TaskResult

Task execution result class, generic class.

**Package Path:** `com.ainirobot.agent.TaskResult`

**Constructor:**

```kotlin
TaskResult(status: Int, result: T? = null)
```

**Parameter Description:**

- `status: Int` - Execution status, 1 indicates success, 2 indicates failure
- `result: T?` - Execution result, can be null

**Properties:**

#### status

```kotlin
val status: Int
```

Execution status.

#### result

```kotlin
val result: T?
```

Execution result.

#### isSuccess

```kotlin
val isSuccess: Boolean
```

Whether execution succeeded, returns true when status=1.

---

## Enumeration Classes

### Role

Message role enumeration, used for LLM message role identification.

**Package Path:** `com.ainirobot.agent.base.llm.Role`

**Enum Values:**

#### USER

User role.

#### ASSISTANT

Assistant role.

#### SYSTEM

System role.

---

### ActionStatus

Action execution status enumeration.

**Package Path:** `com.ainirobot.agent.base.ActionStatus`

**Enum Values:**

#### SUCCEEDED

Execution succeeded.

#### FAILED

Execution failed.

#### INTERRUPTED

Execution interrupted.

#### RECALLED

Repeated planning caused current action to be interrupted.

---

## Annotation Classes

### AgentAction

Action annotation, used to mark member methods as Actions.

**Package Path:** `com.ainirobot.agent.annotations.AgentAction`

**Target:** `AnnotationTarget.FUNCTION`

**Properties:**

#### name

```kotlin
val name: String
```

Action name.

#### desc

```kotlin
val desc: String
```

Action description.

#### displayName

```kotlin
val displayName: String
```

Action display name.

**Usage Example:**

```kotlin
@AgentAction(
    name = "com.agent.demo.SHOW_SMILE_FACE",
    displayName = "Smile",
    desc = "Respond to user's happy, satisfied, or positive emotions"
)
private fun showSmileFace(action: Action, @ActionParameter(...) sentence: String): Boolean {
    // Implementation logic
    return true
}
```

---

### ActionParameter

Parameter annotation, used to mark Action method parameters.

**Package Path:** `com.ainirobot.agent.annotations.ActionParameter`

**Target:** `AnnotationTarget.VALUE_PARAMETER`

**Properties:**

#### name

```kotlin
val name: String
```

Parameter name.

#### desc

```kotlin
val desc: String
```

Parameter description.

#### required

```kotlin
val required: Boolean = true
```

Whether this is a required parameter, default true.

#### enumValues

```kotlin
val enumValues: Array<String> = []
```

Restrict parameter value to only select from specified values.

**Usage Example:**

```kotlin
@ActionParameter(
    name = "sentence",
    desc = "Reply to the user",
    required = true
)
sentence: String
```

---

## Utility Classes

### AOCoroutineScope

Agent coroutine scope, used to execute coroutine operations in Agent.

**Package Path:** `com.ainirobot.agent.coroutine.AOCoroutineScope`

**Methods:**

#### launch()

```kotlin
fun launch(block: suspend CoroutineScope.() -> Unit): Job
```

Launch coroutine.

**Parameter Description:**

- `block: suspend CoroutineScope.() -> Unit` - Coroutine code block

**Return Value:**

- `Job` - Coroutine job object

#### cancelAll()

```kotlin
fun cancelAll()
```

Cancel all coroutine tasks and close thread pool.

**Usage Example:**

```kotlin
AOCoroutineScope.launch {
    // Execute time-consuming operations in coroutine
    AgentCore.ttsSync("Hello")
    // Notify after completion
    action.notify()
}
```

---

## Important Notes

### Action Execution Considerations

1. **onExecute method cannot execute time-consuming operations**
2. **Time-consuming operations must be placed in coroutines or threads**
3. **Must call action.notify() method after execution completes**
4. **onExecute method executes in child thread by default**

### Lifecycle Management

1. **Only one AppAgent instance per app**
2. **Only one PageAgent instance per page**
3. **App-level Actions take effect while application is in foreground**
4. **Page-level Actions take effect while page is visible**

### Registration Methods

1. **Dynamic Registration**: Register in code, only for internal use within current application
2. **Static Registration**: Configure in actionRegistry.json, can be called externally

### Parameter Naming Conventions

1. **Parameter names use English, multiple words connected with underscores**
2. **Avoid names identical to Action or Parameter object properties**
3. **Provide clear parameter descriptions to help AI understand**
