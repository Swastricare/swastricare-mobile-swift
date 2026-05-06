# iOS Settings — Android Parity Redesign

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the iOS Profile/Settings screen (`ProfileView.swift`) to mirror the Android `SettingsScreen.kt` UI 1:1 — same sections, profile banner with mountain illustration, card style, AITeal accents.

**Architecture:** Replace the current `List`-based `ProfileView` body with a `ScrollView`/`LazyVStack` rendering an Android-style header, profile banner, and grouped section cards. Keep `ProfileViewModel` unchanged (already exposes user, biometric, app version). Reuse existing destinations: `AccountView`, `FamilyView`, `HealthDataSettingsView`, `RemindersSettingsView` (notifications), `GoalsSettingsView` (activity goals), `ThemeSettingsView`, sheet-based `TermsContentView` / `PrivacyContentView`.

**Tech Stack:** SwiftUI, Swift Canvas API for the mountain backdrop, existing `DesignSystem.swift` tokens.

---

## Visual reference (Android)

Sections, in order:
1. **Title block** — "Settings" 28pt bold + "Manage your profile and preferences" 13pt 50% alpha (left-aligned, 20pt horizontal)
2. **Profile banner** — 96pt-tall card, gradient `#D9F0E4 → #C2E0EE`, mountains+sun canvas on the right, avatar (56pt), name, email, "Active for X days" badge with green dot, chevron. Tap → `AccountView`.
3. **ACCOUNT** card: Personal Information / Family (subtitle "Coming soon") / Health Data Sync
4. **PREFERENCES** card: Notifications / Activity Goals / Biometric Lock (toggle)
5. **SUPPORT** card: Contact Us (opens `https://swastricare.com`) / About (Version X)
6. **Log Out** card (red, full-width row)
7. **Footer** — Version X, "Terms of Service • Privacy Policy" (AITeal links)

Card style: `#FFFFFF` fill, 16pt corner radius, 1pt border `#E6E8EB`, 16pt horizontal screen padding.
Section labels: uppercase, 11pt semibold, 0.8pt letter-spacing, 40% black, 24pt left padding, 24pt top.
Row icon: 36pt rounded 10pt box, transparent bg, AITeal `#22C5A6` tint, 20pt symbol.
Row label: 15pt medium; subtitle: 12pt 50% alpha; chevron: 20pt 30% alpha; divider 0.5pt at 64pt left inset.

---

## Task 1 — Build the new SwiftUI screen

**Files:**
- Modify: `swastricare-mobile-swift/Views/Profile/ProfileView.swift` (full rewrite of `body` and helpers; keep `QuickStatCard` and `HealthProfileRow` if still referenced elsewhere)

**Step 1: Confirm `HealthProfileRow` / `QuickStatCard` external usage**

```bash
grep -rn "HealthProfileRow\|QuickStatCard" swastricare-mobile-swift --include="*.swift"
```
If only used inside `ProfileView.swift`, delete with the rewrite. If referenced in `SettingsView.swift` or elsewhere, keep them at the bottom of the file.

**Step 2: Rewrite `ProfileView`**

Replace the `body` with a `ScrollView { LazyVStack(spacing: 0) { ... } }` wrapped in `ZStack { Color.white.ignoresSafeArea(); ... }` (per memory rule: pure white bg, no `AppColors.background`).

Compose these private views (all inside `ProfileView.swift` for now):

- `titleBlock` — VStack leading-aligned, "Settings" + tagline
- `ProfileBannerCard` — 96pt rounded 20pt gradient card, with `MountainsBackdrop` Canvas pinned right (140pt wide), avatar + name + email + active-badge + chevron. Tap → `showAccountView = true`.
- `MountainsBackdrop` — `Canvas` drawing sun (`#FFE6A8`), back mountain (white 55%), front mountain (white 85%), snow cap (`#E9F5FA`), and a subtle horizon line.
- `SectionLabel(_ text: String)` — uppercase 11pt semibold 40% alpha, 24pt leading, 24pt top, 8pt bottom.
- `SettingsCard<Content>` — VStack with white fill, 1pt `#E6E8EB` border, 16pt radius, 16pt horizontal screen padding.
- `SettingsRow` — icon badge + label + optional subtitle + optional value text + chevron, full-width tap target. 14pt horizontal / 12pt vertical padding.
- `SettingsToggleRow` — icon badge + label + `Toggle` (AITeal track when on). 14pt horizontal / 8pt vertical padding.
- `LogOutRow` — red icon badge (10% red bg, full red icon), red label, optional `ProgressView` while loading.
- `RowDivider` — 0.5pt 6%-alpha black divider, 64pt leading inset.
- `IconBadge` — 36pt 10pt-rounded box; default transparent bg, AITeal tint.
- `FooterLinks` — version + bullet-separated Terms / Privacy buttons (AITeal text).

**Wiring:**
- Personal Information row → `showAccountView = true`
- Family row → present a tiny bottom alert/snackbar saying "Family — coming soon" (Android uses snackbar; iOS can use `.alert` or simply route to `FamilyView` when ready). For parity right now: show an alert with title "Family" / message "Coming soon".
- Health Data Sync → `NavigationLink { HealthDataSettingsView() }`
- Notifications → `NavigationLink { RemindersSettingsView() }`
- Activity Goals → `NavigationLink { GoalsSettingsView() }`
- Biometric Lock toggle → `viewModel.toggleBiometric()` (existing async)
- Contact Us → `UIApplication.shared.open(URL(string: "https://swastricare.com")!)`
- About → alert "About — coming soon" (Android shows snackbar)
- Log Out → `viewModel.showSignOutConfirmation = true` (existing)
- Terms / Privacy → `activeSheet = .terms` / `.privacy` (existing sheet enum already present)

**Keep:**
- `.alert("Sign Out", ...)`, `.alert("Delete Account", ...)`, `.alert("Error", ...)` blocks
- `.sheet(item: $activeSheet)` for terms/privacy/hydrationSettings/appUpdate
- `.onReceive(NotificationCenter.default.publisher(for: .deepLinkFamilyJoin))` and `showFamilyFromDeepLink` navigation
- `.trackScreen("Profile")`

**Drop (no longer in the new design):**
- `phoneMissingBanner` (Android settings doesn't show it)
- `quickStatsSection` (height/weight/BMI grid — Android moved these into the Personal Info screen)
- `hydrationSection` (replaced by Health Data Sync entry; hydration prefs still reachable from notifications/reminders)
- `signOutSection` "Delete Account" row (Android only has Log Out at this level; delete account stays accessible via Account/Personal Info screen)
- Old `settingsSection`, `appVersionRow`, `versionFooter` (replaced by new `FooterLinks` and the About row)

**Step 3: Build for the iPhone simulator to type-check**

Run:
```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build -quiet 2>&1 | tail -40
```
Expected: `** BUILD SUCCEEDED **`. Fix any compile errors.

**Step 4: Install on physical iPhone and launch**

Per saved feedback (auto-install on iPhone after UI edits, device id `FEC4D85A-...`):
```bash
xcodebuild -scheme swastricare-mobile-swift -destination 'id=FEC4D85A-...' -configuration Debug build install 2>&1 | tail -20
```
(Confirm exact device id from `xcrun devicectl list devices` if needed.)

**Step 5: Visual QA checklist**

- [ ] Pure white background everywhere on the screen
- [ ] Banner gradient + mountains render correctly on small (iPhone SE) and large (Pro Max) widths
- [ ] AITeal `#22C5A6` icon tint on every Account/Preferences/Support row
- [ ] Card border `#E6E8EB`, 16pt radius
- [ ] Section label kerning and uppercase casing matches Android
- [ ] Tapping each row navigates to the correct destination
- [ ] Biometric toggle reflects state and calls into `ProfileViewModel.toggleBiometric`
- [ ] Log Out shows confirmation alert and signs out

**Step 6: Commit**

```bash
git add swastricare-mobile-swift/Views/Profile/ProfileView.swift
git commit -m "feat(ios): port Android settings UI to iOS Profile tab"
```

---

## Task 2 — Cleanup (only if Task 1 left dead code)

**Files:**
- Modify or delete: `Views/Settings/SettingsView.swift` if it referenced the now-removed Profile sub-views.

**Step 1: Search for orphaned references**

```bash
grep -rn "QuickStatCard\|HealthProfileRow\|hydrationSection\|phoneMissingBanner" swastricare-mobile-swift --include="*.swift"
```

**Step 2: If `SettingsView.swift` is now unused, leave it alone (project-wide cleanup is out of scope). If it fails to compile, restore the structs in `ProfileView.swift` at the bottom.**

**Step 3: Re-run the build** to confirm no regressions.

**Step 4: Commit any cleanup separately** if needed.

---

## Out of scope

- Refactoring `ProfileViewModel`
- New destinations (Family screen UX, About screen)
- Snackbar component (use SwiftUI alert as parity stand-in)
- Renaming the tab from "Profile"

## Notes for the implementer

- Use `Color(hex:)` from `DesignSystem.swift` for all hex colors. Don't hardcode raw `Color(red:green:blue:)`.
- Follow `feedback_white_background.md`: never use `AppColors.background`.
- Follow `feedback_no_gradient_buttons.md`: rows are tap targets, not styled buttons; the banner gradient is on the card background, which is fine.
- Use `.poppins(...)` font helpers (already used throughout the file).
- The Android screen's iconography uses `Icons.Outlined.*` (Material). Use the closest SF Symbol: `person`, `person.2`, `heart`, `bell`, `flag`, `faceid`/`touchid` (use `viewModel.biometricIcon`), `bubble.left.and.text.bubble.right`, `info.circle`, `rectangle.portrait.and.arrow.right`.
