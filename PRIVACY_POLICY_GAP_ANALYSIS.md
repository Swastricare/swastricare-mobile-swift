# Privacy Policy & Terms & Conditions Gap Analysis

## Executive Summary

**Status:** ⚠️ **Gaps Found** - The privacy policy and terms & conditions do not fully match the app's actual data collection practices, particularly regarding image collection and AI image analysis.

---

## Current Privacy Policy Coverage

The current privacy policy (in `ConsentView.swift`) mentions:
- ✅ Personal information (name, email) when creating an account
- ✅ Health data from Apple HealthKit (with permission)
- ✅ Medication and hydration data
- ✅ Documents stored in secure vault

---

## What the App Actually Collects

### 1. **Image Collection** ⚠️ **NOT FULLY DISCLOSED**

The app collects images in multiple ways:

#### a) **Photo Library Access** - ❌ **MISSING FROM POLICY**
- **Location:** `VaultView.swift` uses `PhotosPicker` to select images from photo library
- **Purpose:** Users can upload medical documents/images to the vault
- **Missing Permission Description:** `PrivacyInfo.plist` does not include `NSPhotoLibraryUsageDescription`
- **Policy Gap:** Privacy policy mentions "Documents you store in the secure vault" but doesn't explicitly mention **images/photos** collection

#### b) **Camera for Heart Rate Measurement** - ⚠️ **PARTIALLY DISCLOSED**
- **Location:** `PrivacyInfo.plist` has `NSCameraUsageDescription`
- **Purpose:** "SwasthiCare needs camera access to measure your heart rate by detecting blood flow through your fingertip"
- **Policy Gap:** Privacy policy doesn't mention camera usage or image collection for health measurements

#### c) **AI Features (Multiple)** - ❌ **PARTIALLY DISCLOSED**

**1. AI Image Analysis:**
- **Location:** `supabase/functions/ai-image-analysis/index.ts`
- **Purpose:** Images are analyzed using **Google Gemini 1.5 Flash Vision API** for:
  - Meal analysis (food identification, calorie estimation)
  - Workout analysis (activity identification, form tips)
  - Supplement analysis (wellness information)
- **Third-Party Service:** Images are sent to Google Gemini API for processing
- **Status:** ✅ Now disclosed in privacy policy

**2. AI Chat Assistant:**
- **Location:** `supabase/functions/ai-chat/index.ts`
- **Purpose:** Chat conversations with health assistant
- **Data Sent:** User messages, conversation history sent to **Google Gemini 3 Flash Preview**
- **Storage:** Conversations stored in `ai_conversations` table
- **Status:** ✅ Now disclosed in privacy policy

**3. AI Health Analysis:**
- **Location:** `supabase/functions/ai-health-analysis/index.ts`
- **Purpose:** Comprehensive health metrics analysis
- **Data Sent:** Health metrics (steps, heart rate, sleep, calories, exercise, distance, blood pressure, weight) sent to **Google Gemini 3 Flash Preview**
- **Storage:** Analysis results stored in `ai_insights` table
- **Status:** ✅ Now disclosed in privacy policy

**4. AI Text Generation:**
- **Location:** `supabase/functions/ai-text-generation/index.ts`
- **Purpose:** Generate daily summaries, weekly reports, goal suggestions
- **Data Sent:** Health data sent to **Google Gemini Pro**
- **Storage:** Generated content stored in `generated_content` table
- **Status:** ✅ Now disclosed in privacy policy

### 2. **Detailed Health Data Collection** - ⚠️ **TOO VAGUE**

**Current Policy Says:** "Health data from Apple HealthKit (with your permission)"

**Actually Collected (from `HealthKitService.swift`):**
- Step count
- Heart rate
- Sleep analysis
- Active calories burned
- Exercise time
- Stand time
- Distance walking/running
- Blood pressure (systolic & diastolic)
- Body mass (weight)
- Dietary water

**Policy Gap:** The policy should be more specific about what health data types are collected, or at least provide a link to see the full list.

### 3. **Health Profile Information** - ✅ **COVERED**
- Name, gender, date of birth, height, weight, blood type
- This is covered under "Personal information" section

### 4. **Voice/Audio Collection** - ✅ **COVERED IN PLIST, MISSING IN POLICY**
- **Location:** `PrivacyInfo.plist` has `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`
- **Purpose:** Speech-to-text conversion in AI Assistant
- **Policy Gap:** Privacy policy doesn't mention voice/audio recording

### 5. **Third-Party Services** - ❌ **MISSING**
- **Google Gemini Vision API:** Used for image analysis (not mentioned)
- **Supabase:** Used for data storage (should be mentioned)
- **Apple HealthKit:** Mentioned but not as a third-party service

---

## Missing Permission Descriptions

### ❌ `NSPhotoLibraryUsageDescription` - **MISSING**

The app uses `PhotosPicker` to access the photo library but `PrivacyInfo.plist` doesn't include this permission description. This is required by Apple App Store guidelines.

**Recommended addition:**
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>SwasthiCare needs access to your photo library to upload medical documents and images to your secure vault.</string>
```

---

## Recommendations

### 🔴 **Critical - Must Fix Before App Store Submission**

1. **Add AI Image Analysis Disclosure**
   - Update privacy policy to explicitly mention:
     - Images are analyzed using AI (Google Gemini Vision API)
     - Purpose: Meal, workout, and supplement analysis
     - Images are sent to Google for processing
     - Analysis results are stored in the database

2. **Add Photo Library Permission Description**
   - Add `NSPhotoLibraryUsageDescription` to `PrivacyInfo.plist`
   - Update privacy policy to explicitly mention photo/image collection

3. **Add Camera Usage Disclosure**
   - Update privacy policy to mention camera usage for heart rate measurement
   - Clarify that camera images are processed locally (if true) or sent to servers (if applicable)

### 🟡 **Important - Should Fix**

4. **Expand Health Data Collection Details**
   - Be more specific about which HealthKit data types are collected
   - Or provide a comprehensive list in an expandable section

5. **Add Voice/Audio Collection Disclosure**
   - Mention microphone and speech recognition usage in privacy policy
   - Explain purpose (AI Assistant voice input)

6. **Add Third-Party Services Section**
   - List all third-party services that process user data:
     - Google Gemini Vision API (image analysis)
     - Supabase (data storage)
     - Apple HealthKit (health data)

### 🟢 **Nice to Have**

7. **Add Data Retention Policy**
   - How long is data stored?
   - When is data deleted?

8. **Add Data Location Information**
   - Where is data stored geographically?
   - Is data stored in specific regions (e.g., US, EU)?

---

## Updated Privacy Policy Sections Needed

### Section: "Information We Collect"

**Current:**
```
- Personal information (name, email) when you create an account
- Health data from Apple HealthKit (with your permission)
- Medication and hydration data you enter
- Documents you store in the secure vault
```

**Recommended Update:**
```
- Personal information (name, email) when you create an account
- Health profile information (name, gender, date of birth, height, weight, blood type)
- Health data from Apple HealthKit (with your permission), including:
  * Activity data (steps, exercise time, distance, calories)
  * Vital signs (heart rate, blood pressure)
  * Body measurements (weight)
  * Sleep data
  * Hydration data
- Images from your photo library for medical document storage
- Images captured via camera for heart rate measurement
- Images analyzed using AI for meal, workout, and supplement insights
- Audio/voice recordings for AI Assistant voice input (with your permission)
- Documents and images you store in the secure vault
- Medication and hydration data you enter
```

### New Section: "How We Process Your Images"

**Add:**
```
- Image Analysis: We use Google Gemini Vision API to analyze images you upload for meal, workout, and supplement insights. Images are sent to Google for processing and analysis results are stored securely.
- Heart Rate Measurement: We use your device camera to detect blood flow through your fingertip for heart rate measurement. Camera frames are processed locally on your device and not stored or transmitted.
- Document Storage: Images you upload to the medical vault are stored securely in our encrypted storage system.
```

### New Section: "Third-Party Services"

**Add:**
```
- Google Gemini Vision API: Processes images for AI-powered health insights
- Supabase: Provides secure cloud storage and database services
- Apple HealthKit: Provides access to health data (with your explicit permission)
```

---

## Updated Terms & Conditions Needed

### Section: "Service Description"

**Current:**
```
Swastricare provides health tracking, medication reminders, AI-powered insights, and secure document storage. We may modify or discontinue the service at any time.
```

**Recommended Update:**
```
Swastricare provides health tracking, medication reminders, AI-powered insights (including image analysis for meals, workouts, and supplements), secure document storage, and heart rate measurement using your device camera. We may modify or discontinue the service at any time.
```

---

## Missing from PrivacyInfo.plist

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>SwasthiCare needs access to your photo library to upload medical documents and images to your secure vault.</string>
```

---

## Compliance Notes

### Apple App Store Requirements
- ❌ Missing `NSPhotoLibraryUsageDescription` - **Required** when using PhotosPicker
- ✅ All other required permissions are present

### GDPR/Privacy Compliance
- ⚠️ Third-party data processing (Google Gemini) not disclosed
- ⚠️ Purpose limitation - AI image analysis purpose not clearly stated
- ⚠️ Data minimization - Not clear if images are stored after analysis

---

## Next Steps

1. ✅ **Immediate:** Add `NSPhotoLibraryUsageDescription` to `PrivacyInfo.plist`
2. ✅ **Before Launch:** Update privacy policy in `ConsentView.swift` with missing disclosures
3. ✅ **Review:** Legal review of updated privacy policy and terms
4. ✅ **Test:** Ensure all permission requests show proper descriptions
5. ✅ **App Store:** Verify privacy nutrition labels match actual data collection

---

## Files to Update

1. `swastricare-mobile-swift/PrivacyInfo.plist` - Add photo library permission
2. `swastricare-mobile-swift/Views/Auth/ConsentView.swift` - Update PrivacyContentView and TermsContentView
3. Consider external privacy policy document if content becomes too long for in-app display
