# Privacy Policy for SwastriCare

**Last Updated:** March 12, 2026

## 1. Introduction

SwastriCare ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application (the "App"). This policy applies to both our iOS and Android applications.

Please read this privacy policy carefully. If you do not agree with the terms of this privacy policy, please do not access the App.

---

## 2. Information We Collect

### 2.1 Personal Information

We collect the following personal information that you provide to us:

- **Account Information:** Name, email address, phone number, date of birth, gender
- **Health Profile:** Age, weight, height, blood type, allergies, chronic conditions, emergency contacts
- **Authentication Data:** Email/password or Google Sign-In credentials

### 2.2 Health and Fitness Data

We collect and process the following health-related information:

- **Vital Signs:** Heart rate, blood pressure, oxygen saturation
- **Activity Data:** Steps, distance, active minutes, calories burned, workout/exercise sessions
- **Hydration:** Water intake logs and drinking patterns
- **Medications:** Medication names, dosages, schedules, and intake records
- **Diet & Nutrition:** Meal logs, calorie intake, macronutrient data, food photos
- **Sleep Data:** Sleep duration and quality (synced from HealthKit/Health Connect)
- **Menstrual Cycle:** Period dates, symptoms, predictions
- **Weight & Body Metrics:** Weight history, BMI, body measurements
- **Medical Documents:** Lab reports, prescriptions, medical records you upload to the Vault
- **Family Health Data:** Health information for family members you add to your care circle

### 2.3 Location Data (IMPORTANT)

**We collect precise location data (GPS coordinates) for the following purposes:**

- **Workout Tracking:** When you start a run, walk, cycle, or outdoor workout, we track your GPS route to calculate distance, pace, elevation, and display your route on a map
- **Background Location:** We collect location data even when the app is closed or not in use during active workout sessions to provide continuous route tracking. This allows the app to track your complete workout route without interruption.
- **Weather Information:** We use your approximate location to provide weather updates relevant to your workouts

**You have full control over location permissions:**

- Enable/disable location access in your device settings at any time
- Only GPS-based workout features require location access; all other app features (hydration tracking, medication reminders, vault, etc.) work without location permission
- Stop location tracking at any time by ending your workout session

**We DO NOT:**

- Track your location when you're not actively using workout features
- Sell your location data to third parties
- Use location data for advertising purposes
- Share your location with anyone except as necessary to display maps

### 2.4 Camera and Photo Data

We access your device camera for:

- **Heart Rate Monitoring:** Using your camera's flash and lens to detect heart rate via photoplethysmography (PPG)
- **Food Logging:** Taking photos of meals for AI-powered food recognition and nutrition estimation
- **AR Body Scanning:** 3D body scanning for fitness tracking (optional feature)
- **Document Upload:** Scanning medical documents for your Vault

**Note:** Camera frames used for heart rate detection are processed locally on your device and are NOT uploaded to our servers.

### 2.5 Microphone/Audio Data

We access your microphone for:

- **Voice Interaction:** Speaking with the AI health assistant
- Audio data is sent to our AI service provider (Google Gemini) for processing
- No audio is stored permanently; it's only used for real-time conversation

### 2.6 Device and Usage Information

We automatically collect:

- **Device Information:** Device model, operating system version, unique device identifiers
- **App Usage Data:** Features used, session duration, crash reports, performance metrics
- **Network Information:** Internet connectivity status (to ensure data sync)

### 2.7 Health Platform Integration Data

With your explicit permission, we sync data with:

- **iOS HealthKit:** Steps, heart rate, workouts, sleep, weight, active energy
- **Android Health Connect:** Steps, heart rate, workouts, sleep, distance, calories, blood pressure, VO2 max, hydration
- **Samsung Health:** Health metrics (Android only)
- **Garmin Connect:** Fitness data from Garmin devices (optional)

**Important:** We only read/write health data you explicitly grant permission for. You can revoke these permissions at any time through your device settings.

---

## 3. How We Use Your Information

We use the collected information for:

### 3.1 Core App Functionality

- Providing health tracking, medication reminders, hydration tracking, workout logging
- Syncing data across your devices
- Displaying health analytics and trends
- GPS route tracking and workout mapping

### 3.2 AI-Powered Features

- Personalized health insights and recommendations
- AI health assistant conversations (powered by Google Gemini and MedGemma)
- Food recognition and nutrition analysis
- Health nudges and proactive suggestions

### 3.3 Notifications and Reminders

- Medication reminders
- Hydration reminders
- Appointment alerts
- Menstrual cycle predictions and notifications

### 3.4 Family Care

- Sharing health data with family members you explicitly add to your care circle
- Role-based access control (view-only or manage permissions)

### 3.5 App Improvement

- Analytics to understand feature usage and improve user experience
- Crash reporting to fix bugs and improve stability
- Performance monitoring

### 3.6 Compliance and Safety

- Detecting and preventing fraud or abuse
- Complying with legal obligations
- Protecting user safety and security

---

## 4. How We Share Your Information

### 4.1 We DO Share Data With:

1. **Essential Service Providers:**
   - **Supabase:** Our backend infrastructure provider (database, authentication, file storage) - US-based, SOC 2 Type II compliant
   - **Google Firebase:** Analytics, crash reporting, push notifications - GDPR compliant
   - **Google Gemini/MedGemma:** AI conversation and medical insights - Subject to Google's privacy policies
   - **Google Maps:** Route visualization for workouts
   - **Weather API:** Weather data for workout planning

2. **Family Members (with your consent):**
   - Health data shared with family members you add to your family circle
   - Access is controlled by permissions you set (view vs. manage)

3. **Legal Requirements:**
   - When required by law, court order, or government regulation
   - To protect our rights, privacy, safety, or property

### 4.2 We DO NOT:

- Sell your personal or health data to third parties
- Use your data for advertising purposes
- Share your data with insurance companies
- Provide data to employers or government health databases without your explicit consent
- Share data with ABDM/ABHA without your authorization (when integration is active)

---

## 5. Data Storage and Security

### 5.1 Security Measures

- **Encryption in Transit:** All data sent between your device and our servers uses TLS 1.3 encryption
- **Encryption at Rest:** Database encrypted with AES-256 encryption
- **Local Encryption:** Sensitive data stored on your device uses AES-256-GCM encryption (Android) and iOS Keychain (iOS)
- **Biometric Protection:** Optional biometric lock (fingerprint/Face ID) for app access
- **Row-Level Security:** Database access controlled by Supabase RLS policies ensuring users can only access their own data
- **Secure File Storage:** Medical documents stored in encrypted cloud storage with signed URLs

### 5.2 Data Location

Primary data storage: Supabase servers (US-based infrastructure). All data transfers comply with applicable data protection regulations.

### 5.3 Data Retention

- **Active Accounts:** We retain your data as long as your account is active
- **Account Deletion:** When you delete your account, all personal data is permanently deleted within 30 days
- **Backups:** Backup copies are deleted within 90 days of account deletion
- **Legal Holds:** Data may be retained longer if required by law

---

## 6. Your Privacy Rights

You have the right to:

1. **Access Your Data:** Export all your health data in JSON format
2. **Correct Your Data:** Edit or update any personal or health information
3. **Delete Your Data:** Request complete account and data deletion from Settings → Account → Delete Account
4. **Data Portability:** Download your data in a machine-readable format
5. **Withdraw Consent:** Revoke health platform permissions, location access, or family sharing at any time
6. **Opt-Out of Analytics:** Disable analytics in app settings

### How to Exercise Your Rights

- **In-App:** Most privacy controls are available in Settings
- **Email:** Contact us at privacy@swastricare.com
- **Response Time:** We respond to requests within 30 days

---

## 7. Children's Privacy

SwastriCare is not intended for children under 13. We do not knowingly collect data from children under 13. If you are a parent/guardian and believe your child has provided us with personal information, please contact us at privacy@swastricare.com.

**Note:** Family features allow parents to track children's health, but the parent/guardian is responsible for the data collected about their dependents.

---

## 8. Third-Party Services

Our app integrates with third-party services that have their own privacy policies:

- **Supabase:** https://supabase.com/privacy
- **Google Firebase:** https://firebase.google.com/support/privacy
- **Google Gemini API:** https://ai.google.dev/gemini-api/terms
- **Google Maps Platform:** https://cloud.google.com/maps-platform/terms
- **HealthKit (iOS):** https://www.apple.com/legal/privacy/
- **Health Connect (Android):** https://health.google/health-connect-privacy/

We are not responsible for the privacy practices of these third-party services.

---

## 9. Advertising

**We do NOT collect or use advertising identifiers.** Our app does not display ads, and we have explicitly disabled:

- Google Analytics advertising features
- Ad ID collection (Android)
- IDFA tracking (iOS)

---

## 10. ABDM/ABHA Integration

When we integrate with India's Ayushman Bharat Digital Mission (ABDM):

- ABDM integration will be **opt-in only**
- You control what health data is linked to your ABHA ID
- Data sharing with ABDM-participating healthcare providers requires your explicit consent
- You can unlink your ABHA ID at any time
- We comply with National Health Authority's data protection guidelines

---

## 11. Permissions Summary

### Android Permissions

| Permission | Purpose | Required |
|------------|---------|----------|
| INTERNET | Data sync, AI features | Yes |
| ACCESS_FINE_LOCATION | GPS workout tracking | Optional |
| ACCESS_BACKGROUND_LOCATION | Continuous workout tracking | Optional |
| CAMERA | Heart rate, food logging, document scanning | Optional |
| RECORD_AUDIO | Voice AI assistant | Optional |
| USE_BIOMETRIC | App lock for security | Optional |
| POST_NOTIFICATIONS | Medication/hydration reminders | Optional |
| SCHEDULE_EXACT_ALARM | Precise medication reminders | Optional |
| Health Connect Permissions | Sync fitness and health data | Optional |

### iOS Permissions

| Permission | Purpose | Required |
|------------|---------|----------|
| Location (When In Use) | Weather, outdoor workout tracking | Optional |
| Location (Always) | Background workout tracking | Optional |
| Camera | Heart rate, food photos, documents | Optional |
| Microphone | Voice AI assistant | Optional |
| HealthKit | Sync health and fitness data | Optional |
| Notifications | Reminders and alerts | Optional |
| Face ID/Touch ID | App lock for security | Optional |

**All permissions except INTERNET are optional.** You can use core app features without granting all permissions.

---

## 12. International Data Transfers

While SwastriCare primarily serves users in India, our infrastructure partners may process data outside India. We ensure:

- All partners comply with GDPR and international data protection standards
- Appropriate safeguards are in place for data transfers
- Data processing agreements are established with all service providers

---

## 13. Updates to This Privacy Policy

We may update this Privacy Policy from time to time. We will notify you of material changes by:

- Posting the updated policy in the app
- Sending a push notification or email
- Requiring acceptance of the new policy before continued use

**Your continued use of the app after changes indicates acceptance of the updated policy.**

---

## 14. Compliance

We comply with:

- India's Digital Personal Data Protection Act, 2023
- Information Technology Act, 2000 and IT Rules
- GDPR (for applicable users)
- Apple App Store Guidelines
- Google Play Store Developer Policies

---

## 15. Contact Us

For privacy-related questions, requests, or concerns:

**Email:** privacy@swastricare.com
**Support:** support@swastricare.com
**Website:** https://swastricare.com

**Data Protection Officer:** dpo@swastricare.com

---

**By using SwastriCare, you acknowledge that you have read, understood, and agree to this Privacy Policy.**
