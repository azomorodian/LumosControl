// --- Required Libraries ---
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <Firebase_ESP_Client.h>
#include <Adafruit_NeoPixel.h>
#include <Arduino.h>
#include <stdio.h>
#include "secrets.h" // copy secrets.h.example → secrets.h (gitignored)
#define RESERVED_COLOR 0xFF0000 // Deep Red
long reservedEffectMillis = 0;
bool reservedFlag = false;


String SSID = "";
String PASSWORD = "";
String RESTAURANT_ID = "";
String LAMP_DOCUMENT_ID = "";
// --- Hardware Configuration ---
#define LED_PIN 3
#define LED_COUNT 24
#define TOUCH_SIGNAL_PIN 4

// Create an object to access the permanent memory (NVS)
Preferences preferences;

// Create a web server object on port 80
WebServer server(80);

// A flag to track if the device is in Access Point mode
bool apMode = false;
bool APModeFlash = false;
unsigned long lastAPModeUpdate = 0;


// --- Global Objects ---
Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// --- Touch Logic Variables ---
int prevDuration = 0;

// --- Timing Variables ---
unsigned long last_heartbeat_millis = 0;
unsigned long last_poll_millis = 0;
const long heartbeat_interval = 5 * 60 * 1000; // 5 minutes
const long poll_interval = 5000; // Check for new commands every 5 seconds

unsigned long last_poll_state_millis = 0;
const long poll_state_interval = 3000;
//----  battery Percentage ----
int batteryPercent = 20;

// --- Effect State Variables ---
String currentEffect = "static";
uint32_t currentColor = strip.Color(0, 0, 0); 
int currentBrightness = 150;
unsigned long lastEffectUpdate = 0;
int effectStep = 0; // For animations
unsigned long  CandleEffectMillis = 0;

bool callingFlag = false;
char deviceId[18];

String getDeviceId() {
  uint64_t mac = ESP.getEfuseMac();
  sprintf(deviceId, "%02X:%02X:%02X:%02X:%02X:%02X",
          (uint8_t)(mac >> 40),
          (uint8_t)(mac >> 32),
          (uint8_t)(mac >> 24),
          (uint8_t)(mac >> 16),
          (uint8_t)(mac >> 8),
          (uint8_t)mac);
  return String(deviceId);
}
// ======================= Firebase Functions =======================
// Callback function for authentication token status
void tokenStatusCallback(TokenInfo info) {
  if (info.status == token_status_ready) {
    Serial.println("Token ready, stream will be connected...");
  } else if (info.status == token_status_error) {
    Serial.printf("Token error: %s\n", info.error.message.c_str());
  }
}
void fetchStateData()
{
  String documentPath = "restaurants/" + String(RESTAURANT_ID) + "/lamps/" + String(LAMP_DOCUMENT_ID);
  Serial.println("Get State ...");
  if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(),"state")) {
    FirebaseJson json = fbdo.payload().c_str();
    FirebaseJsonData result;
    if (json.get(result, "/fields/state/mapValue/fields/tableStatus/stringValue")) {
      String tableStatus = result.stringValue;
      if (tableStatus == "reserved") reservedFlag = true; else reservedFlag = false;
    }
  }

}
void fetchControlData() {
  String documentPath = "restaurants/" + String(RESTAURANT_ID) + "/lamps/" + String(LAMP_DOCUMENT_ID);
  Serial.println("Polling...");
  // Fetch only the 'control' field from the document
  if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(),"control")) {
    FirebaseJson json = fbdo.payload().c_str();
    FirebaseJsonData result;
   // Update the base color
    if (json.get(result, "/fields/control/mapValue/fields/color/stringValue")) {
      String colorHex = result.stringValue;
      currentColor = strtoul(colorHex.substring(1).c_str(), NULL, 16);
      Serial.print("Color : ");
      Serial.println(currentColor);

    }

    // Update the base brightness
    if (json.get(result, "/fields/control/mapValue/fields/brightness/integerValue")) {
      currentBrightness = map(result.intValue, 0, 100, 0, 255);
      Serial.print("Brightness : ");
      Serial.println(currentBrightness);
    }

    // Update the effect string
    if (json.get(result, "/fields/control/mapValue/fields/effect/stringValue")) {
      currentEffect = result.stringValue;
      Serial.print("Effect : ");
      Serial.println(currentEffect);
      effectStep = 0; // Reset animation on effect change
    }
  } else {
    Serial.printf("Error polling data: %s\n", fbdo.errorReason().c_str());
    if (fbdo.errorReason().indexOf("not found") != -1){
      Serial.println("Document not found. This lamp has likely been deleted.");
      Serial.println("Clearing configuration and restarting...");
      preferences.begin("config", false);
      preferences.clear();
      preferences.end();
      delay(1000);
      ESP.restart();
    }
  }
}

// Function to send a touch event to Firebase
void sendTouchEvent(String eventType) {
  String documentPath = "restaurants/" + String(RESTAURANT_ID) + "/lamps/" + String(LAMP_DOCUMENT_ID);
  String content = "{\"fields\":{\"state\":{\"mapValue\":{\"fields\":{\"callStatus\":{\"stringValue\":\"" + eventType + "\"}}}}}}";

  Serial.print("Sending touch event: "); Serial.println(eventType);
  Serial.println(documentPath);
  Serial.println(content);
  if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.c_str(), "state.callStatus")) {
    // Success
  } else {
    Serial.printf("Error sending touch event: %s\n", fbdo.errorReason().c_str());
  }
}

// Function to send a heartbeat to indicate the device is online
void sendHeartbeat() {
  String documentPath = "restaurants/" + String(RESTAURANT_ID) + "/lamps/" + String(LAMP_DOCUMENT_ID);

  // --- Get and Format Current Time ---
  // This is the correct way to generate a timestamp that Firestore understands.
  time_t now = time(nullptr);
  char timeStr[30];
  // Format the time into the ISO 8601 format required by Firestore
  strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));

  // --- Create the JSON Payload ---
  // We now insert our formatted time string into the timestampValue field.
  String content = "{\"fields\":{\"state\":{\"mapValue\":{\"fields\":{\"isOnline\":{\"booleanValue\":true},\"lastSeen\":{\"timestampValue\":\"" + String(timeStr) + "\"}}}}}}";
  
  Serial.println("Sending heartbeat...");
  Serial.println(content); // Print the JSON for debugging
  
  if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.c_str(), "state.isOnline,state.lastSeen")) {
    // Success
  } else {
    Serial.printf("Error sending heartbeat: %s\n", fbdo.errorReason().c_str());
  }
}

// ======================= Effect Functions =======================
void updatePulseEffect() {
  // Use a sine wave for a smooth pulse
  float brightnessFactor = (sin(effectStep * 3.14159 / 180.0) + 1.0) / 2.0;
  float ff = brightnessFactor * (float)currentBrightness;
  strip.setBrightness((int)ff);
  strip.fill(currentColor);
  strip.show();
  effectStep = (effectStep + 20) % 360; // Increment angle
}

void updateFlickerEffect() {
  for (int i = 0; i < strip.numPixels(); i++) {
    int flickerAmount = random(0, 150);
    int r = max(0, (int)((currentColor >> 16) & 0xFF) - flickerAmount);
    int g = max(0, (int)((currentColor >> 8) & 0xFF) - flickerAmount);
    int b = max(0, (int)(currentColor & 0xFF) - flickerAmount);
    strip.setPixelColor(i, r, g, b);
  }
  strip.setBrightness(currentBrightness);
  strip.show();
}

void updateChaserEffect() {
  strip.clear(); // Turn all pixels off
  // Light up one pixel
  strip.setPixelColor(effectStep, currentColor);
  strip.setBrightness(currentBrightness);
  strip.show();
  effectStep = (effectStep + 20) % strip.numPixels(); // Move to the next pixel
}
// A quick double-flash in blue to get attention
void updateNotifyCallEffect() {
  // Turn all LEDs off for a moment
  strip.clear();
  strip.show();
  delay(150);
  
  // First flash
  strip.fill(strip.Color(0, 0, 255)); // Blue
  strip.setBrightness(255);
  strip.show();
  delay(200);
  
  // Turn off again
  strip.clear();
  strip.show();
  delay(150);
  
  // Second flash
  strip.fill(strip.Color(0, 0, 255)); // Blue
  strip.show();
  delay(200);
  
  // After the effect, it's best to return to a default state
  currentEffect = "static";
}

// A slow, gentle pulse in green
void updateNotifyFoodEffect() {
  // This uses the same logic as the pulse effect, but with a fixed green color
  float brightnessFactor = (sin(effectStep * 3.14159 / 180.0) + 1.0) / 2.0;
  strip.setBrightness(currentBrightness * (float)brightnessFactor);
  strip.fill(strip.Color(0, 255, 0)); // Green
  strip.show();
  effectStep = (effectStep + 20) % 360;
}
void updateRainbowEffect() {
    strip.rainbow(effectStep); 
    strip.setBrightness(currentBrightness);
    strip.show(); 
    effectStep++; // This will cycle through the hue colors
    if (effectStep >= 65536) {effectStep = 0;}
}

// ----------- CANDLE FLICKER FUNCTION --------------------
void updateCandleEffect() {
  if (millis() - CandleEffectMillis > random(50, 150)) { // Flicker at a random rate
    CandleEffectMillis = millis();
    for (int i = 0; i < LED_COUNT; i++) {
      // Create a warm, orangey-yellow base color
      // We vary the green component to shift between orange and yellow
      int green = random(120, 180);
      uint32_t color = strip.Color(255, green, 0);
      
      strip.setPixelColor(i, color);
    }
    // Set a random overall brightness for the flicker effect
    strip.setBrightness(random(100, 200));
    strip.show();
  }
}
// reserved effect
void updateReservedEffect() {

    // Create a brightness value that moves up and down using a sine wave
    // This makes the pulse smooth and elegant.
    float sineValue = sin(millis() / 2000.0f * PI);
    int brightness = map(sineValue * 100, -100, 100, 50, 200); // Pulse between 50 and 200

    strip.fill(RESERVED_COLOR);
    strip.setBrightness(brightness);
    strip.show();
}

// ================================================================
// Functions for Access Point (Configuration) Mode
// ================================================================

void handleConfigure() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"Body missing\"}");
    return;
  }
  String body = server.arg("plain");
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, body);
  if (error) {
    server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }

  const char* ssid = doc["ssid"];
  const char* password = doc["password"];
  const char* restId = doc["restaurant_id"];

  if (ssid && restId && password) {
    // ذخیره اطلاعات در NVS
    preferences.begin("config", false);
    preferences.putString("ssid", ssid);
    preferences.putString("password", password);
    preferences.putString("restaurant_id", restId);
    preferences.end();

    server.send(200, "application/json", "{\"status\":\"success\"}");
    Serial.println("Configuration saved. Restarting...");
    Serial.println("RestaurantID : " + String(restId));
    delay(1000);
    ESP.restart();
  } else {
    server.send(400, "application/json", "{\"error\":\"Missing fields\"}");
  }
}

void handleDeviceId() {
  String payload = "{\"device_id\":\"" + getDeviceId() + "\"}";
  server.send(200, "application/json", payload);
}

void setupAPMode() {
  apMode = true;
  Serial.println("Starting AP Mode...");
  String apName = "Lumos-Setup-" + String(deviceId).substring(12, 14) + String(deviceId).substring(15, 17);
  apName.replace(":", "");
  WiFi.softAP(apName.c_str());
  IPAddress myIP = WiFi.softAPIP();
  Serial.print("AP IP: "); Serial.println(myIP);
  server.on("/device_id", HTTP_GET, handleDeviceId);
  server.on("/configure", HTTP_POST, handleConfigure);
  server.begin();
  Serial.println("Web server started. Waiting for configuration...");
}


// This is the final, corrected version.
void registerDeviceInFirebase() {
  String deviceId = getDeviceId(); // Using MAC as the unique device ID
  // The path to the parent document that contains the "lamps" collection
  String parentDocPath = "restaurants/" + RESTAURANT_ID;
  // The full path to the collection itself
  String collectionPath = parentDocPath + "/lamps";
  
  Serial.println("Checking if device is already registered...");
  
  // Create a query to find a lamp with this deviceId
  FirebaseJson queryJson;
  queryJson.set("from/[0]/collectionId", "lamps");
  queryJson.set("where/fieldFilter/field/fieldPath", "deviceId");
  queryJson.set("where/fieldFilter/op", "EQUAL");
  queryJson.set("where/fieldFilter/value/stringValue", deviceId);
  queryJson.set("limit", 1);

  if (Firebase.Firestore.runQuery(&fbdo, FIREBASE_PROJECT_ID, "",parentDocPath.c_str() , &queryJson)) {
    Serial.println("Query successful. Response:");
    Serial.println(fbdo.payload());

    FirebaseJson queryResult = fbdo.payload().c_str();
    FirebaseJsonData resultData;
    if (queryResult.get(resultData, "[0]/document")) {     
       Serial.println("Device already registered. Fetching its lamp_id...");           
       queryResult.get(resultData, "[0]/document/name");
       String fullPath = resultData.stringValue;
       int lastSlash = fullPath.lastIndexOf('/');
       LAMP_DOCUMENT_ID = fullPath.substring(lastSlash + 1);
       Serial.print("Retrieved lamp_id: ");
       Serial.println(LAMP_DOCUMENT_ID);
    } else {
      // --- DEVICE NOT FOUND, CREATE IT ---
      Serial.println("Device not found. Creating new document...");
      time_t now = time(nullptr);
      char timeStr[30];
      strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
      FirebaseJson contentJson;
      contentJson.set("fields/restaurantId/stringValue", RESTAURANT_ID);
      contentJson.set("fields/deviceId/stringValue", deviceId);
      contentJson.set("fields/tableName/stringValue", "New Lamp");
      contentJson.set("fields/tableNumber/integerValue", 0);
      contentJson.set("fields/createdAt/timestampValue", String(timeStr));
      contentJson.set("fields/state/mapValue/fields/isOnline/booleanValue", true);
      contentJson.set("fields/state/mapValue/fields/batteryPercent/integerValue", 100);
      contentJson.set("fields/state/mapValue/fields/callStatus/stringValue", "none");
      contentJson.set("fields/state/mapValue/fields/tableStatus/stringValue", "available");
      contentJson.set("fields/state/mapValue/fields/lastSeen/timestampValue", String(timeStr));
      contentJson.set("fields/control/mapValue/fields/brightness/integerValue", 80);
      contentJson.set("fields/control/mapValue/fields/color/stringValue", "#FFFFFF");
      contentJson.set("fields/control/mapValue/fields/effect/stringValue", "static");
      
      if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", collectionPath.c_str(), contentJson.raw())) {
        Serial.println("New lamp document created successfully. Parsing response...");

        FirebaseJson response = fbdo.payload().c_str();
        response.get(resultData, "name");
       
        
        String fullPath = resultData.stringValue;
        int lastSlash = fullPath.lastIndexOf('/');
        LAMP_DOCUMENT_ID = fullPath.substring(lastSlash + 1);
        
        Serial.print("Captured new lamp_id: ");
        Serial.println(LAMP_DOCUMENT_ID);

      } else {
        Serial.println("Error creating document: " + fbdo.errorReason());
      }
    }
  } else {
    Serial.println("Query failed: " + fbdo.errorReason());
  }
}




void setupFirebase() {
  // Assign the project credentials
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  // Assign the signing verification certificates
  config.token_status_callback = tokenStatusCallback; //see addons/TokenHelper.h
  Firebase.reconnectNetwork(true);
  Firebase.begin(&config, &auth);
}

// ======================= Main Functions =======================

void setup() {
  Serial.begin(115200);
  Serial.println("\nBooting device...");
  strip.begin();
  strip.show();
  pinMode(TOUCH_SIGNAL_PIN, INPUT);

  String deviceID = getDeviceId();
  Serial.println("Device ID: " + deviceID);

// Start preferences memory in read-only mode to check for credentials
  preferences.begin("config", true); 
  SSID = preferences.getString("ssid", "");
  preferences.end();

 if (SSID == "") {
    // If no SSID is saved, enter configuration mode
    setupAPMode();
  } else {
    // If credentials are saved, try to connect to the Wi-Fi
    apMode = false;
    Serial.print("Found stored credentials. Connecting to: ");
    Serial.println(SSID);
    preferences.begin("config", true);
    PASSWORD = preferences.getString("password", "");
    RESTAURANT_ID = preferences.getString("restaurant_id", "");
    preferences.end();

    Serial.println(RESTAURANT_ID);
    WiFi.mode(WIFI_STA); // Set Wi-Fi mode to Station
    WiFi.begin(SSID.c_str(), PASSWORD.c_str());

    int attempts = 0;
    // Try to connect for about 5 minute
    while (WiFi.status() != WL_CONNECTED && attempts < 600) {
      delay(500);
      Serial.print(".");
      attempts++;
    }
    if (WiFi.status() == WL_CONNECTED) {
      // Connection successful
      Serial.println("\nWiFi connected!");
      Serial.print("IP address: ");
      Serial.println(WiFi.localIP());
      Serial.println("Syncing time with NTP server...");
      configTime(0, 0, "pool.ntp.org");
      time_t now = time(nullptr);
      while (now < 8 * 3600 * 2) { // A check to see if time is valid (greater than a low threshold)
        delay(500);
        now = time(nullptr);
      }
      Serial.println("Time synchronized.");
      setupFirebase();
      registerDeviceInFirebase();
      sendHeartbeat();
    } else {
      // Connection failed
      Serial.println("\nFailed to connect with stored credentials.");
      
      // Clear the invalid credentials to avoid infinite connection attempts
      preferences.begin("config", false);
      preferences.clear();
      preferences.end();
      // Enter configuration mode so the user can enter new credentials
      setupAPMode();
    }
  }

}

void loop() {
  if (apMode) {
    // If in configuration mode, just handle web server requests
    server.handleClient();
    if (millis() - lastAPModeUpdate > 300)
    {
      APModeFlash = !APModeFlash;
      if (APModeFlash)
      {

          strip.fill(strip.Color(0, 100, 0)); // Light Green
          strip.show();
      }
      else
      {
          strip.clear();
          strip.show();
      }
      lastAPModeUpdate = millis();
    }
  } else {
    // --- Touch Detection Logic ---
    int p1 = pulseIn(TOUCH_SIGNAL_PIN, HIGH, 10000);
    int p2 = pulseIn(TOUCH_SIGNAL_PIN, HIGH, 10000);
    int pulseDuration = p1>p2?p1:p2;
    if ((pulseDuration == 0 && prevDuration != 0) || (prevDuration == 0 && pulseDuration != 0)) {
      if (!reservedFlag) {
        sendTouchEvent("calling");
        callingFlag = true;
      }
    }
    prevDuration = pulseDuration;

    // --- Effect Update Logic (non-blocking) ---
    if (millis() - lastEffectUpdate > 50) {
      lastEffectUpdate = millis();
      if (callingFlag) {
        updateNotifyCallEffect();
        callingFlag = false;
      } else if((currentEffect != "Hard_Reset!") && reservedFlag) {
        //outside if
      } else  if (currentEffect == "pulse") {
        updatePulseEffect();
      } else if (currentEffect == "flicker") {
        updateFlickerEffect();
      } else if (currentEffect == "chaser") {
        updateChaserEffect();
      } else if (currentEffect == "notify_food") {
        updateNotifyFoodEffect();
      } else if (currentEffect == "rainbow") {
        updateRainbowEffect();
      } else if (currentEffect == "candle") {
          //if part implementent outside of this function because of random timing
      } else if (currentEffect == "Hard_Reset!") {
        Serial.println("\nClear Lamp Data.");
        preferences.begin("config", false);
        preferences.clear();
        preferences.end();
        delay(1000);
        ESP.restart();
      } else { // Default to "static"
        strip.fill(currentColor);
        strip.setBrightness(currentBrightness);
        strip.show();
      }
    }
    // --- Heartbeat Logic ---
    if (millis() - last_heartbeat_millis > heartbeat_interval) {
      last_heartbeat_millis = millis();
      sendHeartbeat();
    }
    if (millis() - last_poll_millis > poll_interval){
            last_poll_millis = millis();
            fetchControlData();
    }
    if (millis() - last_poll_state_millis > poll_state_interval) {
        last_poll_state_millis = millis();
        fetchStateData();
    }
    if (reservedFlag)
    {
      if (millis() - reservedEffectMillis > 30){
        reservedEffectMillis = millis();
        updateReservedEffect();
      }
    } else {
        if (currentEffect == "candle") {
            updateCandleEffect();
        }
    }
  }
}