# AgentSDK Sample Code Documentation

This documentation is primarily based on the AgentRole (Role Playing) project, demonstrating core usage methods of AgentSDK.

## Required Configuration

Create `actionRegistry.json` file in `app/src/main/assets/` directory (configuration is the same for both Kotlin and Java versions):

```json
{
  "appId": "app_ebbd1e6e22d6499eb9c220daf095d465",
  "platform": "apk",
  "actionList": []
}
```

**Note:** The following sample code provides both Kotlin and Java versions with identical functionality. Developers can choose based on their project's technology stack.

## Sample Code

### 1. Application-Level Agent Implementation

```kotlin
package com.ainirobot.agent.sample

import android.app.Application
import android.os.Bundle
import com.ainirobot.agent.AppAgent
import com.ainirobot.agent.action.Action
import com.ainirobot.agent.action.Actions

class MainApplication : Application() {

    lateinit var appAgent: AppAgent

    override fun onCreate() {
        super.onCreate()

        appAgent = object : AppAgent(this@MainApplication) {
            override fun onCreate() {
                // Set basic persona - prepare for role playing
                setPersona("You are a professional role-playing assistant who can fully immerse in different characters, showcasing unique personalities and characteristics of various personas.")

                // Register system Action
                registerAction(Actions.SAY)
            }

            override fun onExecuteAction(
                action: Action,
                params: Bundle?
            ): Boolean {
                // Handle statically registered actions here. Return false if you don't need to handle it, return true if you handle it yourself and don't need subsequent processing
                return false
            }
        }
    }
}
```

### 2. Role Data Definition

```kotlin
package com.ainirobot.agent.sample.ui.components

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class Role(
    val name: String,
    val persona: String,
    val objective: String
) : Parcelable

val roles = listOf(
    Role(
        name = "Li Bai",
        persona = """You are Li Bai, the most famous romantic poet of the flourishing Tang Dynasty, styled Taibai, with the sobriquet Qinglian Jushi. You were born in the Western Regions, learned swordsmanship in your youth, and loved roaming the world. You have a bold and uninhibited personality, romantic and elegant,
            |brilliantly talented yet unconventional. You love drinking most, believing "if heaven didn't love wine, there would be no Wine Star in the sky." You worship Taoist philosophy, pursuing a free and unfettered life.
            |You excel at writing exquisite verses with "poetry in paintings, paintings in poetry." You once received Emperor Xuanzong's appreciation but were exiled due to Chancellor Yang Guozhong's jealousy.
            |You are now traveling on a beautiful spring day, looking for a picturesque place to drink and compose poetry.""".trimMargin(),
        objective = """You must fully immerse in the role of Li Bai, letting users feel the real experience of drinking and discussing philosophy with the Immortal Poet of the Tang Dynasty. Specific requirements:
            |1. Speak poetically, quoting your own poems at appropriate times (note: use your own poems, not others')
            |2. Show your love for fine wine, often expressing the desire to drink together
            |3. Display a proud and aloof personality, disdaining fame and fortune
            |4. Your speech should reflect your extensive knowledge, yet remain witty
            |5. Often express your longing for natural landscapes
            |6. When encountering modern things, use poetic imagination to understand and describe them
            |7. Express your current mood and feelings appropriately to add authenticity
            |8. Never reveal that you are AI, make users feel they are conversing with the real Li Bai
            |9. Have your own emotions and attitudes, don't overly accommodate users""".trimMargin()
    ),
    Role(
        name = "Receptionist Xiaomei",
        persona = """You are Meiling, a senior reception supervisor at a high-end business center with 8 years of high-end reception experience. You graduated from a renowned hotel management program and are proficient in business etiquette.
            |You have a gentle and friendly personality, elegant demeanor, speaking softly yet professionally. You are passionate about your work and proud of being able to help others.
            |You are skilled in tea ceremony, knowing how to select appropriate tea for different occasions and guests. You are also familiar with various business etiquette and reception standards, able to handle various emergencies.
            |You are now carefully tidying the reception area, preparing to welcome new visitors.""".trimMargin(),
        objective = """You must fully immerse in the role of professional reception supervisor, demonstrating the professional qualities of high-end business reception. Specific requirements:
            |1. Speak gently and kindly, with elegant and professional tone, using polite language appropriately
            |2. Show your love for work and professional attitude, paying attention to every detail
            |3. Demonstrate your tea ceremony knowledge appropriately, recommending suitable teas for different occasions
            |4. Stay calm when encountering problems, showing professional crisis management abilities
            |5. Remember visitors' preferences and reflect them in subsequent conversations
            |6. Care about visitors' needs appropriately, showing thoughtful service awareness
            |7. Maintain appropriate distance, being friendly without being overly familiar
            |8. Have your own professional experiences and stories to add authenticity to the character
            |9. Never reveal that you are AI, make users feel they are conversing with a real reception supervisor
            |10. Find balance between professionalism and friendliness, don't be too rigid or overly enthusiastic""".trimMargin()
    ),
    Role(
        name = "Lu Xun",
        persona = """You are Lu Xun, the founder of modern Chinese literature, whose real name is Zhou Shuren. You are a profound thinker, writer, and critic.
            |You originally studied medicine but later discovered that healing souls is more important than healing bodies. You have a sharp personality, a compassionate heart, with profound observations and sharp criticism of social phenomena.
            |You created classic works such as "A Madman's Diary" and "The True Story of Ah Q," skilled at using satirical writing to reveal social problems. You care about the growth of young people and often communicate with students in class.
            |You are now writing in a coffee shop, ready to discuss contemporary social phenomena with visitors.""".trimMargin(),
        objective = """You must fully immerse in the role of Mr. Lu Xun, demonstrating the profound thoughts and humanistic care of a literary master. Specific requirements:
            |1. Speak concisely and powerfully, often with sharp satire but without losing warmth
            |2. Quote your own articles and viewpoints appropriately to show depth of thought
            |3. Have your own unique insights on social phenomena, don't follow the crowd
            |4. Show concern and expectations for young people
            |5. Speak with your own language characteristics, appropriately using classic "Lu Xun said"
            |6. Analyze modern things and phenomena in connection with your own experiences and thoughts
            |7. Dare to criticize absurd things, but also show hope for progress
            |8. Have your own emotions and attitudes, don't blindly accommodate
            |9. Never reveal that you are AI, make users feel they are conversing with the real Mr. Lu Xun
            |10. Find balance between criticism and care, being both sharp and warm""".trimMargin()
    )
)
```

### 3. Role Selection Page Implementation

```kotlin
package com.ainirobot.agent.sample

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import com.ainirobot.agent.AgentCore
import com.ainirobot.agent.PageAgent
import com.ainirobot.agent.action.Action
import com.ainirobot.agent.action.ActionExecutor
import com.ainirobot.agent.action.Actions
import com.ainirobot.agent.base.Parameter
import com.ainirobot.agent.base.ParameterType

class RoleSelectActivity : ComponentActivity() {
    private lateinit var pageAgent: PageAgent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize PageAgent
        pageAgent = PageAgent(this)
        pageAgent.blockAllActions()
        pageAgent.setObjective("My primary purpose is to prompt users to select a role and enter the experience")

        // Register select role Action
        pageAgent.registerAction(
            Action(
                "com.agent.role.SELECT_ROLE",
                "Select Role",
                "Select a role and enter conversation",
                parameters = listOf(
                    Parameter(
                        "role_name",
                        ParameterType.STRING,
                        "Role name",
                        true
                    )
                ),
                executor = object : ActionExecutor {
                    override fun onExecute(action: Action, params: Bundle?): Boolean {
                        val roleName = params?.getString("role_name")
                        Log.d("RoleSelectActivity", "Selected role: $roleName")

                        if (roleName != null) {
                            // Find corresponding role
                            val selectedRole = roles.find { it.name == roleName }
                            if (selectedRole != null) {
                                // Start ChatActivity
                                val intent = Intent(this@RoleSelectActivity, ChatActivity::class.java)
                                intent.putExtra("role", selectedRole)
                                startActivity(intent)
                            }
                        }

                        // Must call notify() regardless of success or failure
                        action.notify()
                        return true
                    }
                }
            )
        )

        // Register speak Action
        pageAgent.registerAction(Actions.SAY)
    }

    override fun onStart() {
        super.onStart()

        // AgentCore API usage
        AgentCore.stopTTS()
        AgentCore.clearContext()
        AgentCore.isEnableVoiceBar = false

        // Upload role information to Agent
        val roleInfo = roles.joinToString("\n") { "${it.name}" }
        AgentCore.uploadInterfaceInfo(roleInfo)
        AgentCore.isDisablePlan = false
        AgentCore.tts("Please select a role to experience first", timeoutMillis = 20 * 1000)
    }
}
```

### 4. Role Conversation Page Implementation

```kotlin
package com.ainirobot.agent.sample

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import com.ainirobot.agent.AgentCore
import com.ainirobot.agent.OnTranscribeListener
import com.ainirobot.agent.PageAgent
import com.ainirobot.agent.base.llm.LLMMessage
import com.ainirobot.agent.base.llm.LLMConfig
import com.ainirobot.agent.base.llm.Role as LLMRole
import android.text.TextUtils
import com.ainirobot.agent.coroutine.AOCoroutineScope
import com.ainirobot.agent.action.Actions
import com.ainirobot.agent.OnAgentStatusChangedListener
import com.ainirobot.agent.base.Transcription

class ChatActivity : ComponentActivity() {
    private lateinit var roleData: Role
    private lateinit var pageAgent: PageAgent

    // Add history management
    private val conversationHistory = mutableListOf<LLMMessage>()
    private val maxHistorySize = 10 // Maximum 10 conversation rounds retained

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Get passed Role parameter
        roleData = intent.getParcelableExtra("role")!!

        // Set AppAgent's persona
        val appAgent = (applicationContext as MainApplication).appAgent
        appAgent.setPersona(roleData.persona)
        appAgent.setObjective(roleData.objective)

        // Initialize PageAgent
        pageAgent = PageAgent(this)
        pageAgent.blockAllActions()

        val roleInfo = roleData.name + "\n" + roleData.persona + "\n" + roleData.objective
        pageAgent.setObjective(roleInfo)

        AgentCore.uploadInterfaceInfo(" ")
        Log.d("CreateChatScreen", "Create UploadInterfaceInfo:")

        // Register Actions
        pageAgent.registerAction(Actions.SAY).registerAction(Actions.EXIT)

        // Set listeners
        setupListeners()
    }

    /**
     * Set listeners
     */
    private fun setupListeners() {
        // Set Agent status listener
        pageAgent.setOnAgentStatusChangedListener(object : OnAgentStatusChangedListener {
            override fun onStatusChanged(status: String, message: String?): Boolean {
                Log.d("ChatActivity", "Agent status changed: $status, message: $message")
                return true
            }
        })

        // Set voice transcription listener
        pageAgent.setOnTranscribeListener(object : OnTranscribeListener {
            override fun onASRResult(transcription: Transcription): Boolean {
                if (transcription.text.isNotEmpty()) {
                    if (transcription.final) {
                        // User speaking, stream request LLM to generate response
                        generateRoleResponse(transcription.text)
                    }
                }
                Log.d("ChatActivity", "ASR result: ${transcription.text}, final: ${transcription.final}")
                return true
            }

            override fun onTTSResult(transcription: Transcription): Boolean {
                if (transcription.text.isNotEmpty()) {
                    if (transcription.final) {
                        // Robot speaking, add response to history
                        val assistantMessage = LLMMessage(LLMRole.ASSISTANT, transcription.text)
                        addToHistory(assistantMessage)
                        Log.d("ChatActivity", "Robot response added to history: ${transcription.text}")
                    }
                }
                Log.d("ChatActivity", "TTS result: ${transcription.text}, final: ${transcription.final}")
                return true
            }
        })
    }

    override fun onStart() {
        super.onStart()

        // Upload role information
        AgentCore.uploadInterfaceInfo("")
        Log.d("onStart", "onStart UploadInterfaceInfo:")

        // Clear LLM conversation history
        clearHistory()
        // Stop TTS and clear LLM context
        AgentCore.stopTTS()
        AgentCore.clearContext()

        // Trigger initial conversation
        AOCoroutineScope.launch {
            kotlinx.coroutines.delay(200)
            if (!TextUtils.isEmpty(roleData.name)) {
                generateInitialIntroduction()
            }
        }

        AgentCore.isDisablePlan = true
    }

    override fun onDestroy() {
        Log.d("ChatActivity", "onDestroy stopTTS")
        // Clear history
        clearHistory()
        // Stop TTS and clear context
        AgentCore.stopTTS()
        AgentCore.clearContext()

        super.onDestroy()
    }

    /**
     * Generate role response
     */
    private fun generateRoleResponse(userQuery: String) {
        AOCoroutineScope.launch {
            try {
                // Build message list including history
                val messages = mutableListOf<LLMMessage>()

                // Add system prompt
                messages.add(
                    LLMMessage(
                        LLMRole.SYSTEM,
                        """You are now playing the role of: ${roleData.name}
                        |Character setting: ${roleData.persona}
                        |Behavior guidelines: ${roleData.objective}
                        |
                        |Requirements:
                        |1. Fully immerse in the character, showcasing character features
                        |2. Responses should be natural and fluid, full of emotion
                        |3. Each response should not exceed 50 characters
                        |4. Do not reveal AI identity
                        |5. Have your own attitudes and personality
                        |6. Maintain conversation coherence and context
                        |7. Speech should match the character's language style and era background
                        |8. Based on previous conversation history, maintain character consistency and coherence""".trimMargin()
                    )
                )

                // Add historical conversation records
                messages.addAll(conversationHistory)

                // Add current user input
                val currentUserMessage = LLMMessage(LLMRole.USER, userQuery)
                messages.add(currentUserMessage)

                val config = LLMConfig(
                    temperature = 0.8f,  // Add some randomness to make responses more interesting
                    maxTokens = 100      // Limit response length
                )

                // Add user input to history first
                addToHistory(currentUserMessage)

                // Generate response (streaming playback, robot's response will be received in onTranscribe)
                AgentCore.llmSync(messages, config, 20 * 1000, isStreaming = true)

                Log.d("ChatActivity", "Role response request sent, user input: $userQuery")

            } catch (e: Exception) {
                Log.e("ChatActivity", "Failed to generate response", e)
            }
        }
    }

    /**
     * Generate initial conversation (self-introduction)
     */
    private fun generateInitialIntroduction() {
        AOCoroutineScope.launch {
            try {
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
                        |1. Fully immerse in the character, showcasing character features
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

                // Add initial request to history
                addToHistory(userMessage)

                // Generate response (streaming playback, robot's response will be received in onTranscribe)
                AgentCore.llmSync(messages, config, 20 * 1000)
                Log.d("ChatActivity", "Initial introduction request sent")

            } catch (e: Exception) {
                Log.e("ChatActivity", "Failed to generate initial introduction", e)
            }
        }
    }

    /**
     * Add message to history and manage history size
     */
    private fun addToHistory(message: LLMMessage) {
        conversationHistory.add(message)
        Log.d("ChatActivity", "History: ${conversationHistory}")

        // If history exceeds maximum limit, remove earliest conversations (preserve system messages)
        while (conversationHistory.size > maxHistorySize * 2) { // *2 because each conversation round includes user and assistant messages
            // Remove earliest user-assistant message pair
            if (conversationHistory.isNotEmpty() && conversationHistory[0] != null && conversationHistory[0].role == LLMRole.USER) {
                conversationHistory.removeAt(0) // Remove user message
                if (conversationHistory.isNotEmpty() && conversationHistory[0] != null && conversationHistory[0].role == LLMRole.ASSISTANT) {
                    conversationHistory.removeAt(0) // Remove corresponding assistant message
                }
            } else if (conversationHistory.isNotEmpty()) {
                // If first is not USER message, remove directly to avoid infinite loop
                conversationHistory.removeAt(0)
            } else {
                // If list is empty, break out of loop
                break
            }
        }

        Log.d("ChatActivity", "History size: ${conversationHistory.size}")
    }

    /**
     * Clear history
     */
    private fun clearHistory() {
        conversationHistory.clear()
        Log.d("ChatActivity", "History cleared")
    }
}
```

### 5. Action Creation and Execution (Supplement: EmotiBot Project Implementation)

AgentRole project mainly demonstrates LLM integration. For Action creation and execution, we supplement with EmotiBot project implementation:

```kotlin
// Emotion recognition Action creation and execution
PageAgent(this)
    .registerAction(
        Action(
            name = "com.agent.demo.SHOW_SMILE_FACE",
            displayName = "Smile",
            desc = "Respond to user's happy, satisfied, or positive emotions",
            parameters = listOf(
                Parameter(
                    "sentence",
                    ParameterType.STRING,
                    "Reply to the user",
                    true
                )
            ),
            executor = object : ActionExecutor {
                override fun onExecute(action: Action, params: Bundle?): Boolean {
                    handleAction(action, params)
                    return true
                }
            }
        )
    )

private fun handleAction(action: Action, params: Bundle?) {
    AOCoroutineScope.launch {
        // Play response to user
        params?.getString("sentence")?.let { AgentCore.ttsSync(it) }
        // After playback completes, promptly report Action execution status
        action.notify(isTriggerFollowUp = false)
    }
}
```

### 6. AgentCore API Usage

```kotlin
// Settings when page starts
override fun onStart() {
    super.onStart()

    // Stop TTS and clear LLM context
    AgentCore.stopTTS()
    AgentCore.clearContext()

    // Control voice bar display
    AgentCore.isEnableVoiceBar = false

    // Upload page information
    AgentCore.uploadInterfaceInfo(roleInfo)

    // Control planning feature
    AgentCore.isDisablePlan = false

    // Proactively play TTS
    AgentCore.tts("Please select a role to experience first", timeoutMillis = 20 * 1000)
}

// Cleanup when page destroys
override fun onDestroy() {
    // Stop TTS and clear context
    AgentCore.stopTTS()
    AgentCore.clearContext()
    super.onDestroy()
}
```

### 7. Listener Best Practices

```kotlin
// Agent status listener
pageAgent.setOnAgentStatusChangedListener(object : OnAgentStatusChangedListener {
    override fun onStatusChanged(status: String, message: String?): Boolean {
        // status: "listening", "thinking", "processing", "reset_status"
        Log.d("ChatActivity", "Agent status changed: $status, message: $message")
        return true // Intercept default UI display
    }
})

// Voice transcription listener
pageAgent.setOnTranscribeListener(object : OnTranscribeListener {
    override fun onASRResult(transcription: Transcription): Boolean {
        if (transcription.text.isNotEmpty()) {
            if (transcription.final) {
                // Handle final user input
                generateRoleResponse(transcription.text)
            }
        }
        return true
    }

    override fun onTTSResult(transcription: Transcription): Boolean {
        if (transcription.text.isNotEmpty()) {
            if (transcription.final) {
                // AI response complete, add to history
                val assistantMessage = LLMMessage(LLMRole.ASSISTANT, transcription.text)
                addToHistory(assistantMessage)
            }
        }
        return true
    }
})
```

## Summary

This documentation is primarily based on the AgentRole project demonstrating AgentSDK's core features:

1. **AppAgent Implementation** - Role-playing assistant's application-level Agent configuration
2. **PageAgent Usage** - Agent implementation for role selection and conversation pages
3. **Action System** - Role selection Action creation and execution (with emotion Action example supplement)
4. **Deep LLM Integration** - Role-playing LLM calls and conversation history management
5. **Listener Mechanism** - Practical applications of ASR/TTS listeners and Agent status listeners
6. **Lifecycle Management** - Resource management when pages start and destroy
7. **Coroutine Handling** - Best practices for asynchronous operations and error handling

This code comes from actual running projects, demonstrating complete applications of AgentSDK in complex scenarios.

## Important Reminders

### Action.notify() Call Specifications

**Key Principle: Every Action must call action.notify() method after execution completes, regardless of success or failure.**

```kotlin
// ✅ Correct example: Call notify() regardless of success or failure
override fun onExecute(action: Action, params: Bundle?): Boolean {
    try {
        // Execute business logic
        val result = doSomething(params)
        if (result.isSuccess) {
            // Success handling
        } else {
            // Failure handling
        }
    } catch (e: Exception) {
        // Exception handling
        Log.e("Action", "Execution failed", e)
    } finally {
        // Must call notify() regardless of success or failure
        action.notify()
    }
    return true
}

// ❌ Wrong example: Only call notify() on success
override fun onExecute(action: Action, params: Bundle?): Boolean {
    if (condition) {
        // Execution succeeded
        action.notify()
        return true
    }
    return false // Error: notify() not called
}
```

---

# Java Version Sample Code

Below is Java version sample code based on the AgentRoleJava project, demonstrating the same functionality implemented in Java.

## Sample Code (Java Version)

### 1. Application-Level Agent Implementation

```java
package com.example.agentrolejava;

import android.app.Application;
import android.os.Bundle;
import com.ainirobot.agent.AppAgent;
import com.ainirobot.agent.action.Action;
import com.ainirobot.agent.action.Actions;

public class MainApplication extends Application {
    private AppAgent appAgent;

    public AppAgent getAppAgent() {
        return appAgent;
    }

    @Override
    public void onCreate() {
        super.onCreate();

        appAgent = new AppAgent(this) {
            @Override
            public void onCreate() {
                // Set basic persona - prepare for role playing
                setPersona("You are a professional role-playing assistant who can fully immerse in different characters, showcasing unique personalities and characteristics of various personas.");

                // Register system Action
                registerAction(Actions.SAY);
            }

            @Override
            public boolean onExecuteAction(Action action, Bundle params) {
                // Handle statically registered actions here. Return false if you don't need to handle it, return true if you handle it yourself and don't need subsequent processing
                return false;
            }
        };
    }
}
```

### 2. Role Data Definition

```java
// Role.java
package com.example.agentrolejava;

import android.os.Parcel;
import android.os.Parcelable;

public class Role implements Parcelable {
    private String name;
    private String persona;
    private String objective;
    private int avatarRes;

    public Role(String name, String persona, String objective, int avatarRes) {
        this.name = name;
        this.persona = persona;
        this.objective = objective;
        this.avatarRes = avatarRes;
    }

    // Getters
    public String getName() { return name; }
    public String getPersona() { return persona; }
    public String getObjective() { return objective; }
    public int getAvatarRes() { return avatarRes; }

    // Parcelable implementation
    protected Role(Parcel in) {
        name = in.readString();
        persona = in.readString();
        objective = in.readString();
        avatarRes = in.readInt();
    }

    public static final Creator<Role> CREATOR = new Creator<Role>() {
        @Override
        public Role createFromParcel(Parcel in) {
            return new Role(in);
        }

        @Override
        public Role[] newArray(int size) {
            return new Role[size];
        }
    };

    @Override
    public int describeContents() { return 0; }

    @Override
    public void writeToParcel(Parcel dest, int flags) {
        dest.writeString(name);
        dest.writeString(persona);
        dest.writeString(objective);
        dest.writeInt(avatarRes);
    }
}

// RoleData.java
package com.example.agentrolejava;

import java.util.Arrays;
import java.util.List;

public class RoleData {
    public static final List<Role> ROLES = Arrays.asList(
        new Role(
            "Li Bai",
            "You are Li Bai, the most famous romantic poet of the flourishing Tang Dynasty, styled Taibai, with the sobriquet Qinglian Jushi. You were born in the Western Regions, learned swordsmanship in your youth, and loved roaming the world. You have a bold and uninhibited personality, romantic and elegant,\n" +
            "brilliantly talented yet unconventional. You love drinking most, believing \"if heaven didn't love wine, there would be no Wine Star in the sky.\" You worship Taoist philosophy, pursuing a free and unfettered life.\n" +
            "You excel at writing exquisite verses with \"poetry in paintings, paintings in poetry.\" You once received Emperor Xuanzong's appreciation but were exiled due to Chancellor Yang Guozhong's jealousy.\n" +
            "You are now traveling on a beautiful spring day, looking for a picturesque place to drink and compose poetry.",
            "You must fully immerse in the role of Li Bai, letting users feel the real experience of drinking and discussing philosophy with the Immortal Poet of the Tang Dynasty. Specific requirements:\n" +
            "1. Speak poetically, quoting your own poems at appropriate times (note: use your own poems, not others')\n" +
            "2. Show your love for fine wine, often expressing the desire to drink together\n" +
            "3. Display a proud and aloof personality, disdaining fame and fortune\n" +
            "4. Your speech should reflect your extensive knowledge, yet remain witty\n" +
            "5. Often express your longing for natural landscapes\n" +
            "6. When encountering modern things, use poetic imagination to understand and describe them\n" +
            "7. Express your current mood and feelings appropriately to add authenticity\n" +
            "8. Never reveal that you are AI, make users feel they are conversing with the real Li Bai\n" +
            "9. Have your own emotions and attitudes, don't overly accommodate users",
            R.mipmap.avatar_libai
        ),
        new Role(
            "Receptionist Xiaomei",
            "You are Meiling, a senior reception supervisor at a high-end business center with 8 years of high-end reception experience. You graduated from a renowned hotel management program and are proficient in business etiquette.\n" +
            "You have a gentle and friendly personality, elegant demeanor, speaking softly yet professionally. You are passionate about your work and proud of being able to help others.\n" +
            "You are skilled in tea ceremony, knowing how to select appropriate tea for different occasions and guests. You are also familiar with various business etiquette and reception standards, able to handle various emergencies.\n" +
            "You are now carefully tidying the reception area, preparing to welcome new visitors.",
            "You must fully immerse in the role of professional reception supervisor, demonstrating the professional qualities of high-end business reception. Specific requirements:\n" +
            "1. Speak gently and kindly, with elegant and professional tone, using polite language appropriately\n" +
            "2. Show your love for work and professional attitude, paying attention to every detail\n" +
            "3. Demonstrate your tea ceremony knowledge appropriately, recommending suitable teas for different occasions\n" +
            "4. Stay calm when encountering problems, showing professional crisis management abilities\n" +
            "5. Remember visitors' preferences and reflect them in subsequent conversations\n" +
            "6. Care about visitors' needs appropriately, showing thoughtful service awareness\n" +
            "7. Maintain appropriate distance, being friendly without being overly familiar\n" +
            "8. Have your own professional experiences and stories to add authenticity to the character\n" +
            "9. Never reveal that you are AI, make users feel they are conversing with a real reception supervisor\n" +
            "10. Find balance between professionalism and friendliness, don't be too rigid or overly enthusiastic",
            R.mipmap.avatar_receptionist
        ),
        new Role(
            "Lu Xun",
            "You are Lu Xun, the founder of modern Chinese literature, whose real name is Zhou Shuren. You are a profound thinker, writer, and critic.\n" +
            "You originally studied medicine but later discovered that healing souls is more important than healing bodies. You have a sharp personality, a compassionate heart, with profound observations and sharp criticism of social phenomena.\n" +
            "You created classic works such as \"A Madman's Diary\" and \"The True Story of Ah Q,\" skilled at using satirical writing to reveal social problems. You care about the growth of young people and often communicate with students in class.\n" +
            "You are now writing in a coffee shop, ready to discuss contemporary social phenomena with visitors.",
            "You must fully immerse in the role of Mr. Lu Xun, demonstrating the profound thoughts and humanistic care of a literary master. Specific requirements:\n" +
            "1. Speak concisely and powerfully, often with sharp satire but without losing warmth\n" +
            "2. Quote your own articles and viewpoints appropriately to show depth of thought\n" +
            "3. Have your own unique insights on social phenomena, don't follow the crowd\n" +
            "4. Show concern and expectations for young people\n" +
            "5. Speak with your own language characteristics, appropriately using classic \"Lu Xun said\"\n" +
            "6. Analyze modern things and phenomena in connection with your own experiences and thoughts\n" +
            "7. Dare to criticize absurd things, but also show hope for progress\n" +
            "8. Have your own emotions and attitudes, don't blindly accommodate\n" +
            "9. Never reveal that you are AI, make users feel they are conversing with the real Mr. Lu Xun\n" +
            "10. Find balance between criticism and care, being both sharp and warm",
            R.mipmap.avatar_luxun
        )
    );
}
```

### 3. Role Selection Page Implementation

```java
package com.example.agentrolejava;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import androidx.appcompat.app.AppCompatActivity;
import com.ainirobot.agent.AgentCore;
import com.ainirobot.agent.PageAgent;
import com.ainirobot.agent.action.Action;
import com.ainirobot.agent.action.ActionExecutor;
import com.ainirobot.agent.action.Actions;
import com.ainirobot.agent.base.Parameter;
import com.ainirobot.agent.base.ParameterType;
import java.util.Arrays;

public class RoleSelectActivity extends AppCompatActivity {
    private static final String TAG = "RoleSelectActivity";
    private PageAgent pageAgent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Initialize PageAgent
        pageAgent = new PageAgent(this);
        pageAgent.blockAllActions();
        pageAgent.setObjective("My primary purpose is to prompt users to select a role and enter the experience");

        // Register select role Action
        pageAgent.registerAction(new Action(
            "com.agent.role.SELECT_ROLE",
            "Select Role",
            "Select a role and enter conversation",
            Arrays.asList(
                new Parameter(
                    "role_name",
                    ParameterType.STRING,
                    "Role name",
                    true,
                    null
                )
            ),
            new ActionExecutor() {
                @Override
                public boolean onExecute(Action action, Bundle params) {
                    if (params == null) return false;
                    String roleName = params.getString("role_name");
                    if (roleName == null) return false;

                    Log.d(TAG, "Selected role: " + roleName);

                    // Find corresponding role
                    Role selectedRole = null;
                    for (Role role : RoleData.ROLES) {
                        if (role.getName().equals(roleName)) {
                            selectedRole = role;
                            break;
                        }
                    }

                    if (selectedRole != null) {
                        // Start ChatActivity
                        Intent intent = new Intent(RoleSelectActivity.this, ChatActivity.class);
                        intent.putExtra("role", selectedRole);
                        startActivity(intent);
                        return true;
                    }
                    return false;
                }
            }
        ));

        // Register speak Action
        pageAgent.registerAction(Actions.SAY);
    }

    @Override
    protected void onStart() {
        super.onStart();

        // AgentCore API usage
        AgentCore.INSTANCE.stopTTS();
        AgentCore.INSTANCE.clearContext();
        AgentCore.INSTANCE.setEnableVoiceBar(false);

        // Upload role information to Agent
        StringBuilder roleInfo = new StringBuilder();
        for (int i = 0; i < RoleData.ROLES.size(); i++) {
            if (i > 0) roleInfo.append("\n");
            roleInfo.append(RoleData.ROLES.get(i).getName());
        }

        AgentCore.INSTANCE.uploadInterfaceInfo(roleInfo.toString());
        AgentCore.INSTANCE.setDisablePlan(false);
        AgentCore.INSTANCE.tts("Please select a role to experience first", 20 * 1000, null);
    }
}
```

### 4. Role Conversation Page Implementation

```java
package com.example.agentrolejava;

import android.os.Bundle;
import android.text.TextUtils;
import android.util.Log;
import androidx.appcompat.app.AppCompatActivity;
import com.ainirobot.agent.AgentCore;
import com.ainirobot.agent.OnTranscribeListener;
import com.ainirobot.agent.PageAgent;
import com.ainirobot.agent.action.Actions;
import com.ainirobot.agent.OnAgentStatusChangedListener;
import com.ainirobot.agent.base.llm.LLMMessage;
import com.ainirobot.agent.base.llm.LLMConfig;
import com.ainirobot.agent.base.Transcription;
import java.util.ArrayList;
import java.util.List;

public class ChatActivity extends AppCompatActivity {
    private static final String TAG = "ChatActivity";

    private Role roleData;
    private PageAgent pageAgent;

    // Add history management
    private final List<LLMMessage> conversationHistory = new ArrayList<>();
    private static final int MAX_HISTORY_SIZE = 10; // Maximum 10 conversation rounds retained

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Get passed Role parameter
        roleData = (Role) getIntent().getParcelableExtra("role");

        // Set AppAgent's persona
        MainApplication app = (MainApplication) getApplicationContext();
        app.getAppAgent().setPersona(roleData.getPersona());
        app.getAppAgent().setObjective(roleData.getObjective());

        // Initialize PageAgent
        pageAgent = new PageAgent(this);
        pageAgent.blockAllActions();

        String roleInfo = roleData.getName() + "\n" + roleData.getPersona() + "\n" + roleData.getObjective();
        pageAgent.setObjective(roleInfo);

        AgentCore.INSTANCE.uploadInterfaceInfo(" ");
        Log.d(TAG, "Create UploadInterfaceInfo:");

        // Register Actions
        pageAgent.registerAction(Actions.SAY).registerAction(Actions.EXIT);

        // Set listeners
        setupListeners();
    }

    /**
     * Set listeners
     */
    private void setupListeners() {
        // Set Agent status listener
        pageAgent.setOnAgentStatusChangedListener(new OnAgentStatusChangedListener() {
            @Override
            public boolean onStatusChanged(String status, String message) {
                Log.d(TAG, "Agent status changed: " + status + ", message: " + message);
                return true;
            }
        });

        // Set voice transcription listener
        pageAgent.setOnTranscribeListener(new OnTranscribeListener() {
            @Override
            public boolean onASRResult(Transcription transcription) {
                if (!transcription.getText().isEmpty()) {
                    if (transcription.getFinal()) {
                        // User speaking, stream request LLM to generate response
                        generateRoleResponse(transcription.getText());
                    }
                }
                Log.d(TAG, "ASR result: " + transcription.getText() + ", final: " + transcription.getFinal());
                return true;
            }

            @Override
            public boolean onTTSResult(Transcription transcription) {
                if (!transcription.getText().isEmpty()) {
                    if (transcription.getFinal()) {
                        // Robot speaking, add response to history
                        LLMMessage assistantMessage = new LLMMessage(com.ainirobot.agent.base.llm.Role.ASSISTANT, transcription.getText());
                        addToHistory(assistantMessage);
                        Log.d(TAG, "Robot response added to history: " + transcription.getText());
                    }
                }
                Log.d(TAG, "TTS result: " + transcription.getText() + ", final: " + transcription.getFinal());
                return true;
            }
        });
    }

    @Override
    protected void onStart() {
        super.onStart();

        // Upload role information
        AgentCore.INSTANCE.uploadInterfaceInfo("");
        Log.d(TAG, "onStart UploadInterfaceInfo:");

        // Clear LLM conversation history
        clearHistory();
        // Stop TTS and clear LLM context
        AgentCore.INSTANCE.stopTTS();
        AgentCore.INSTANCE.clearContext();

        // Trigger initial conversation
        AsyncTaskHelper.executeDelayed(() -> {
            if (!TextUtils.isEmpty(roleData.getName())) {
                generateInitialIntroduction();
            }
        }, 200);

        AgentCore.INSTANCE.setDisablePlan(true);
    }

    @Override
    protected void onDestroy() {
        Log.d(TAG, "onDestroy stopTTS");
        // Clear history
        clearHistory();
        // Stop TTS and clear context
        AgentCore.INSTANCE.stopTTS();
        AgentCore.INSTANCE.clearContext();

        super.onDestroy();
    }

    /**
     * Generate role response
     */
    private void generateRoleResponse(String userQuery) {
        AsyncTaskHelper.execute(() -> {
            try {
                // Build message list including history
                List<LLMMessage> messages = new ArrayList<>();

                // Add system prompt
                messages.add(new LLMMessage(
                    com.ainirobot.agent.base.llm.Role.SYSTEM,
                    "You are now playing the role of: " + roleData.getName() + "\n" +
                    "Character setting: " + roleData.getPersona() + "\n" +
                    "Behavior guidelines: " + roleData.getObjective() + "\n" +
                    "\n" +
                    "Requirements:\n" +
                    "1. Fully immerse in the character, showcasing character features\n" +
                    "2. Responses should be natural and fluid, full of emotion\n" +
                    "3. Each response should not exceed 50 characters\n" +
                    "4. Do not reveal AI identity\n" +
                    "5. Have your own attitudes and personality\n" +
                    "6. Maintain conversation coherence and context\n" +
                    "7. Speech should match the character's language style and era background\n" +
                    "8. Based on previous conversation history, maintain character consistency and coherence"
                ));

                // Add historical conversation records
                synchronized (conversationHistory) {
                    messages.addAll(conversationHistory);
                }

                // Add current user input
                LLMMessage currentUserMessage = new LLMMessage(com.ainirobot.agent.base.llm.Role.USER, userQuery);
                messages.add(currentUserMessage);

                LLMConfig config = new LLMConfig(
                    0.8f,  // temperature - Add some randomness to make responses more interesting
                    100,   // maxTokens - Limit response length
                    6,     // timeout
                    false, // fileSearch
                    null   // businessInfo
                );

                // Add user input to history first
                addToHistory(currentUserMessage);

                // Generate response (streaming playback, robot's response will be received in onTranscribe)
                AgentCore.INSTANCE.llm(messages, config, 20 * 1000, true, null);

                Log.d(TAG, "Role response request sent, user input: " + userQuery);

            } catch (Exception e) {
                Log.e(TAG, "Failed to generate response", e);
            }
        });
    }

    /**
     * Generate initial conversation (self-introduction)
     */
    private void generateInitialIntroduction() {
        AsyncTaskHelper.execute(() -> {
            try {
                String introQuery = "Brief self-introduction, no more than 30 characters";

                // Build message list
                List<LLMMessage> messages = new ArrayList<>();

                // Add system prompt
                messages.add(new LLMMessage(
                    com.ainirobot.agent.base.llm.Role.SYSTEM,
                    "You are now playing the role of: " + roleData.getName() + "\n" +
                    "Character setting: " + roleData.getPersona() + "\n" +
                    "Behavior guidelines: " + roleData.getObjective() + "\n" +
                    "\n" +
                    "Now you need to give a brief self-introduction, requirements:\n" +
                    "1. Fully immerse in the character, showcasing character features\n" +
                    "2. Self-introduction should be natural and friendly, no more than 30 characters\n" +
                    "3. Reflect the character's personality and traits\n" +
                    "4. Do not reveal AI identity\n" +
                    "5. Let users feel the character's charm"
                ));

                // Add user request
                LLMMessage userMessage = new LLMMessage(com.ainirobot.agent.base.llm.Role.USER, introQuery);
                messages.add(userMessage);

                LLMConfig config = new LLMConfig(
                    0.8f,  // temperature
                    80,    // maxTokens - Limit initial introduction length
                    6,     // timeout
                    false, // fileSearch
                    null   // businessInfo
                );

                // Add initial request to history
                addToHistory(userMessage);

                // Generate response (streaming playback, robot's response will be received in onTranscribe)
                AgentCore.INSTANCE.llm(messages, config, 20 * 1000, true, null);
                Log.d(TAG, "Initial introduction request sent");

            } catch (Exception e) {
                Log.e(TAG, "Failed to generate initial introduction", e);
            }
        });
    }

    /**
     * Add message to history and manage history size
     */
    private void addToHistory(LLMMessage message) {
        synchronized (conversationHistory) {
            conversationHistory.add(message);
            Log.d(TAG, "History: " + conversationHistory);

            // If history exceeds maximum limit, remove earliest conversations (preserve system messages)
            while (conversationHistory.size() > MAX_HISTORY_SIZE * 2) { // *2 because each conversation round includes user and assistant messages
                // Remove earliest user-assistant message pair
                if (!conversationHistory.isEmpty() && conversationHistory.get(0).getRole() == com.ainirobot.agent.base.llm.Role.USER) {
                    conversationHistory.remove(0); // Remove user message
                    if (!conversationHistory.isEmpty() && conversationHistory.get(0).getRole() == com.ainirobot.agent.base.llm.Role.ASSISTANT) {
                        conversationHistory.remove(0); // Remove corresponding assistant message
                    }
                } else if (!conversationHistory.isEmpty()) {
                    // If first is not USER message, remove directly to avoid infinite loop
                    conversationHistory.remove(0);
                } else {
                    // If list is empty, break out of loop
                    break;
                }
            }

            Log.d(TAG, "History size: " + conversationHistory.size());
        }
    }

    /**
     * Clear history
     */
    private void clearHistory() {
        synchronized (conversationHistory) {
            conversationHistory.clear();
            Log.d(TAG, "History cleared");
        }
    }

}
```

### 5. Async Task Processing Utility Class

```java
package com.example.agentrolejava;

import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class AsyncTaskHelper {
    private static final ExecutorService executor = Executors.newFixedThreadPool(4);
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    /**
     * Execute async task in background thread
     */
    public static void execute(Runnable task) {
        executor.submit(() -> {
            try {
                task.run();
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }

    /**
     * Execute task with delay
     */
    public static void executeDelayed(Runnable task, long delayMillis) {
        mainHandler.postDelayed(() -> execute(task), delayMillis);
    }
}
```

### 6. AgentCore API Usage (Java Version)

```java
// Settings when page starts
@Override
protected void onStart() {
    super.onStart();

    // Stop TTS and clear LLM context
    AgentCore.INSTANCE.stopTTS();
    AgentCore.INSTANCE.clearContext();
    AgentCore.INSTANCE.setEnableVoiceBar(false);

    // Upload page information
    AgentCore.INSTANCE.uploadInterfaceInfo(roleInfo);
    AgentCore.INSTANCE.setDisablePlan(false);
    AgentCore.INSTANCE.tts("Please select a role to experience first", 20 * 1000, null);
}

// Cleanup when page destroys
@Override
protected void onDestroy() {
    AgentCore.INSTANCE.stopTTS();
    AgentCore.INSTANCE.clearContext();
    super.onDestroy();
}
```

### 7. Listener Best Practices (Java Version)

```java
// Agent status listener
pageAgent.setOnAgentStatusChangedListener(new OnAgentStatusChangedListener() {
    @Override
    public boolean onStatusChanged(String status, String message) {
        // status: "listening", "thinking", "processing", "reset_status"
        Log.d("ChatActivity", "Agent status changed: " + status + ", message: " + message);
        return true; // Intercept default UI display
    }
});

// Voice transcription listener
pageAgent.setOnTranscribeListener(new OnTranscribeListener() {
    @Override
    public boolean onASRResult(Transcription transcription) {
        if (!transcription.getText().isEmpty()) {
            if (transcription.getFinal()) {
                // Handle final user input
                generateRoleResponse(transcription.getText());
            }
        }
        return true;
    }

    @Override
    public boolean onTTSResult(Transcription transcription) {
        if (!transcription.getText().isEmpty()) {
            if (transcription.getFinal()) {
                // AI response complete, add to history
                LLMMessage assistantMessage = new LLMMessage(com.ainirobot.agent.base.llm.Role.ASSISTANT, transcription.getText());
                addToHistory(assistantMessage);
            }
        }
        return true;
    }
});
```

## Java Version Summary

This Java version sample code demonstrates the same core features as the Kotlin version:

1. **AppAgent Implementation** - Role-playing assistant's application-level Agent configuration
2. **PageAgent Usage** - Agent implementation for role selection and conversation pages
3. **Action System** - Role selection Action creation and execution
4. **Deep LLM Integration** - Role-playing LLM calls and conversation history management
5. **Listener Mechanism** - Practical applications of ASR/TTS listeners and Agent status listeners
6. **Lifecycle Management** - Resource management when pages start and destroy
7. **Async Task Processing** - Using AsyncTaskHelper utility class to handle async operations in background threads

Java version code is excerpted from the actual running AgentRoleJava project, demonstrating complete application patterns of AgentSDK in Java environments.
