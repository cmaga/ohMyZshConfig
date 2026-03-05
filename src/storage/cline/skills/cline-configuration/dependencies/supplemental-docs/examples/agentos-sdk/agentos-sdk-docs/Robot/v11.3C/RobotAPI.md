# Robot Native Interface Usage Reference

## RobotOS Introduction

RobotOS is an open development platform by Orion Star, developed on the Android platform for multi-morphology hardware robots and diverse business scenario combinations.

RobotOS provides rich robot business APIs and robot capability components, enabling developers to conveniently develop robot applications.

Based on the Android platform, RobotOS provides an SDK for Android APK development. Users can apply RobotService.jar to develop Android applications on robots. All robot models running RobotOS support this SDK.

## Important: Speech Functionality Migration Notice

**On the AgentOS system, all speech and NLP-related functionalities have been migrated to AgentOS SDK. The original speech and NLP functionalities in RobotAPI have been deprecated:**

### Deprecated RobotAPI Speech and NLP Functionalities

- **ASR (Automatic Speech Recognition)**: Original RobotAPI speech-to-text functionality
- **TTS (Text-to-Speech)**: Original RobotAPI text-to-speech functionality
- **NLP (Natural Language Processing)**: Original RobotAPI natural language understanding and processing functionality

### New Speech and Large Language Model Solutions

**All speech and NLP functionalities are now provided through AgentOS SDK:**

- **Wake-free interaction**: AgentOS SDK provides more intelligent wake-free speech interaction
- **ASR/TTS**: Implemented through AgentOS SDK interfaces such as `AgentCore.tts()`
- **Intelligent conversation**: Integration of large language models for natural language understanding and generation, replacing original NLP functionality
- **Action planning**: Automatic action planning and execution based on user speech intent
- **Large language model capabilities**: Powerful natural language understanding through large language models, replacing traditional NLP

### Migration Guide

If your project uses RobotAPI speech or NLP functionalities, please:

1. **Remove RobotAPI-related code**: Delete original ASR, TTS, NLP, and wake-up RobotAPI calls
2. **Integrate AgentOS SDK**: Refer to [AgentOS SDK Documentation](../Agent/v0.4.5/AgentOS_SDK_Doc_v0.4.5.md) for integration
3. **Functionality Mapping Migration**:
   - RobotAPI wake-up -> AgentOS SDK wake-free interaction
   - RobotAPI ASR -> AgentOS SDK speech recognition listening
   - RobotAPI TTS -> AgentOS SDK `AgentCore.tts()` interface
   - RobotAPI NLP -> AgentOS SDK large language model interface and action planning

### Collaborative Use

**Collaborative Relationship between RobotAPI and AgentOS SDK:**

- **AgentOS SDK**: Responsible for all AI intelligent interactions (speech interaction, intelligent conversation, large language model capabilities, action planning execution)
- **RobotAPI**: Responsible for robot hardware control (motion, navigation, sensors, vision, etc)

**RobotAPI Legacy Speech Functionality Reference Documentation:**
The following documentation helps developers understand the original RobotAPI speech functionality, facilitating the identification and removal of legacy code in projects:

- [Speech](https://orionbase.orionstar.com/doc?m=21&h=6065a29&lang=cn#text%E8%BD%ACmp3)

## Version

**V11.3 Version API Latest**

## SDK Integration

### 1. Import SDK Dependencies

#### Add JAR Package Dependencies

1. Obtain SDK file: Find the `robotservice_xx.jar` file in the Robot version directory (such as `Robot/v11.3C/robotservice_11.3.jar`). SDK file follows the `robotservice_<version>.jar` naming convention. Please select the corresponding directory according to the actual version
2. Copy the JAR package file to the `app/libs/` directory of the Android project
3. Add dependency configuration in the `app/build.gradle` file:

```gradle
dependencies {
    implementation files('libs/robotservice_11.3.jar')
    // Other dependencies...
}
```

### 2. Configure Manifest File

Add the following configuration in the `AndroidManifest.xml` file:

```xml
<activity android:name=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    <intent-filter>
        <action android:name="action.orionstar.default.app" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</activity>
```

### 3. Startup Configuration (Optional)

If you need the application to automatically start after the robot boots up, please configure according to the following steps:

#### Step 1: Manifest Configuration

Add the following intent-filter in Activity:

```xml
<intent-filter>
    <action android:name="action.orionstar.default.app" />
    <category android:name="android.intent.category.DEFAULT" />
</intent-filter>
```

#### Step 2: System Settings

Configure in the robot system:

1. Swipe down with three fingers to enter system settings
2. Select "Developer Settings"
3. Configure your application in "Startup Programs"

> **Important Note**: Startup program setting function requires OTA3 or later version support

### 4. Permission Configuration

To ensure the SDK functions properly, declare the following permissions in `AndroidManifest.xml`:

```xml
<!-- Internet access permission -->
<uses-permission android:name="android.permission.INTERNET"/>
<!-- Robot settings provider permission -->
<uses-permission android:name="com.ainirobot.coreservice.robotSettingProvider" />
<!-- External storage read/write permission -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

## SDK Integration Steps

### 1. Create Callback Interface

Create a callback to receive speech requests and system events:

```java
public class ModuleCallback extends ModuleCallbackApi {
    @Override
    public boolean onSendRequest(int reqId, String reqType, String reqText, String reqParam)
            throws RemoteException {
                // This callback is deprecated
        return true;
    }

    @Override
    public void onRecovery() throws RemoteException {
        // Control right restored. After receiving this event, regain control of the robot
    }

    @Override
    public void onSuspend() throws RemoteException {
        // Control right removed by system. After receiving this event, all API calls are invalid
    }
}
```

### 2. Connect to Server

```java
RobotApi.getInstance().connectServer(this, new ApiListener() {
    @Override
    public void handleApiDisabled() {
        // API Disabled
    }

    @Override
    public void handleApiConnected() {
        // Server connected, set callbacks to receive requests, including speech instructions, system events, etc

    }

    @Override
    public void handleApiDisconnected() {
        // Connection Disconnected
    }
});
```

**Important Note:**
Initialization of the robot SDK marks the robot transferring chassis capability permissions to the currently running APP. The robot will trigger the disconnection callback when the system takes over, a fault occurs, or another robot SDK program is started. Only when system takeover ends will it reconnect.

> **Note 1**: All APIs must be called after successfully connecting to the server
>
> **Note 2**: Only foreground processes running in the foreground can correctly connect and obtain robot chassis control permissions. Background services do not work.

### 5. Register Status Listener

```java
StatusListener statusListener = new StatusListener(){
    @Override
    public void onStatusUpdate(String type, String data) throws RemoteException {
        // Handle status update
    }
};

// Register status listener
RobotApi.getInstance().registerStatusListener(type, statusListener);

// Unregister status listener
RobotApi.getInstance().unregisterStatusListener(statusListener);
```

**Supported Status Types:**

- `Definition.STATUS_POSE`: Robot current coordinates, continuously reported
- `Definition.STATUS_POSE_ESTIMATE`: Current localization status, reported when localization status changes
- `Definition.STATUS_BATTERY`: Current battery status information, including charging status, battery level, low battery alarm, etc

### 6. Set reqId

Many SDK methods require passing the `reqId` parameter, which is an ID for debugging and log tracking. Passing any number allows the function to work normally, but for convenience in log tracking and debugging, it is recommended to make `reqId` a self-incrementing static variable, or pass different `reqId` values based on business needs to distinguish function calls.

## Vision Capability

### Introduction

Vision capability currently mainly refers to person detection and recognition modules. APIs are mainly provided through PersonApi and RobotApi.

Person detection is a local capability. When a person stands in front of the robot (excluding poor lighting conditions), the robot can detect the person. When the person is far away, both face and body can be detected. When the person is close, only face information can be detected. When the person ID is greater than or equal to 0, it indicates that the person face information is complete and can be used to obtain face photos for recognition.

Person recognition requires using face photos for recognition. This capability requires network usage. Please ensure that persons meet the conditions for taking photos when acquiring person photos.

> **Note**: When using robot vision capability, do not use the robot camera simultaneously. This will cause vision capability errors and failures

See the Demo for specific usage flow. The following is the API introduction:

### Main Person Information

```java
private int id; // Person face local recognition ID, this ID can be used for focus following, etc
private double distance; // Distance
private double faceAngleX; // Person face X-axis angle
private double faceAngleY; // Person face Y-axis angle
private int headSpeed; // Current robot head rotation speed
private long latency; // Data latency
private int facewidth; // Face width
private int faceheight; // Face height
private int faceX; // Face X coordinate
private int faceY; // Face Y coordinate
private int bodyX; // Body X coordinate
private int bodyY; // Body Y coordinate
private int bodywidth; // Body width
private int bodyheight; // Body height
private double angleInView; // Person angle relative to robot head
private String quality; // Quality check parameter
private int age; // Age (estimated value returned after cloud registration)
private String gender; // Gender (according to national regulations, this item will only return results after authorization and registration)
private int glasses; // Wearing glasses
private String remoteFaceId; // If registered, the registered person face remote ID
private String faceRegisterTime; // Registration time
// For more Person information, see the Person class definition in com.ainirobot.coreservice.client.listener in the SDK
```

### Register Person Change Listener

**Method Name:** `registerPersonListener` / `unregisterPersonListener`

**Invocation Method:**

```java
PersonListener listener = new PersonListener() {
    @Override
    public void personChanged() {
        super.personChanged();
        // When persons change, you can call the get current person list interface to get all persons in the robot vision
    }
};

// Register person listener
PersonApi.getInstance().registerPersonListener(listener);

// Unregister person listener
PersonApi.getInstance().unregisterPersonListener(listener);
```

**Parameter Description:**

- `listener`: Person information change listener

### Get All Persons Information

**Method Name:** `getAllPersons`

**Invocation Method:**

```java
// Get all persons information in robot vision
List<Person> personList = PersonApi.getInstance().getAllPersons();
// Get all persons information within 1m range in robot vision
List personList = PersonApi.getInstance().getAllPersons(1);
```

**Parameter Description:**

- `maxDistance`: Within what vision range of the robot, unit in meters. The robot can recognize persons most accurately at a distance of 1-3 meters.

**Return Value:**

- `personList`: Person information list

### Get Person List with Body Detected

**Method Name:** `getAllBodyList`

**Invocation Method:**

```java
// Get person list with all body information in robot vision
List<Person> personList = PersonApi.getInstance().getAllBodyList();
// Get person list with all body information within 1m range in robot vision
List personList = PersonApi.getInstance().getAllBodyList(1);
```

**Parameter Description:**

- `maxDistance`: Within what vision range of the robot, unit in meters. The robot can recognize persons most accurately at a distance of 1-3 meters.

**Return Value:**

- `personList`: Person information list

### Get Person List with Face Detected

**Method Name:** `getAllFaceList`

**Invocation Method:**

```java
// Get person list with all face information in robot vision
List<Person> personList = PersonApi.getInstance().getAllFaceList();
// Get person list with all face information within 1m range in robot vision
List personList = PersonApi.getInstance().getAllFaceList(1);
```

**Parameter Description:**

- `maxDistance`: Within what vision range of the robot, unit in meters. The robot can recognize persons most accurately at a distance of 1-3 meters.

**Return Value:**

- `personList`: Person information list

### Get Person List with Complete Face Detected

**Method Name:** `getCompleteFaceList`

**Invocation Method:**

```java
// Get person list with all complete face information in robot vision
List<Person> personList = PersonApi.getInstance().getCompleteFaceList();
```

**Return Value:**

- `personList`: Person information list

### Get Person in Focus Following

This method is only effective when focus following is in progress

**Method Name:** `getFocusPerson`

**Invocation Method:**

```java
Person person = PersonApi.getInstance().getFocusPerson();
```

**Return Value:**

- `person`: Person information

For focus following related APIs, click here to view.

### Get Face Photo

**Method Name:** `getPictureById`

**Invocation Method:**

```java
RobotApi.getInstance().getPictureById(reqId, faceId, count, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONObject json = new JSONObject(message);
            String status = json.optString("status");
            // Photo retrieved successfully
            if (Definition.RESPONSE_OK.equals(status)) {
                JSONArray pictures = json.optJSONArray("pictures");
                if (!TextUtils.isEmpty(pictures.optString(0))) {
                    // Full local storage path of photo
                    String picturePath = pictures.optString(0);
                }
            }
        } catch (JSONException | NullPointerException e) {
            e.printStackTrace();
        }
    }
});
```

**Parameter Description:**

- `faceID`: Face ID, obtainable through local face recognition (Person ID)
- `count`: Number of photos to retrieve, this parameter is currently ineffective, default is one

> **Note**: Images saved by this interface need to be manually deleted after use

### Auto Registration

**Method Name:** `startRegister`

Pass in the name. This method will capture faces from the camera in real-time and register the face with the given name. Use this method for daily person registration

**Invocation Method:**

```java
RobotApi.getInstance().startRegister(reqId, personName, timeout, tryCount, secondDelay, new ActionListener() {
    @Override
    public void onResult(int status, String response) throws RemoteException {
        if (Definition.RESULT_OK != status) {
            // Registration failed
            return;
        }
        try {
            JSONObject json = new JSONObject(response);
            String remoteType = json.optString(Definition.REGISTER_REMOTE_TYPE);
            String remoteName = json.optString(Definition.REGISTER_REMOTE_NAME);
            if (Definition.REGISTER_REMOTE_SERVER_EXIST.equals(remoteType)) {
                // Current user already exists
            } else if (Definition.REGISTER_REMOTE_SERVER_NEW.equals(remoteType)) {
                // New user registration successful
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
});
```

**Parameter Description:**

- `personName`: Registration name
- `timeout`: Timeout duration, attempts to re-register on failure until timeout
- `tryCount`: Number of retry attempts on failure, will give up retrying after retry time exceeds timeout
- `secondDelay`: Retry interval

> **Note**: Do not repeatedly register the same face

### Remote Registration

**Method Name:** `remoteRegister`

**Invocation Method:**

```java
RobotApi.getInstance().remoteRegister(reqId, name, path, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONObject jsonObject = new JSONObject(message);
            int code = jsonObject.optInt("code", -1);
            switch (code) {
                case 0:// Success
                    break;
                case Definition.REMOTE_CODE_FACE_INVALID:// Invalid image
                    break;
                default:// Others
                    break;
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
});
```

**Parameter Description:**

- `name`: Registration name
- `path`: Image path, obtainable through getPictureById

> **Note**: Do not repeatedly register the same face

### Remote Recognition

**Method Name:** `getPersonInfoFromNet`

**Invocation Method:**

```java
RobotApi.getInstance().getPersonInfoFromNet(reqId, faceId, pictures, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONObject json = new JSONObject(message);
            JSONObject info = json.getJSONObject("people");
            info.getString("name"); // Name
            info.getString("gender"); // Gender
            info.getString("age"); // Age
        } catch (JSONException | NullPointerException e) {
            e.printStackTrace();
        }
    }
});
```

**Parameter Description:**

- `faceID`: Face ID, obtainable through local face recognition (Person ID)
- `pictures`: Face photo, obtainable through getPictureById interface

### Switch Camera

**Method Name:** `switchCamera`

**Invocation Method:**

```java
RobotApi.getInstance().switchCamera(reqId, camera, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONObject json = new JSONObject(message);
            if (Definition.RESPONSE_OK.equals(json.getString("status"))) {
                // Switch successful
            }
        } catch (JSONException | NullPointerException e) {
            e.printStackTrace();
        }
    }
});
```

**Parameter Description:**

- `camera`: Camera, String type
  - `Definition.JSON_HEAD_FORWARD` Front camera
  - `Definition.JSON_HEAD_BACKWARD` Rear camera

## Camera

The robot cameras are either single or dual. Different product lines use different cameras. See the documentation below for details.

#### Leopard Secretary 2 and Leopard Secretary Mini

Dual cameras. The front camera can be opened using Android standard API or shared stream to get camera preview data. (Opening the front camera using Android standard API will temporarily disable robot vision algorithms. After release, vision algorithm capability will be restored after some time). Rear camera can only be opened using Android standard API.

#### Note

When using Android API to open camera, the APP may crash the first time you authorize it to use the camera, but there are no restrictions after that. If you encounter a crash when authorizing the camera, just restart it. After that, you can use the camera normally.

Landscape Robot Note: After starting through Android standard method, the orientation is 90 degrees, because the robot has no gyroscope, the program defaults to portrait camera, but the robot is actually a landscape device. The solution is simple: set camera rotation to -90 degrees or 270 degrees through Android API (or other video SDK APIs) to correct it

The following Demos are for Android camera API usage, for reference only. If not satisfied, please search online according to your needs

Camera1 Demo

Camera2 Demo

### Camera Data Stream Sharing

Because the robot vision capability VisionSDK needs to use the camera, if the camera is occupied by secondary development programs, it will make robot face detection and face recognition unavailable. If you want to use the camera without affecting robot vision functionality, you need to use shared data stream to get camera data from VisionSDK. Camera data is obtained through SurfaceShareApi. It has three main methods:

- startRequest(): Start shared data stream
- onImageAvailable(ImageReader reader): This is a callback where all image data from shared streams comes out
- stopPushStream(): Close shared data stream

Obtaining image data via shared streams has large memory and CPU overhead. Be sure to close it when not in use to avoid OOM. Images obtained from shared data streams are in YUV format. To render to surfaceview, they need to be converted to bitmap.

## Basic Motion

### Linear Motion

**Method Name:** `goForward` / `goBackward`

**Invocation Method:**

```java
CommandListener motionListener = new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        if ("succeed".equals(message)) {
            // Call successful
        } else {
            // Call failed
        }
    }
};
RobotApi.getInstance().goForward(reqId, speed, motionListener);
RobotApi.getInstance().goForward(reqId, speed, distance, motionListener);
RobotApi.getInstance().goForward(reqId, speed, distance, avoid, motionListener);
RobotApi.getInstance().goBackward(reqId, speed, motionListener);
RobotApi.getInstance().goBackward(reqId, speed, distance, motionListener);
```

**Parameter Description:**

- `speed`: Motion speed, unit: m/s, range 0 ~ 1.0. Speeds greater than 1.0 will be capped at 1.0
- `distance`: Motion distance, unit: m. Value must be greater than 0.
- `avoid`: Whether to perform obstacle avoidance while walking. Only forward motion supports obstacle avoidance.

### Rotational Motion

**Method Name:** `turnLeft` / `turnRight`

**Invocation Method:**

```java
CommandListener rotateListener = new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        if ("succeed".equals(message)) {
            // Call successful
        } else {
            // Call failed
        }
    }
};
RobotApi.getInstance().turnLeft(reqId, speed, rotateListener);
RobotApi.getInstance().turnLeft(reqId, speed, angle, rotateListener);
RobotApi.getInstance().turnRight(reqId, speed, rotateListener);
RobotApi.getInstance().turnRight(reqId, speed, angle, rotateListener);
```

**Parameter Description:**

- `speed`: Rotation speed, unit: degree/s, range 0 ~ 50 degrees/s
- `angle`: Rotation angle, unit: degree. Value must be greater than 0

### Control Robot through Angular/Linear Velocity

**Method Name:** `motionArcWithObstacles`

**Invocation Method:**

```java
RobotApi.getInstance().motionArcWithObstacles(reqID,0.5,0.5,new CommandListener(){
    @Override
    public void onResult(int result, String message, String extraData) {
    }
    @Override
    public void onStatusUpdate(int status, String data, String extraData) {
    }
});
```

**Parameter Description:**

- `lineSpeed`: Linear speed, range -1.2 ~ 1.2
- `angularSpeed`: Angular speed, range -2 ~ 2

### Stop

**Method Name:** `stopMove`

**Invocation Method:**

```java
RobotApi.getInstance().stopMove(reqId, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        if ("succeed".equals(message)) {
            // Call successful
        } else {
            // Call failed
        }
    }
});
```

> **Note:** This interface can only be used to stop forward, backward and rotation motions. It cannot be used to stop navigation or head motion.

### Head Gimbal Motion

**Method Name:** `moveHead`

**Invocation Method:**

```java
RobotApi.getInstance().moveHead(reqId, hMode, vMode, hAngle, vAngle, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONObject json = new JSONObject(message);
            String status = json.getString("status");
            if (Definition.CMD_STATUS_OK.equals(status)) {
                // Operation successful
            }
        } catch (JSONException | NullPointerException e) {
            e.printStackTrace();
        }
    }
});
```

**Parameter Description:**

- `hMode`: Mode for horizontal rotation. Absolute motion: `absolute`. Relative motion: `relative`
- `vMode`: Mode for vertical motion. Absolute motion: `absolute`. Relative motion: `relative`
- `hAngle`: Horizontal rotation angle, range: -120 ~ 120 degrees
- `vAngle`: Vertical motion angle, range: 0 ~ 90 degrees

> **Note:** Please note the physical limitations of different machine types. For mini and Xiaobao Express 2 models, horizontal rotation mode has no effect.

### Reset Gimbal to Initial Angle

**Method Name:** `resetHead`

**Invocation Method:**

```java
RobotApi.getInstance().resetHead(reqId, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONObject json = new JSONObject(message);
            String status = json.getString("status");
            if (Definition.CMD_STATUS_OK.equals(status)) {
                // Operation successful
            }
        } catch (JSONException | NullPointerException e) {
            e.printStackTrace();
        }
    }
});
```

## Map and Localization

### Introduction

Map and localization are prerequisites for robot navigation. Creating a new map tells the robot the walkable range, and localization tells the robot its current position. The robot comes with a "Map Tool" that can complete all map and location operations, or you can use the API yourself

**Set Location:** Inform the robot of the current location's name, which can then be used with navigation interface to navigate to this location

### Map Creation and Localization

Map creation and localization can be performed using the system-integrated map tools.

> In map coordinates, x and y represent the robot's position in the map, and theta represents the robot's facing direction (unit: radians)

### Localization (Set Robot Initial Position)

**Method Name:** `setPoseEstimate`

**Invocation Method:**

```java
try {
    JSONObject params = new JSONObject();
    // X coordinate
    params.put(Definition.JSON_NAVI_POSITION_X, x);
    // Y coordinate
    params.put(Definition.JSON_NAVI_POSITION_Y, y);
    // Z coordinate
    params.put(Definition.JSON_NAVI_POSITION_THETA, theta);
    RobotApi.getInstance().setPoseEstimate(reqId, params.toString(), new CommandListener() {
        @Override
        public void onResult(int result, String message) {
            if ("succeed".equals(message)) {
                // Localization successful
            }
        }
    });
} catch (JSONException e) {
    e.printStackTrace();
}
```

### Check if Currently Localized

**Method Name:** `isRobotEstimate`

**Invocation Method:**

```java
RobotApi.getInstance().isRobotEstimate(reqId, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        if (!"true".equals(message)) {
            // Currently not localized
        } else {
            // Currently localized
        }
    }
});
```

### Set Current Location Name

**Method Name:** `setLocation`

**Invocation Method:**

```java
RobotApi.getInstance().setLocation(reqId, placeName, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        if ("succeed".equals(message)) {
            // Location point saved successfully
        } else {
            // Location point save failed
        }
    }
});
```

**Parameter Description:**

- `placeName`: Location name

> **Note:** Before calling this interface, ensure localization is complete

### Get Position Coordinates by Location Name

**Method Name:** `getLocation`

**Invocation Method:**

```java
RobotApi.getInstance().getLocation(reqId, placeName, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONObject json = new JSONObject(message);
            // Whether current location exists
            boolean isExist = json.getBoolean(Definition.JSON_NAVI_SITE_EXIST);
            if (isExist) {
                // X coordinate
                double x = json.getDouble(Definition.JSON_NAVI_POSITION_X);
                // Y coordinate
                double y = json.getDouble(Definition.JSON_NAVI_POSITION_Y);
                // Facing direction
                double z = json.getDouble(Definition.JSON_NAVI_POSITION_THETA);
            }
        } catch (JSONException | NullPointerException e) {
            e.printStackTrace();
        }
    }
});
```

**Parameter Description:**

- `placeName`: Location name

> **Note:** Locations saved by setLocation are associated with the map. When retrieving locations via getLocation, you should use the same map, otherwise getLocation will fail

### Get All Position Points on Current Map

**Method Name:** `getPlaceList`

**Invocation Method:**

```java
RobotApi.getInstance().getPlaceList(reqId, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONArray jsonArray = new JSONArray(message);
            int length = jsonArray.length();
            for (int i = 0; i < length; i++) {
                JSONObject json = jsonArray.getJSONObject(i);
                // Commonly used
                json.getString("name"); // Location name
                json.getDouble("x"); // X coordinate
                json.getDouble("y"); // Y coordinate
                // Rarely used
                json.getDouble("theta"); // Facing direction
                json.getString("id"); // Location ID
                json.getLong("time"); // Update time
                json.getInt("status"); // 0: Normal area, can reach 1: Forbidden area, cannot reach 2: Outside map, cannot reach
            }
        } catch (JSONException | NullPointerException e) {
            e.printStackTrace();
        }
    }
});
```

### Get Robot Current Position

**Method Name:** `getPosition`

**Invocation Method:**

```java
RobotApi.getInstance().getPosition(reqId, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        try {
            JSONObject json = new JSONObject(message);
            // X coordinate
            double x = json.getDouble(Definition.JSON_NAVI_POSITION_X);
            // Y coordinate
            double y = json.getDouble(Definition.JSON_NAVI_POSITION_Y);
            // Facing direction
            double z = json.getDouble(Definition.JSON_NAVI_POSITION_THETA);
        } catch (JSONException | NullPointerException e) {
            e.printStackTrace();
        }
    }
});
```

> **Note:** Before calling this interface, ensure localization is complete

### Check if Robot is at Position Point

**Method Name:** `isRobotInLocations`

**Invocation Method:**

```java
try {
    JSONObject params = new JSONObject();
    params.put(Definition.JSON_NAVI_TARGET_PLACE_NAME, placeName); // Location name
    params.put(Definition.JSON_NAVI_COORDINATE_DEVIATION, range); // Location range
    RobotApi.getInstance().isRobotInlocations(reqId,
            params.toString(), new CommandListener() {
                @Override
                public void onResult(int result, String message) {
                    try {
                        JSONObject json = new JSONObject(message);
                        // Whether at target location
                        json.getBoolean(Definition.JSON_NAVI_IS_IN_LOCATION);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }
            });
} catch (JSONException e) {
    e.printStackTrace();
}
```

**Parameter Description:**

- `placeName`: Location name
- `range`: Location range, unit: m

### Get Current Map Name

**Method Name:** `getMapName`

**Invocation Method:**

```java
RobotApi.getInstance().getMapName(reqId, new CommandListener() {
    @Override
    public void onResult(int result, String message) {
        if (!TextUtils.isEmpty(message)) {
            // message is the map name
            String mapName = message;
        }
    }
});
```

### Listen for Position State Changes

Start a listener callback that triggers when location and location state change.

```java
public class Pose {
    public float px, py, theta;
    public final long time;
    public String name;
    /**
     * FREE = 0;      // Normal area, can reach
     * OBSTACLE = 1;  // Forbidden area, cannot reach
     * OUTSIDE = 2;   // Outside map, cannot reach
     */
    public int status;
    public float distance;
}
RobotApi.getInstance().registerStatusListener(Definition.STATUS_POSE,
    new StatusListener(){
        @Override
        public void onStatusUpdate(String type, String value) {
            Pose pose = GsonUtil.fromJson(value, Pose.class);
        }
    });
```

### Switch Map

**Method Name:** `switchMap`

**Invocation Method:**

```java
RobotApi.getInstance().switchMap(reqId, mapName, new CommandListener(){
    @Override
    public void onResult(int result, String message) {
        if ("succeed".equals(message)) {
            // Map switched successfully
        }
    }
});
```

**Parameter Description:**

- `mapName`: Map name

> **Note:** After switching maps, re-localization is required

## Navigation

### Introduction

Navigation refers to the robot's walking ability. The robot can move from point A to point B, automatically planning routes during movement and effectively avoiding obstacles.

Robot navigation uses many sensors, including bottom LIDAR, RGBD, head IR sensors (on some models), etc. Please do not block these sensors during navigation to avoid robot immobility or path planning failure.

> **Important Note:** The prerequisite for robot to execute navigation is: the robot has created a new map, is successfully localized on this map, and the LIDAR is in the enabled state. Please pay special attention to this!

### Navigation Status and Error Code Definition

Status and error code reference table that may appear in navigation series APIs

#### Navigation Status Definition (corresponding to NavigationListener's onStatusUpdate method)

```java
STATUS_START_NAVIGATION = 1014; // Start navigation
STATUS_START_CRUISE = 1015; // Start patrol
STATUS_NAVI_AVOID = 1018; // Start obstacle avoidance
STATUS_NAVI_AVOID_END = 1019; // Obstacle avoidance finished
STATUS_NAVI_OUT_MAP = 1020; // Out of map. It is recommended to call stopNavigation to stop navigation
STATUS_NAVI_MULTI_ROBOT_WAITING = 1034; // Multi-robot scheduling waiting
STATUS_NAVI_MULTI_ROBOT_WAITING_END = 1035; // Multi-robot scheduling wait finished
STATUS_NAVI_GO_STRAIGHT = 1036; // Start moving straight
STATUS_NAVI_TURN_LEFT = 1037; // Start turning left
STATUS_NAVI_TURN_RIGHT = 1038; // Start turning right
STATUS_NAVI_GLOBAL_PATH_FAILED = 1025; // Path planning failed, navigation failed, need to handle error, It is recommended to call stopNavigation to stop navigation
```

#### Navigation Error Code Definition (corresponding to NavigationListener's onError method)

```java
ERROR_DESTINATION_NOT_EXIST = -108; // Destination does not exist
ERROR_DESTINATION_CAN_NOT_ARRAIVE = -109; // Obstacle avoidance timeout, destination unreachable
ERROR_IN_DESTINATION = -113; // Currently near destination
ERROR_NOT_ESTIMATE = -116; // Currently not localized
ERROR_MULTI_ROBOT_WAITING_TIMEOUT = -125; // Multi-robot scheduling wait timeout
ERROR_NAVIGATION_FAILED = -120; // Navigation failed for other reasons, fallback failed
ACTION_RESPONSE_ALREADY_RUN = -1; // This interface has been called, please stop first before calling again
ACTION_RESPONSE_REQUEST_RES_ERROR = -6; // Already have interface call that needs to control chassis, please stop first before continuing
```

### Navigate to Specified Location

**Method Name:** `startNavigation`

**Parameter Description:**

- `destName`: Navigation destination name (must be set first via setLocation)
- `pose`: Navigation destination coordinates
- `obsDistance`: Maximum obstacle avoidance distance. Robot stops when obstacles are closer than this distance. Value must be greater than 0, default 0.75, unit: meters
- `coordinateDeviation`: Destination range. If the distance to the destination is within this range, it is considered reached. Recommended value is 0.2, unit: meters
- `time`: Obstacle avoidance timeout duration. If robot movement is less than 0.1m within this time, navigation fails. Unit: milliseconds, recommended 30\*1000
- `linearSpeed`: Navigation linear speed, range: 0.1 ~ 0.85 m/s, default: 0.7 m/s
- `angularSpeed`: Navigation angular speed, range: 0.4 ~ 1.4 rad/s, default: 1.2 rad/s

> **Note:** Before calling this interface, ensure localization is complete

### Stop Navigation to Specified Location

**Method Name:** `stopNavigation`

**Invocation Method:**

```java
RobotApi.getInstance().stopNavigation(reqId);
```

> **Note:** This interface can only be used to stop navigation started by startNavigation

## Battery Management

### Get Current Battery Level

**Invocation Method:**

```java
RobotSettingApi.getInstance().getRobotString(Definition.ROBOT_SETTINGS_BATTERY_INFO);
```

### Start Auto Charging

**Method Name:** `startNaviToAutoChargeAction`

**Invocation Method:**

```java
RobotApi.getInstance().startNaviToAutoChargeAction(reqId, timeout, new ActionListener() {
    @Override
    public void onResult(int status, String responseString) throws RemoteException {
        switch (status) {
            case Definition.RESULT_OK:
                // Charging successful
                break;
            case Definition.RESULT_FAILURE:
                // Charging failed
                break;
        }
    }
    @Override
    public void onStatusUpdate(int status, String data) throws RemoteException {
        switch (status) {
            case Definition.STATUS_NAVI_GLOBAL_PATH_FAILED:
                // Global path planning failed
                break;
            case Definition.STATUS_NAVI_OUT_MAP:
                // Target point cannot be reached
                break;
            case Definition.STATUS_NAVI_AVOID:
                // Route to charging pile is blocked by obstacles
                break;
            case Definition.STATUS_NAVI_AVOID_END:
                // Obstacle has been removed
                break;
            default:
                break;
        }
    }
});
```

**Parameter Description:**

- `timeout`: Navigation timeout duration. If charging pile is not reached within this time, auto-charging is considered failed

### Stop Auto Charging

**Method Name:** `stopAutoChargeAction`

**Invocation Method:**

```java
RobotApi.getInstance().stopAutoChargeAction(reqId, true);
```

### Stop Charging and Undock from Charging Pile

**Method Name:** `leaveChargingPile`

**Parameter Description:**

- `speed`: Speed for moving away from charging pile, default 0.7
- `distance`: Distance to move away from charging pile, default 0.2, unit: meters

> **Note 1:** This method cannot be used for contact charging undocking.
>
> **Note 2:** This method requires calling `RobotApi.getInstance().disableBattery();` to disable system charging first.

## System Functions

### System Status Monitoring

Robot has many states and events that can be monitored to assist work. Monitoring is mainly done using the functions below.

**Invocation Method:**

```java
RobotApi.getInstance().registerStatusListener(
        Definition.STATUS_POSE_ESTIMATE, mStatusPoseListener);
```

Event definitions that can be monitored can be found in SDK's `Definition.java`. Currently provided monitoring states are as follows:

```java
STATUS_POSE = "navi_pose"; // Location changed
STATUS_MAP = "navi_map"; // Map changed
STATUS_EMERGENCY = "status_emergency"; // Emergency status
STATUS_POSE_ESTIMATE = "status_pose_estimate"; // Robot localization status
STATUS_AVOID_STOPPING = "status_avoid_stopping"; // Dynamic obstacle avoidance stop
STATUS_SWITCH_MAP = "status_switch_map"; // Map switching
STATUS_RADAR = "status_radar"; // Radar status
STATUS_BATTERY = "status_battery"; // Battery charging status
STATUS_MULTIPLE_ROBOT_WORKING = "status_multiple_robot_working"; // Multi-robot status information
STATUS_MAP_OUTSIDE = "status_map_outside_report"; // Robot outside map
STATUS_ROBOT_BEING_PUSHED = "status_robot_being_pushed"; // Robot being pushed
```

### Get Device SN

**Method Name:** `getRobotSn`

**Invocation Method:**

```java
boolean status = RobotApi.getInstance().getRobotSn(
    new CommandListener(){
        @Override
        public void onResult(int result, String message) {
            if (Definition.RESULT_OK == result) {
                String serialNum = message;
            } else {
                // Handle error
            }
        }
    });
```

### Get System Version

**Method Name:** `getVersion`

**Invocation Method:**

```java
String version = RobotApi.getInstance().getVersion();
```

### Disable System Functions

System no longer handles emergency stop events, no emergency stop screen. Can be used for custom emergency stop screen. When emergency stopped, all chassis-related APIs are disabled, and state switching APIs like wake-up and sleep are ineffective.

**Method Name:** `disableEmergency`

**Invocation Method:**

```java
RobotApi.getInstance().disableEmergency();
```

### Disable Battery Interface

Disable current battery interface. During charging, all client app capabilities except chassis operations are available.

If charging takeover is not needed, it is recommended to call this interface immediately after successful RobotAPI connection on app startup. The charging takeover screen will remain disabled until app exit.

**Method Name:** `disableBattery`

**Invocation Method:**

```java
RobotApi.getInstance().disableBattery();
```

### Sleep Function

#### Scenario Introduction

Sleep is a low-power running mode for robots when there are no tasks or low battery.

> **Note:** Using sleep API requires adding the following permissions:
>
> ```xml
> <uses-permission android:name="com.ainirobot.coreservice.robotSettingProvider" />
> ```

#### Start Sleep

**Method Name:** `robotStandby`

**Invocation Method:**

```java
RobotApi.getInstance().robotStandby(0, new CommandListener() {
    @Override
    public void onStatusUpdate(int status, String data, String extraData) {
        super.onStatusUpdate(status, data, extraData);
    }
});
```

#### Stop Sleep

**Method Name:** `robotStandbyEnd`

**Invocation Method:**

```java
RobotApi.getInstance().robotStandbyEnd(reqId);
```

### Install APK

**Method Name:** `installApk`

**Invocation Method:**

```java
RobotApi.getInstance().installApk(reqid, fullPathName, taskID);
```

**Parameter Description:**

- `reqId`: int type, command ID
- `fullPathName`: Installation package path
- `taskID`: Task ID, any non-empty string content
