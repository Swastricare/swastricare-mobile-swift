# Android Production Launch TODO

> **Purpose**: Complete gap analysis between iOS (reference) and Android (target). Organized into phases with delegatable tasks for agent sessions.
> **Generated**: 2026-03-04 | **Branch**: android-nikhil

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented and matches iOS |
| ⚠️ | Partially implemented / needs fixes |
| ❌ | Missing entirely |
| 🎨 | UI/Design gap |
| 🔧 | Code/Logic gap |
| 📱 | Platform-specific (no iOS equivalent) |

---

## PHASE 0: Critical Blockers (Must Fix Before Any Testing)

### P0-1: Build & Config Fixes
- [x] 🔧 ~~**Fix hardcoded version code in SplashScreen.kt:78**~~ — Now uses `BuildConfig.VERSION_CODE`
- [x] 🔧 ~~**Set up Weather API key**~~ — Now reads from `BuildConfig.OPENWEATHERMAP_API_KEY` (set via `gradle.properties`)
- [x] 🔧 ~~**Fix notification icon**~~ — Created `ic_notification.xml` vector drawable, updated `NotificationService` + `MedicationReminderReceiver`
- [x] 🔧 ~~**Fix ActivityDetailScreen placeholder data**~~ — Now loads real data from `RunActivityRepository`, falls back to sample only if not found
- [x] 🔧 ~~**Fix logout state clearing**~~ — `SupabaseAuthRepository` now clears SharedPreferences on signOut/deleteAccount
- [ ] 🔧 **Verify Google Sign-In web client ID** in `gradle.properties` is production-ready

### P0-2: Signing & Release Config
- [ ] 🔧 Create release signing keystore
- [ ] 🔧 Configure `signingConfigs` in `build.gradle.kts` for release builds
- [x] 🔧 ~~Enable R8/ProGuard minification~~ — `isMinifyEnabled = true`, `isShrinkResources = true` for release
- [x] 🔧 ~~ProGuard rules updated~~ — Added keep rules for SceneView/Filament, ML Kit, Firebase, Google Play Services, app data models
- [ ] 🔧 Update `versionName` and `versionCode` for launch (currently `1.0.0` / `1`)

---

## PHASE 1: Feature Parity Gaps (iOS has, Android missing/incomplete)

### P1-1: Home Screen (Vitals Dashboard)

**iOS Reference**: `Views/Home/HomeView.swift` — Health status card, hydration progress, medication timeline, diet summary, heart rate, nudge cards, quick actions

| Item | Status | Detail |
|------|--------|--------|
| Health status summary card | ⚠️ | Verify matches iOS layout: greeting + health score + status text |
| Hydration progress ring on home | ⚠️ | iOS shows inline progress ring with ml/goal — verify identical |
| Medication next-due card on home | ⚠️ | iOS shows timeline grouped by time slots on home |
| Diet calorie summary on home | ⚠️ | iOS shows CalorieProgressRing + macro bar inline |
| Heart rate last reading card | ⚠️ | iOS shows last BPM with trend indicator |
| Nudge cards (NudgeCardsView) | ⚠️ | iOS has `NudgeService` with smart contextual nudges — verify Android `SupabaseNudgeRepository` matches |
| 3D anatomy model viewer | ✅ | Both have SceneView/ModelViewer |
| Quick action buttons | ⚠️ | iOS has quick-add for water, food, meds from home — verify Android |

**Tasks**:
- [ ] 🎨 Screenshot-compare iOS HomeView vs Android HomeScreen section by section
- [ ] 🎨 Match card layouts, spacing, typography, icon sizes
- [ ] 🔧 Verify all home metric cards pull real data (not placeholders)
- [ ] 🎨 Match glass morphism card style (blur, border, corner radius)

### P1-2: Hydration Screen

**iOS Reference**: `Views/Home/HydrationView.swift` + `HydrationSettingsView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Water wave animation | ❌ | iOS has custom `WaterWave` shape animation showing fill level — Android missing |
| Drink type selection | ⚠️ | iOS supports: water, tea, coffee, juice, milk, etc. with icons — verify Android has all types |
| Daily history timeline | ⚠️ | iOS shows each drink entry with timestamp — verify Android |
| Smart goal calculation | ⚠️ | iOS calculates based on weight + activity + weather — verify Android `HydrationViewModel` matches |
| Calendar history view | ⚠️ | iOS has calendar view for hydration history — verify Android |
| Urine color guide | ❌ | iOS has `UrineColorGuideView.swift` — Android missing |
| DrinkingPatternLearner | ❌ | iOS has ML-based pattern learning for smart reminders — Android likely missing |
| Undo last drink | ⚠️ | Verify Android supports undo |

**Tasks**:
- [ ] 🎨 Implement water wave fill animation (custom Canvas/Path shape)
- [ ] 🔧 Add UrineColorGuideView equivalent screen
- [ ] 🔧 Implement DrinkingPatternLearner for smart reminder timing
- [ ] 🎨 Match drink type icons and selection UI
- [ ] 🎨 Match progress ring style (colors, stroke width, animation)

### P1-3: Medication Screen

**iOS Reference**: `Views/Home/MedicationsView.swift` + `AddMedicationView.swift` + `MedicationDetailView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Timeline view grouped by time | ⚠️ | iOS groups meds by morning/afternoon/evening/night — verify Android |
| Adherence tracking percentage | ⚠️ | iOS shows adherence % with visual indicator — verify |
| Ask AI button | ⚠️ | iOS has "Ask AI about this medication" button — verify Android |
| Medication detail with history | ⚠️ | iOS shows full medication history with taken/skipped/missed — verify |
| Medication frequency options | ⚠️ | iOS supports: daily, twice daily, three times, weekly, as needed — verify Android matches all |
| Medication form types | ⚠️ | iOS supports: tablet, capsule, liquid, injection, topical, inhaler — verify Android |
| Edit medication | ⚠️ | Verify full edit flow matches iOS |

**Tasks**:
- [ ] 🎨 Match medication card design (icon, name, dosage, time, status badge)
- [ ] 🔧 Verify all frequency/form options match iOS
- [ ] 🔧 Verify adherence calculation logic matches iOS
- [ ] 🎨 Match timeline grouping UI (section headers, dividers)

### P1-4: Diet & Nutrition Screen

**iOS Reference**: `Views/Home/DietView.swift` + `DietSettingsView.swift` + `FoodSearchView.swift` + `AddFoodView.swift`

| Item | Status | Detail |
|------|--------|--------|
| CalorieProgressRing | ⚠️ | iOS has animated circular progress ring — verify Android matches |
| MacroBreakdownBar | ⚠️ | iOS has horizontal stacked bar (carbs/protein/fat/fiber) — verify Android |
| MealSectionCard | ⚠️ | iOS groups by meal type with expand/collapse — verify Android |
| DietQuickActionButton | ⚠️ | iOS has floating quick-add button — verify Android |
| Nutritional insights | ⚠️ | iOS generates insights from meal data — verify Android |
| Food search with database | ⚠️ | Verify Android food search matches iOS database/API |
| Portion/serving size picker | ⚠️ | Verify Android has same serving units as iOS |
| Ask AI for meal analysis | ⚠️ | iOS has button to route to AI with meal context — verify |

**Tasks**:
- [ ] 🎨 Match calorie ring animation and colors
- [ ] 🎨 Match macro breakdown bar proportions and labels
- [ ] 🎨 Match meal section card layout (icon, name, calories, expand arrow)
- [ ] 🔧 Verify food database/search API parity

### P1-5: Heart Rate Screen

**iOS Reference**: `Views/HeartRate/` (6 files) — CameraPreviewView, WaveformView, ResultView, DisclaimerView, AnalyticsView

| Item | Status | Detail |
|------|--------|--------|
| Camera preview overlay | ⚠️ | iOS has finger placement guide overlay — verify Android |
| Waveform visualization | ⚠️ | iOS has real-time PPG waveform chart — verify Android |
| 30-second measurement timer | ⚠️ | Verify countdown UI matches |
| Result display with zones | ⚠️ | iOS shows BPM + zone (Normal/Elevated/High/Low) with color — verify |
| Medical disclaimer | ⚠️ | iOS has `HeartRateDisclaimerView` — verify Android shows same |
| Analytics/trends view | ⚠️ | iOS has `HeartRateAnalyticsView` with history charts — verify Android `HeartRateAnalyticsScreen` matches |
| Heartbeat pulse animation | ⚠️ | iOS has animated pulse effect during measurement — verify |
| Signal quality indicator | ⚠️ | iOS has `SignalValidator` with quality feedback — verify Android |
| Local storage for history | ⚠️ | iOS has `HeartRateLocalStorage` — verify Android persists readings |

**Tasks**:
- [ ] 🎨 Match camera overlay design (finger guide circle, instructions text)
- [ ] 🎨 Match waveform chart style (line color, grid, animation)
- [ ] 🎨 Match result card design (large BPM number, zone badge, date)
- [ ] 🔧 Verify PPG algorithm accuracy matches iOS (`PPGSignalProcessor`, `HeartRateDetector`, `SignalValidator`)

### P1-6: Run Activity & Live Workout

**iOS Reference**: `Views/Run/` (8+ files) — RunActivityView, LiveActivityTrackingView, ActivityDetailView, RouteMapView, RunCalendarView, WorkoutRecoveryView, charts

| Item | Status | Detail |
|------|--------|--------|
| Weekly progress chart | ⚠️ | iOS has `WeeklyProgressChartView` — verify Android |
| Activity history list | ⚠️ | Verify card design matches iOS |
| Live workout HUD | ⚠️ | iOS shows: distance, time, pace, HR, calories, elevation — verify Android `LiveWorkoutScreen` |
| Route map during workout | ⚠️ | iOS has real-time route drawing — verify Android `RouteMapView` |
| Workout countdown (3-2-1) | ✅ | Both have countdown timer |
| Splits list | ⚠️ | iOS has `SplitsListView` — verify Android `WorkoutSummaryScreen` shows splits |
| Pace chart | ⚠️ | iOS has `PaceChartView` — verify Android |
| Heart rate chart during workout | ⚠️ | iOS has `RunHeartRateChartView` — verify Android |
| Workout recovery view | ⚠️ | iOS has `WorkoutRecoveryView` for post-workout — verify Android `WorkoutRecoveryDialog` |
| Calendar heatmap | ⚠️ | iOS has `RunCalendarView` — verify Android `RunCalendarScreen` |
| Activity types | ⚠️ | Both support Walk/Run/Cycle/Hike — verify icons and colors match |

**Tasks**:
- [ ] 🎨 Match live workout HUD layout (metric positions, font sizes, colors)
- [ ] 🎨 Match workout summary card design
- [ ] 🎨 Match calendar heatmap colors and interaction
- [ ] 🔧 Verify GPS accuracy and route tracking quality

### P1-7: Menstrual Cycle Screen

**iOS Reference**: `Views/MenstrualCycle/MenstrualCycleView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Cycle status card | ⚠️ | iOS shows days until next period with phase — verify Android |
| Phase-specific tips | ⚠️ | iOS shows tips based on current phase — verify Android |
| Symptom logging | ⚠️ | Verify Android has same symptom options as iOS |
| Statistics view | ⚠️ | iOS shows avg cycle length, period duration — verify Android |
| Calendar with color-coded phases | ⚠️ | iOS color codes: Menstrual (pink), Follicular (green), Ovulation (orange), Luteal (purple) — verify Android matches |
| Push reminders for cycle | ⚠️ | Verify Android notification categories match iOS |

**Tasks**:
- [ ] 🎨 Match phase color coding exactly
- [ ] 🎨 Match cycle status card layout
- [ ] 🔧 Verify prediction algorithm matches iOS

### P1-8: Medical Vault

**iOS Reference**: `Views/Vault/VaultView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Folder organization | ⚠️ | iOS has folder structure — verify Android `VaultScreen` |
| Batch upload (up to 10) | ⚠️ | Verify Android supports batch upload |
| Document metadata (title, desc, date) | ⚠️ | Verify Android edit matches iOS |
| Selection mode for bulk ops | ⚠️ | iOS has multi-select mode — verify Android |
| Pull-to-refresh | ⚠️ | Verify Android has pull-to-refresh |
| Document viewer (PDF, images) | ⚠️ | Verify Android `DocumentViewerScreen` supports same file types |
| File type filtering | ⚠️ | iOS filters by type — verify Android category filters match |

**Tasks**:
- [ ] 🎨 Match vault card design (thumbnail, title, date, type badge)
- [ ] 🎨 Match folder/category filter UI
- [ ] 🔧 Verify upload to Supabase Storage works (check `SupbaseVaultRepository` — note typo in filename)
- [ ] 🔧 Fix typo: `SupbaseVaultRepository.kt` → `SupabaseVaultRepository.kt`

### P1-9: AI Health Assistant

**iOS Reference**: `Views/AI/AIView.swift` + `MedicalDisclaimerView.swift`

| Item | Status | Detail |
|------|--------|--------|
| 3 modes (General/Medical/Meal) | ⚠️ | iOS has mode tabs — verify Android mode switching UI |
| Typewriter animation | ⚠️ | iOS has character-by-character reveal — verify Android |
| Image upload (camera/library) | ⚠️ | iOS supports camera + photo library for meal analysis — verify Android |
| Medical disclaimer | ⚠️ | iOS shows disclaimer before medical mode — verify Android |
| Emergency alert | ⚠️ | iOS shows alert for serious health concerns — verify Android |
| Helpful/unhelpful feedback | ⚠️ | iOS has message feedback buttons — verify Android |
| Toast notifications | ⚠️ | Verify Android shows toasts for actions |
| Conversation persistence | ⚠️ | Verify Android saves chat history via `SupabaseAIConversationRepository` |
| Speech-to-text input | ✅ | Both have speech recognition |

**Tasks**:
- [ ] 🎨 Match chat bubble design (user vs AI, timestamp, avatar)
- [ ] 🎨 Match mode selector UI (tabs/chips)
- [ ] 🔧 Verify AI routing matches iOS (Gemini Flash → MedGemma 27B → MedGemma 4B)
- [ ] 🔧 Verify image analysis workflow

### P1-10: Profile & Settings

**iOS Reference**: `Views/Profile/ProfileView.swift` + `AccountView.swift` + `Views/Settings/SettingsView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Quick stats (age, height, weight, BMI) | ⚠️ | Verify Android matches iOS stat cards |
| Profile image | ⚠️ | iOS shows profile image with edit — verify Android |
| Family section in profile | ⚠️ | iOS has family invite/join from profile — verify Android navigation |
| Hydration settings link | ⚠️ | iOS links to hydration settings from profile — verify |
| Notification settings | ⚠️ | iOS has granular notification prefs — verify Android `NotificationSettingsScreen` |
| Biometric toggle | ⚠️ | Verify toggle behavior matches iOS |
| App version display | ⚠️ | Verify Android shows version info |
| Sign out flow | ⚠️ | Verify sign out clears all state |
| Delete account flow | ⚠️ | iOS has account deletion — verify Android |
| Settings loading animation | ⚠️ | iOS has linear progress with percentage — verify Android |

**Tasks**:
- [ ] 🎨 Match profile header layout (image, name, member since)
- [ ] 🎨 Match settings section cards and icons
- [ ] 🔧 Verify sign out clears SharedPreferences, Supabase session, Health Connect

### P1-11: Family Groups

**iOS Reference**: `Views/Profile/FamilyView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Invite code generation | ⚠️ | Verify Android generates codes same format as iOS |
| Join via code | ⚠️ | Verify Android join flow matches |
| Deep link join | ⚠️ | `swastricare://family/join?code=CODE` — verify Android handles |
| Member list | ⚠️ | Verify Android shows family members |
| Role-based access | ⚠️ | Both mark as "coming soon" — verify consistent |

**Tasks**:
- [ ] 🎨 Match family member card design
- [ ] 🔧 Verify deep link family join flow end-to-end

### P1-12: Lock Screen / Biometric

**iOS Reference**: `Views/Lock/LockScreenView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Glass design lock screen | ⚠️ | iOS has glass morphism lock screen — verify Android design |
| Biometric type label | ⚠️ | iOS shows "Face ID" or "Touch ID" — Android should show "Fingerprint" or "Face" |
| Unlock animation | ⚠️ | iOS has unlock transition animation — verify Android |
| Auto-lock on background | ✅ | Both implement ON_STOP lock |

**Tasks**:
- [ ] 🎨 Match lock screen visual design (glass background, icon, text)

### P1-13: Onboarding Flow

**iOS Reference**: `Views/Onboarding/OnboardingView.swift` + `OneQuestionPerScreenOnboardingView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Page count | ⚠️ | iOS has 3 pages (Track Health, AI, Vault) — Android has 4 pages (adds Family) — decide if aligning |
| RulerPicker for height | ✅ | Both have custom ruler picker |
| Weight slider | ⚠️ | iOS uses slider — verify Android input method |
| Gender options | ⚠️ | iOS: male/female/other/prefer not to say — verify Android matches |
| Skip option | ⚠️ | iOS has skip — verify Android |
| Setup loading animation | ⚠️ | iOS has `OnboardingSetupLoadingView` with gear pulse — verify Android |
| Progress indicator | ⚠️ | Verify step indicator design matches |

**Tasks**:
- [ ] 🎨 Match onboarding page illustrations/animations
- [ ] 🎨 Match questionnaire input field styles
- [ ] 🔧 Decide on 3 vs 4 onboarding pages

### P1-14: Health Analytics / Tracker

**iOS Reference**: `Views/Tracker/TrackerView.swift` + `HealthAnalyticsView.swift` + `HealthStreaksView.swift`

| Item | Status | Detail |
|------|--------|--------|
| Health analytics dashboard | ⚠️ | iOS has dedicated TrackerView — verify Android `HealthAnalyticsScreen` |
| Health streaks | ❌ | iOS has `HealthStreaksView.swift` for streak tracking — verify Android has equivalent |
| AI analysis requests | ⚠️ | iOS `TrackerViewModel` requests AI analysis — verify Android |
| Weekly data charts | ⚠️ | Verify chart types and styles match |

**Tasks**:
- [ ] 🔧 Implement health streaks if missing
- [ ] 🎨 Match analytics dashboard layout and chart styles

### P1-15: Notifications & Reminders

**iOS Reference**: `Services/NotificationService.swift` (62KB)

| Item | Status | Detail |
|------|--------|--------|
| Hydration smart reminders | ⚠️ | iOS has pattern-based timing — verify Android |
| Medication adherence-based timing | ⚠️ | iOS adjusts based on adherence — verify Android |
| Diet meal reminders | ⚠️ | iOS has breakfast/lunch/dinner reminders — verify Android |
| Cycle phase notifications | ⚠️ | Verify Android cycle reminders match iOS |
| Rich push with deep links | ⚠️ | iOS has rich notifications with actions — verify Android |
| Badge count management | 📱 | iOS uses badge counts — Android uses notification dots (platform difference, OK) |
| Sound customization | ⚠️ | Verify Android notification sounds |
| Quiet hours | ⚠️ | Verify Android respects quiet hours |
| Notification categories UI | ⚠️ | Verify Android settings match iOS categories |

**Tasks**:
- [ ] 🔧 Verify all 4 notification channels work end-to-end
- [ ] 🔧 Verify notification action buttons (log water, mark taken, log meal)
- [ ] 🔧 Verify boot receiver reschedules all alarms

### P1-16: Widgets

**iOS Reference**: 6 widgets (Hydration, Medication, Steps, Run, 2 Live Activities)

| Item | Status | Detail |
|------|--------|--------|
| Hydration Widget | ✅ | Both have it |
| Medication Widget | ✅ | Both have it |
| Steps Widget | ✅ | Both have it |
| Run Widget | ✅ | Both have it |
| Diet Widget | 📱 | Android has DietWidget — iOS doesn't (Android bonus) |
| Workout Live Activity | ❌ | iOS has real-time Live Activity widget — Android has no equivalent (use Foreground Notification instead) |
| Health Live Activity | ❌ | iOS has health metrics Live Activity — Android has no equivalent |
| Widget click deep links | ⚠️ | Verify all widget clicks navigate correctly |
| Widget data refresh | ⚠️ | Verify `WidgetDataManager` updates all widgets on data change |

**Tasks**:
- [ ] 🔧 Implement foreground notification with live workout stats (Android equivalent of Live Activity)
- [ ] 🔧 Verify all widget action receivers work
- [ ] 🎨 Match widget visual design with iOS widget style where possible

### P1-17: AR Body Scan

**iOS Reference**: `Views/AR/ARBodyScanView.swift` — Body pose detection with organ overlays

| Item | Status | Detail |
|------|--------|--------|
| Pose detection | ✅ | Both use ML Kit / Vision |
| Organ overlays | ⚠️ | iOS overlays organ icons on body — verify Android |
| Body measurements | ⚠️ | Verify Android calculates same measurements |

**Tasks**:
- [ ] 🎨 Match AR overlay design and icons

### P1-18: Deep Links

**iOS Reference**: `Helpers/DeepLinkHandler.swift`

| Item | Status | Detail |
|------|--------|--------|
| `home` | ✅ | Both handle |
| `hydration` | ✅ | Both handle |
| `medications` | ✅ | Both handle |
| `heartRate` / `heartrate` | ⚠️ | Verify case sensitivity |
| `steps` | ✅ | Both handle |
| `run` | ✅ | Both handle |
| `activeWorkout` | ⚠️ | iOS handles — verify Android |
| `startRun/{type}` | ⚠️ | iOS handles `startRun/walk`, `startRun/run`, etc. — verify Android `run/start?type=walk` format |
| `family/join?code=` | ✅ | Both handle |
| `diet` | 📱 | Android has — iOS doesn't (Android bonus) |
| `vault` | 📱 | Android has — iOS doesn't |
| `ai` | 📱 | Android has — iOS doesn't |

**Tasks**:
- [ ] 🔧 Verify all deep links work end-to-end from widget taps and notifications

---

## PHASE 2: UI/Design Polish (Match iOS Premium Feel)

### P2-1: Design System Alignment

| Item | iOS Value | Android Value | Match? |
|------|-----------|---------------|--------|
| Primary accent | `#4F46E5` (accentBlue) | `#5E5CE6` (PrimaryColor) | ⚠️ Slightly different |
| Success green | `#22C55E` | `#32D74B` | ⚠️ Different |
| Danger red | `#EF4444` | `#FF375F` | ⚠️ Different |
| Heart rate | Red semantic | `#FF3B30` | ⚠️ Check iOS exact hex |
| Steps | Green semantic | `#30D158` | ⚠️ Check |
| Hydration | Cyan semantic | `#00C7BE` | ⚠️ Check |
| Medication | `#5856D6` | `#5856D6` | ✅ Match |
| Glass blur | `.ultraThinMaterial` | Custom glass modifier | ⚠️ Verify visual similarity |
| Corner radius | Varies | Varies | ⚠️ Standardize |

**Tasks**:
- [ ] 🎨 **Align color palette** — Decide: use iOS exact hex values or keep platform-native colors
- [ ] 🎨 **Standardize corner radii** across all cards (iOS uses consistent values)
- [ ] 🎨 **Match glass morphism effect** — iOS uses `.ultraThinMaterial` with 0.5pt border stroke
- [ ] 🎨 **Match gradient definitions** — Compare `PremiumColor` gradients between platforms

### P2-2: Typography

- [ ] 🎨 Match font weights and sizes for headings, body, captions
- [ ] 🎨 iOS uses SF Pro (system) — Android uses Roboto (system) — ensure similar visual weight
- [ ] 🎨 Match text opacity values for secondary/tertiary text

### P2-3: Animations & Transitions

| Animation | iOS | Android | Status |
|-----------|-----|---------|--------|
| Tab switch spring | `.spring(0.3, 0.7)` | Unknown | ⚠️ Verify |
| Button press scale | 0.95x | Unknown | ⚠️ Verify |
| Shimmer loading | Diagonal sweep 1.5s | Unknown | ⚠️ Verify |
| Skeleton loaders | `SkeletonShape/Circle` | Unknown | ⚠️ Verify |
| Water wave fill | Custom `WaterWave` shape | ❌ Missing | ❌ |
| Typewriter text (AI) | Character-by-character | ⚠️ Verify | ⚠️ |
| Heartbeat pulse | Scale animation | ⚠️ Verify | ⚠️ |
| Section stagger enter | — | 80ms per section | ✅ Android has |
| Gradient background | Animated orbs | 8s loop gradient | ⚠️ Compare |
| Haptic feedback | On tab/button press | ⚠️ Verify | ⚠️ |

**Tasks**:
- [ ] 🎨 Implement water wave animation for hydration
- [ ] 🎨 Add shimmer/skeleton loading states if missing
- [ ] 🎨 Match button press feedback (scale + haptic)
- [ ] 🎨 Match animated gradient background between platforms
- [ ] 🎨 Add haptic feedback on interactions (tab switch, button press, toggle)

### P2-4: Component-Level UI Match

- [ ] 🎨 **GlassCard** — Match iOS glass card (blur, border, shadow, corner radius)
- [ ] 🎨 **PremiumButton** — Match iOS button styles (primary gradient, secondary outline, ghost)
- [ ] 🎨 **PremiumBackground** — Match iOS animated orb background
- [ ] 🎨 **HeroHeader** — Match iOS title + profile image header component
- [ ] 🎨 **QuestionnaireTextField** — Match iOS input with icon, clear button, focus ring
- [ ] 🎨 **ScaleButtonStyle** — Match iOS spring press animation
- [ ] 🎨 **NudgeCards** — Match iOS nudge card design (icon, message, action button, dismiss)
- [ ] 🎨 **CalorieProgressRing** — Match iOS circular progress (colors, stroke, center text)
- [ ] 🎨 **MacroBreakdownBar** — Match iOS stacked horizontal bar
- [ ] 🎨 **MealSectionCard** — Match iOS expandable meal section
- [ ] 🎨 **PremiumStepsCard** — Match iOS steps widget-style card
- [ ] 🎨 **WeekDateSelector** — Match iOS 7-day date picker

### P2-5: Screen-by-Screen UI Audit

For each screen, compare iOS vs Android layout and fix gaps:

- [ ] 🎨 Splash Screen (video + transition)
- [ ] 🎨 Onboarding pages (illustrations, text, indicators)
- [ ] 🎨 Consent screen (checkboxes, legal text, button)
- [ ] 🎨 Login/SignUp (input fields, social buttons, links)
- [ ] 🎨 Health profile questionnaire (each question screen)
- [ ] 🎨 Home dashboard (all sections, cards, spacing)
- [ ] 🎨 Hydration screen (progress, buttons, history)
- [ ] 🎨 Medications screen (timeline, cards, add form)
- [ ] 🎨 Diet screen (progress ring, macros, meal sections)
- [ ] 🎨 Heart rate screen (camera, waveform, results)
- [ ] 🎨 Run activity screen (stats, history, calendar)
- [ ] 🎨 Live workout screen (HUD, map, controls)
- [ ] 🎨 Workout summary (stats, splits, route)
- [ ] 🎨 Menstrual cycle (calendar, phases, tips)
- [ ] 🎨 Vault screen (documents, categories, upload)
- [ ] 🎨 AI chat (messages, mode switch, input)
- [ ] 🎨 Profile (header, stats, sections)
- [ ] 🎨 Settings (sections, toggles, links)
- [ ] 🎨 Family (members, invite, join)
- [ ] 🎨 Lock screen (biometric, glass design)
- [ ] 🎨 Force update screen
- [ ] 🎨 Health analytics dashboard

---

## PHASE 3: Production Hardening

### P3-1: Crash Prevention & Error Handling

- [ ] 🔧 Add try-catch around all Supabase network calls
- [ ] 🔧 Add null safety checks for Health Connect data
- [ ] 🔧 Handle camera permission denial gracefully (heart rate, AR)
- [ ] 🔧 Handle location permission denial gracefully (workout)
- [ ] 🔧 Handle Health Connect not installed / not available
- [ ] 🔧 Handle no internet connectivity (offline mode)
- [ ] 🔧 Handle Supabase session expiry and re-authentication
- [ ] 🔧 Handle Google Sign-In failures
- [ ] 🔧 Verify workout crash recovery works end-to-end
- [ ] 🔧 Add crash-safe SharedPreferences access (handle corruption)

### P3-2: Performance

- [ ] 🔧 Profile app startup time (target < 2s to interactive)
- [ ] 🔧 Optimize 3D model loading (SceneView/Filament)
- [ ] 🔧 Lazy load screens not in view
- [ ] 🔧 Optimize Health Connect queries (batch reads)
- [ ] 🔧 Optimize Supabase queries (pagination, caching)
- [ ] 🔧 Verify no memory leaks in camera (heart rate, AR)
- [ ] 🔧 Verify no memory leaks in location tracking
- [ ] 🔧 Test with low-end devices (2GB RAM, slow CPU)

### P3-3: Security

- [ ] 🔧 Verify Supabase anon key is NOT a service role key
- [ ] 🔧 Verify no sensitive data in SharedPreferences (only non-PII widget data)
- [ ] 🔧 Verify biometric prompt uses `BIOMETRIC_STRONG`
- [ ] 🔧 Verify Health Connect data permissions are minimal
- [ ] 🔧 Review ProGuard rules to not expose internal APIs
- [ ] 🔧 Verify deep link validation (no injection)
- [ ] 🔧 Verify document upload validates file types/sizes
- [ ] 🔧 Audit network traffic for sensitive data leaks (use HTTPS only)

### P3-4: Analytics & Monitoring

- [ ] 🔧 Verify Firebase Analytics events match iOS events
- [ ] 🔧 Verify Firebase Crashlytics captures all crashes
- [ ] 🔧 Verify Firebase Performance monitors key flows
- [ ] 🔧 Add custom analytics for: onboarding completion, feature adoption, retention signals
- [ ] 🔧 Verify `AppAnalyticsService` sends to Supabase correctly

---

## PHASE 4: Play Store Preparation

### P4-1: Store Listing

- [ ] 📱 App icon (adaptive icon with foreground + background layers)
- [ ] 📱 Feature graphic (1024x500)
- [ ] 📱 Screenshots (phone: 1080x1920 min, 8 screenshots recommended)
- [ ] 📱 Short description (80 chars max)
- [ ] 📱 Full description (4000 chars max)
- [ ] 📱 Privacy policy URL
- [ ] 📱 Terms of service URL
- [ ] 📱 Category selection (Health & Fitness)
- [ ] 📱 Content rating questionnaire
- [ ] 📱 Target audience declaration
- [ ] 📱 Data safety form (declare all data collection)

### P4-2: Health & Fitness Compliance

- [ ] 📱 Health Connect permission rationale (required by Google)
- [ ] 📱 Health data privacy policy (specific to health data handling)
- [ ] 📱 Medical disclaimer (app is not a medical device)
- [ ] 📱 Camera usage disclosure (heart rate measurement)
- [ ] 📱 Location usage disclosure (workout tracking)
- [ ] 📱 Background location justification (if using background location)

### P4-3: Technical Requirements

- [ ] 📱 64-bit APK/AAB support (already using Kotlin, should be fine)
- [ ] 📱 Target API 35 (already set)
- [ ] 📱 Generate signed AAB (Android App Bundle)
- [ ] 📱 Test on multiple screen sizes (phone, foldable, tablet)
- [ ] 📱 Test on Android 8.0 (API 26) through Android 15 (API 35)
- [ ] 📱 Test with different locales (English + Hindi at minimum for Indian audience)
- [ ] 📱 Verify app size is reasonable (< 100MB recommended)
- [ ] 📱 Set up Play App Signing

### P4-4: Testing Tracks

- [ ] 📱 Internal testing track (team testing)
- [ ] 📱 Closed testing track (beta users)
- [ ] 📱 Open testing track (public beta)
- [ ] 📱 Production release

---

## PHASE 5: Post-Launch Monitoring

### P5-1: Day-1 Monitoring

- [ ] 🔧 Monitor Firebase Crashlytics for crash-free rate (target > 99%)
- [ ] 🔧 Monitor Supabase for error rates
- [ ] 🔧 Monitor Health Connect integration errors
- [ ] 🔧 Monitor notification delivery rates
- [ ] 🔧 Monitor widget update reliability

### P5-2: Week-1 Tasks

- [ ] 🔧 Review user feedback/reviews
- [ ] 🔧 Fix any critical bugs discovered
- [ ] 🔧 Monitor retention and feature adoption analytics
- [ ] 🔧 Verify all deep links work from external sources
- [ ] 🔧 Verify in-app update flow works

---

## Task Summary for Agent Delegation

| Phase | Tasks | Priority | Est. Sessions |
|-------|-------|----------|---------------|
| P0: Critical Blockers | 12 | 🔴 Highest | 1-2 |
| P1: Feature Parity | 80+ | 🔴 High | 8-12 |
| P2: UI/Design Polish | 50+ | 🟡 Medium | 6-10 |
| P3: Production Hardening | 25+ | 🟡 Medium | 3-4 |
| P4: Play Store Prep | 20+ | 🟠 High | 2-3 |
| P5: Post-Launch | 10 | 🟢 Low | Ongoing |

**Total estimated tasks: ~200**
**Recommended delegation**: 1 phase per session, with P0 done first, then P1 features split by screen (1-2 features per agent session).

---

## Agent Session Delegation Plan

### Session 1: P0 — Critical Blockers
Fix all TODO items, build config, signing setup.

### Sessions 2-5: P1 — Feature Parity (split by feature group)
- **Session 2**: Home + Hydration + Medications (P1-1, P1-2, P1-3)
- **Session 3**: Diet + Heart Rate (P1-4, P1-5)
- **Session 4**: Run Activity + Menstrual Cycle + Analytics (P1-6, P1-7, P1-14)
- **Session 5**: Vault + AI + Family + Notifications (P1-8, P1-9, P1-11, P1-15)

### Sessions 6-8: P2 — UI Polish
- **Session 6**: Design system alignment + typography + colors (P2-1, P2-2)
- **Session 7**: Animations + component matching (P2-3, P2-4)
- **Session 8**: Screen-by-screen UI audit (P2-5)

### Session 9: P3 — Production Hardening
Error handling, performance, security.

### Session 10: P4 — Play Store Prep
Store listing, compliance, testing.
