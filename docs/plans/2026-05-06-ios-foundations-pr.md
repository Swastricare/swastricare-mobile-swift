# iOS Foundations PR — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Land the foundations every Android-parity screen port depends on — Poppins typography, AITeal color token, forced light theme, brand rename to "Swastri AI", and asset import.

**Architecture:** Modify `DesignSystem.swift` for color tokens; add `Font+Poppins.swift` for typography; copy Poppins TTFs into `Resources/Fonts/` and register via `INFOPLIST_KEY_UIAppFonts` build setting (the project uses auto-generated `Info.plist`); override `preferredColorScheme(.light)` at root in `swastricare_mobile_swiftApp.swift`; sweep brand strings; copy `signup_brand_header.png` into `Assets.xcassets`.

**Tech Stack:** SwiftUI, Xcode 15+ auto-generated Info.plist via `INFOPLIST_KEY_*`, `fileSystemSynchronizedGroups` (per CLAUDE.md, new files auto-discovered).

**Constraints:**
- No automated tests in this project (per CLAUDE.md). Verification = `xcodebuild` compile + manual visual check on simulator.
- No commits per user instruction. Each task ends staged for review.
- SourceKit "cannot find X in scope" warnings are false positives — trust `xcodebuild` output.

---

### Task 1: Copy Poppins TTFs into iOS Resources

**Files:**
- Source: `android/app/src/main/res/font/poppins_{bold,semibold,medium,regular,light}.ttf`
- Destination: `swastricare-mobile-swift/Resources/Fonts/`

**Step 1: Create the Fonts directory**

```bash
mkdir -p swastricare-mobile-swift/Resources/Fonts
```

**Step 2: Copy fonts (rename to PascalCase to match conventional iOS font filenames)**

```bash
cp android/app/src/main/res/font/poppins_bold.ttf swastricare-mobile-swift/Resources/Fonts/Poppins-Bold.ttf
cp android/app/src/main/res/font/poppins_semibold.ttf swastricare-mobile-swift/Resources/Fonts/Poppins-SemiBold.ttf
cp android/app/src/main/res/font/poppins_medium.ttf swastricare-mobile-swift/Resources/Fonts/Poppins-Medium.ttf
cp android/app/src/main/res/font/poppins_regular.ttf swastricare-mobile-swift/Resources/Fonts/Poppins-Regular.ttf
cp android/app/src/main/res/font/poppins_light.ttf swastricare-mobile-swift/Resources/Fonts/Poppins-Light.ttf
```

**Step 3: Verify**

```bash
ls swastricare-mobile-swift/Resources/Fonts/
```

Expected: 5 files. The Xcode project uses `fileSystemSynchronizedGroups` so they'll auto-include.

**Step 4: Stage for review (no commit)**

```bash
git add swastricare-mobile-swift/Resources/Fonts/
git status
```

---

### Task 2: Register fonts in Info.plist via build setting

The project has `GENERATE_INFOPLIST_FILE = YES`. Adding `UIAppFonts` requires `INFOPLIST_KEY_UIAppFonts` build settings entries OR adding the keys to a custom Info.plist. Use build settings to avoid creating a new plist file.

**Files:**
- Modify: `swastricare-mobile-swift.xcodeproj/project.pbxproj` (the app target's Debug + Release `buildSettings` blocks; do NOT touch the Widget target's blocks)

**Step 1: Find the app target's buildSettings**

```bash
grep -n "GENERATE_INFOPLIST_FILE = YES" swastricare-mobile-swift.xcodeproj/project.pbxproj
```

Identify which `GENERATE_INFOPLIST_FILE` lines belong to the app target (not the Widget — those have `INFOPLIST_FILE = SwasthiCareWidgets/Info.plist`). Read ~30 lines around each match to disambiguate.

**Step 2: Add `INFOPLIST_KEY_UIAppFonts` to both Debug and Release buildSettings of the app target**

Right below `GENERATE_INFOPLIST_FILE = YES;`, insert (matching the existing indentation — typically tab+tab+tab):

```
				INFOPLIST_KEY_UIAppFonts = (
					"Resources/Fonts/Poppins-Bold.ttf",
					"Resources/Fonts/Poppins-SemiBold.ttf",
					"Resources/Fonts/Poppins-Medium.ttf",
					"Resources/Fonts/Poppins-Regular.ttf",
					"Resources/Fonts/Poppins-Light.ttf",
				);
```

Note: `INFOPLIST_KEY_UIAppFonts` paths are relative to bundle resources root. With `fileSystemSynchronizedGroups`, files in `Resources/Fonts/` ship at the same relative path inside the bundle.

**Step 3: Compile-check**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -30
```

Expected: `BUILD SUCCEEDED`.

**Step 4: Runtime verify fonts load (simulator)**

After build, launch on simulator (or use a temporary print in `App.init()`):

```swift
for family in UIFont.familyNames.sorted() where family.contains("Poppins") {
    print("Family: \(family) — names: \(UIFont.fontNames(forFamilyName: family))")
}
```

Expected output includes `Poppins-Bold`, `Poppins-SemiBold`, `Poppins-Medium`, `Poppins-Regular`, `Poppins-Light`. Remove the print after verifying.

**Step 5: Stage**

```bash
git add swastricare-mobile-swift.xcodeproj/project.pbxproj
git status
```

---

### Task 3: Add `Font+Poppins.swift` extension mirroring Android Type.kt tokens

**Files:**
- Reference: `android/app/src/main/kotlin/com/swastricare/health/ui/theme/Type.kt`
- Create: `swastricare-mobile-swift/Core/Font+Poppins.swift`

**Step 1: Read Android Type.kt for exact size/weight tokens**

```bash
cat android/app/src/main/kotlin/com/swastricare/health/ui/theme/Type.kt
```

Capture the size/weight pairs for: `displayLarge`, `displayMedium`, `displaySmall`, `headlineLarge`, `headlineMedium`, `headlineSmall`, `titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelMedium`, `labelSmall`.

**Step 2: Create `Font+Poppins.swift` with matching tokens**

```swift
//
//  Font+Poppins.swift
//  swastricare-mobile-swift
//
//  Mirrors Android Type.kt — Poppins token system for cross-platform parity.
//

import SwiftUI

extension Font {
    enum Poppins {
        case bold, semiBold, medium, regular, light

        var fontName: String {
            switch self {
            case .bold: return "Poppins-Bold"
            case .semiBold: return "Poppins-SemiBold"
            case .medium: return "Poppins-Medium"
            case .regular: return "Poppins-Regular"
            case .light: return "Poppins-Light"
            }
        }
    }

    static func poppins(_ weight: Poppins, size: CGFloat) -> Font {
        .custom(weight.fontName, size: size)
    }

    // Android Type.kt token parity. Sizes copied exactly from Type.kt.
    static let pDisplayLarge   = Font.custom("Poppins-Bold",     size: 57)
    static let pDisplayMedium  = Font.custom("Poppins-Bold",     size: 45)
    static let pDisplaySmall   = Font.custom("Poppins-SemiBold", size: 36)
    static let pHeadlineLarge  = Font.custom("Poppins-SemiBold", size: 32)
    static let pHeadlineMedium = Font.custom("Poppins-SemiBold", size: 28)
    static let pHeadlineSmall  = Font.custom("Poppins-SemiBold", size: 24)
    static let pTitleLarge     = Font.custom("Poppins-SemiBold", size: 22)
    static let pTitleMedium    = Font.custom("Poppins-Medium",   size: 16)
    static let pTitleSmall     = Font.custom("Poppins-Medium",   size: 14)
    static let pBodyLarge      = Font.custom("Poppins-Regular",  size: 16)
    static let pBodyMedium     = Font.custom("Poppins-Regular",  size: 14)
    static let pBodySmall      = Font.custom("Poppins-Regular",  size: 12)
    static let pLabelLarge     = Font.custom("Poppins-Medium",   size: 14)
    static let pLabelMedium    = Font.custom("Poppins-Medium",   size: 12)
    static let pLabelSmall     = Font.custom("Poppins-Medium",   size: 11)
}
```

**Important:** before finalizing this file, replace the size constants with the ACTUAL values pulled from Android `Type.kt` in Step 1 — sizes shown above are Material 3 defaults and may differ.

**Step 3: Compile-check**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`.

**Step 4: Stage**

```bash
git add swastricare-mobile-swift/Core/Font+Poppins.swift
git status
```

---

### Task 4: Apply Poppins app-wide via UIKit appearance + sweep `.font(...)` call sites

UIKit-bridged SwiftUI `Text` won't pick up custom fonts globally without explicit application. Strategy: replace `.font(.system(...))`, `.font(.title)`, `.font(.headline)`, `.font(.body)`, `.font(.caption)` etc. across all view files with the Poppins tokens.

**Files:**
- Modify: every file under `swastricare-mobile-swift/Views/` that uses system font tokens
- Modify: any `Components/` files using system fonts

**Step 1: Inventory call sites**

```bash
grep -rn "\.font(\.system\|\.font(\.title\|\.font(\.headline\|\.font(\.body\|\.font(\.subheadline\|\.font(\.caption\|\.font(\.callout\|\.font(\.footnote\|\.font(\.largeTitle" swastricare-mobile-swift/Views/ swastricare-mobile-swift/swastricare-mobile-swift/Components 2>/dev/null | wc -l
```

Note the count — this is the work surface.

**Step 2: Build a mapping table from system → Poppins**

| System | Poppins replacement |
|---|---|
| `.font(.largeTitle)` | `.font(.pDisplaySmall)` |
| `.font(.title)` | `.font(.pHeadlineSmall)` |
| `.font(.title2)` | `.font(.pTitleLarge)` |
| `.font(.title3)` | `.font(.pTitleMedium)` |
| `.font(.headline)` | `.font(.pTitleMedium)` |
| `.font(.body)` | `.font(.pBodyLarge)` |
| `.font(.callout)` | `.font(.pBodyMedium)` |
| `.font(.subheadline)` | `.font(.pBodyMedium)` |
| `.font(.footnote)` | `.font(.pBodySmall)` |
| `.font(.caption)` | `.font(.pLabelMedium)` |
| `.font(.caption2)` | `.font(.pLabelSmall)` |
| `.font(.system(size: N, weight: .bold))` | `.font(.poppins(.bold, size: N))` |
| `.font(.system(size: N, weight: .semibold))` | `.font(.poppins(.semiBold, size: N))` |
| `.font(.system(size: N, weight: .medium))` | `.font(.poppins(.medium, size: N))` |
| `.font(.system(size: N))` | `.font(.poppins(.regular, size: N))` |

**Step 3: Sweep file-by-file**

Do NOT bulk-sed — call sites have nuance (size-only `.system(size:)` needs explicit weight). Process each file with Edit, verifying readability of the resulting code. Group related files into commits sized for review.

Suggested order: shared `Components/` first (highest reuse), then `Views/Home/`, `Views/Auth/`, `Views/Onboarding/`, `Views/Settings/`, `Views/Profile/`, `Views/Vault/`, `Views/Run/`, `Views/HeartRate/`, `Views/MenstrualCycle/`, `Views/AI/`, `Views/AR/`, `Views/Tracker/`, `Views/Splash/`, `Views/Lock/`, `Views/Main/`.

**Step 4: Compile after each group**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

**Step 5: Visual spot-check on simulator**

Launch the app, navigate Home → Settings → AI tab. Confirm typography is Poppins (recognizable rounded geometry vs SF Pro). If anything looks like SF Pro, find missed call sites with grep.

**Step 6: Stage**

```bash
git add -u swastricare-mobile-swift/Views swastricare-mobile-swift/swastricare-mobile-swift/Components 2>/dev/null
git status
```

---

### Task 5: Add `aiTeal` + Android-side semantic colors to `DesignSystem.swift`

**Files:**
- Reference: `android/app/src/main/kotlin/com/swastricare/health/ui/theme/Color.kt`
- Modify: `swastricare-mobile-swift/DesignSystem.swift`

**Step 1: Read Android Color.kt**

```bash
cat android/app/src/main/kotlin/com/swastricare/health/ui/theme/Color.kt
```

Identify all Android-side color tokens not already present in iOS `AppColors`. Specifically look for: `AITeal`, drink-type colors (water, coffee, tea, juice, milk), activity ring colors, sleep stage colors (deep/light/REM/awake), stress mood colors.

**Step 2: Add missing tokens to `AppColors`**

In `DesignSystem.swift`, inside the `struct AppColors`, after the existing `accentRed` block, add:

```swift
// Android parity tokens — added 2026-05-06
static let aiTeal = Color(hex: "22C5A6")
static let aiTealLight = Color(hex: "5BD9C0")
static let aiTealDark = Color(hex: "1A9E85")

// Drink-type tints (mirror Android HydrationScreen palettes)
static let drinkWater = Color(hex: "0EA5E9")
static let drinkCoffee = Color(hex: "78350F")
static let drinkTea = Color(hex: "65A30D")
static let drinkJuice = Color(hex: "F97316")
static let drinkMilk = Color(hex: "FAFAF9")

// Sleep stages (mirror Android SleepScreen)
static let sleepAwake = Color(hex: "F59E0B")
static let sleepRem = Color(hex: "8B5CF6")
static let sleepLight = Color(hex: "60A5FA")
static let sleepDeep = Color(hex: "1E3A8A")
```

**Important:** before finalizing, replace each hex with the exact value found in Android `Color.kt` from Step 1. The values above are placeholders for tokens that may differ.

Add a matching gradient if Android defines one for AI:

```swift
extension PremiumColor {
    static let aiTeal = LinearGradient(
        colors: [Color(hex: "22C5A6"), Color(hex: "5BD9C0")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
```

**Step 3: Compile-check**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

**Step 4: Stage**

```bash
git add swastricare-mobile-swift/DesignSystem.swift
git status
```

---

### Task 6: Force light theme at root

**Files:**
- Modify: `swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift:183`

**Step 1: Read current modifier**

```bash
grep -n "preferredColorScheme" swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift
```

Current: `.preferredColorScheme(themeManager.colorScheme)` at line 183.

**Step 2: Replace with hardcoded light**

Edit line 183 from:

```swift
.preferredColorScheme(themeManager.colorScheme)
```

to:

```swift
.preferredColorScheme(.light) // Android parity: forced light mode (mirrors Android `darkTheme = false`)
```

Leave `ThemeManager` itself intact (Settings UI still navigates to it; we'll repaint Settings during the Settings PR).

**Step 3: Compile-check**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

**Step 4: Visual verify**

Launch simulator with system appearance set to dark. App should render in light theme regardless. Confirm with: Settings → Developer → Dark Appearance → ON, then relaunch app.

**Step 5: Stage**

```bash
git add swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift
git status
```

---

### Task 7: Brand sweep — "SwasthiCare" / "SwasthiCare" → "Swastri AI"

The display name and user-facing copy needs to read "Swastri AI". Bundle ID and class names stay as-is.

**Files:**
- Modify: any `.swift` view file containing user-facing strings with old brand
- Modify: `swastricare-mobile-swift/PrivacyInfo.plist` (already says "SwastriCare", needs to become "Swastri AI" in user-facing permission strings)
- Build setting: `INFOPLIST_KEY_CFBundleDisplayName`

**Step 1: Inventory hits**

```bash
grep -rn "SwasthiCare\|SwastriCare\|Swasthi " swastricare-mobile-swift/ --include="*.swift" --include="*.plist" --include="*.strings" 2>/dev/null
```

**Step 2: Categorize each hit**

For each result, decide:
- **User-facing text** (Text(), navigation titles, alerts, plist permission descriptions) → rename to "Swastri AI"
- **Class names, file names, module names, comments** → leave alone
- **Bundle ID** (`com.swasthicare.*`) → leave alone

**Step 3: Edit user-facing hits**

Use Edit per file. For the permission descriptions in `PrivacyInfo.plist`, edit to say "Swastri AI" instead of "SwastriCare".

**Step 4: Set display name via build setting**

In `swastricare-mobile-swift.xcodeproj/project.pbxproj`, in both Debug and Release `buildSettings` for the app target (NOT the widget), add:

```
				INFOPLIST_KEY_CFBundleDisplayName = "Swastri AI";
```

Place it next to the `INFOPLIST_KEY_UIAppFonts` block from Task 2.

**Step 5: Compile + relaunch**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

Reinstall on sim — home screen icon label should now read "Swastri AI".

**Step 6: Stage**

```bash
git add -u swastricare-mobile-swift/ swastricare-mobile-swift.xcodeproj/project.pbxproj
git status
```

---

### Task 8: Import `signup_brand_header` PNG into Assets.xcassets

**Files:**
- Source: `android/app/src/main/res/drawable-nodpi/signup_brand_header.png` (or wherever it lives — verify in Step 1)
- Destination: `swastricare-mobile-swift/Assets.xcassets/SignupBrandHeader.imageset/`

**Step 1: Locate the source PNG**

```bash
find android/app/src/main/res -name "signup_brand_header*" 2>/dev/null
```

**Step 2: Create imageset structure**

```bash
mkdir -p swastricare-mobile-swift/Assets.xcassets/SignupBrandHeader.imageset
cp <path-found-above> swastricare-mobile-swift/Assets.xcassets/SignupBrandHeader.imageset/signup_brand_header.png
```

**Step 3: Create `Contents.json`**

Write `swastricare-mobile-swift/Assets.xcassets/SignupBrandHeader.imageset/Contents.json`:

```json
{
  "images" : [
    {
      "filename" : "signup_brand_header.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

(Single-resolution PNG used as 1x. Acceptable for now; revisit if pixelation appears on @3x devices — at that point export @2x/@3x from Figma.)

**Step 4: Compile-check**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

**Step 5: Stage**

```bash
git add swastricare-mobile-swift/Assets.xcassets/SignupBrandHeader.imageset
git status
```

---

### Task 9: Final foundation validation

**Step 1: Full clean build**

```bash
xcodebuild clean -scheme swastricare-mobile-swift -sdk iphonesimulator
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. Any warning about missing fonts means UIAppFonts entry is wrong.

**Step 2: Widget extension build**

```bash
xcodebuild -scheme SwasthiCareWidgetsExtension -configuration Debug build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`. (Color tokens live on the main target; widgets shouldn't break, but verify.)

**Step 3: Manual smoke test on simulator**

Launch app on iPhone 15 simulator (or default sim). Navigate:
- Splash / Onboarding / Auth → text uses Poppins, no SF Pro fallback
- Home tab → light theme even with sim system in dark
- Settings → all sections render
- AI tab → renders unchanged (it's the source)
- Force-quit and relaunch → display name reads "Swastri AI" on home screen

**Step 4: Snapshot a status report**

```bash
git status
```

Verify all expected files are staged:
- `swastricare-mobile-swift/Resources/Fonts/Poppins-*.ttf` (5 files)
- `swastricare-mobile-swift/Core/Font+Poppins.swift`
- `swastricare-mobile-swift/DesignSystem.swift`
- `swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift`
- `swastricare-mobile-swift/Assets.xcassets/SignupBrandHeader.imageset/...`
- `swastricare-mobile-swift.xcodeproj/project.pbxproj`
- `swastricare-mobile-swift/PrivacyInfo.plist`
- Many files under `swastricare-mobile-swift/Views/` (font sweep)

**Step 5: Hand off to user — DO NOT commit**

Report what changed, what to spot-check, and wait for user direction before any commit.

---

## Out of scope (next PRs)

- Home V3 redesign — separate PR
- Auth/Onboarding redesign — separate PR
- All other screen ports — separate PRs

## Open decisions for user (before starting Task 1)

1. Confirm the font sweep in Task 4 is acceptable — it touches every view file. Alternative: leave `.font(.system)` in non-redesigned screens and only apply Poppins on redesigned screens. Recommendation: do full sweep now to keep typography consistent.
2. Confirm `INFOPLIST_KEY_*` build-setting approach for fonts/display name (vs creating a real `Info.plist`). Recommendation: build settings — non-invasive.
