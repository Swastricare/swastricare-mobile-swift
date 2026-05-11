# Android Family Feature — Redesign & Wiring

Date: 2026-05-11

## Goal

Make the Family feature reachable and functional on Android, with a redesigned screen that matches the new mock (clean white background, leaf illustration, "Better together" banner, member list with manage affordance).

## Current state

- Backend, Hilt-injected `FamilyRepository`, use cases (`CreateFamilyGroupUseCase`, `AcceptInvitationUseCase`, `GetFamilyMembersUseCase`, `InviteMemberUseCase`, `LeaveFamilyGroupUseCase`, `RemoveMemberUseCase`), `FamilyViewModel`, and the navigation route `"family"` are already in place.
- `FamilyScreen.kt` works but uses the old PrimaryColor (indigo) styling and lacks the new visuals.
- `SettingsScreen.kt:141-150` shows a "Coming soon" snackbar instead of calling the already-wired `onNavigateToFamily` callback.

## Changes

### 1. Settings entry

Replace the "Coming soon" snackbar with `onNavigateToFamily()`. Drop the `valueText = "Coming soon"`. No nav-graph changes — `MainNavGraph.kt:104` already routes `"family"` correctly.

### 2. FamilyScreen redesign

Single `Box` hosting:
- Pure white background (per memory: never `AppColors.background`).
- `background leaf illustration right.png` aligned bottom-end, behind content.
- A `LazyColumn` foreground.

**Header**: back arrow + "Family" title + subtitle "Manage your family members and their medications in one place." + add-user icon (trailing). Add-user opens invite bottom sheet (in-group) or scrolls to create/join card (no-group).

**"Better together" banner card** (always visible): 20dp rounded card with `AITeal.copy(alpha=0.08f)` background. Left: people icon + bold "Better together" + body "Add your loved ones and help them stay on track with their medications." Right: `family screen banner.png`.

#### In-group state (`uiState.familyGroup != null`)

- Section header: bold "Your Family" + trailing "Edit" link (only when `uiState.canManageMembers`). Tapping toggles local `editMode` state: rows then show a red trash icon and tapping fires `vm.showRemoveMemberDialog(member)`.
- Member rows: white card with light gray 1px border, 16dp radius. Avatar circle (initials in AITeal-tinted bg), full name, role display name subtitle, trailing chevron (or trash in edit mode). The current user's row gets a small "Primary" pill (AITeal background, white text, 11sp).
- Bottom CTA: outlined "+ Add Family Member" button → opens `InviteSheet` (Material3 `ModalBottomSheet`) showing big invite code, "Copy Link" + "New Code" actions, and at the bottom a tertiary destructive "Leave Group" text button.

#### No-group state (`uiState.familyGroup == null`)

Same banner + leaf illustration. Then two stacked cards:
1. **Create your family** card: TextField (group name), AITeal solid `Button` "Create Family Group" → `vm.createFamilyGroup(name)`.
2. **Join with invite code** card: code TextField + AITeal solid `Button` "Join Group" (calls existing `vm.joinWithCode()`).

### 3. ViewModel adjustments

Add `groupName: String = ""` field to `FamilyUiState`, plus `updateGroupName(name: String)` in `FamilyViewModel`. The `createFamilyGroup` flow already exists; just wire the input.

### 4. Color discipline

All accents = `AITeal` (#22C5A6). No gradients on buttons. Background pure white. Per project memory.

## Out of scope (deferred)

- Per-member next-dose subtitle (needs a new repository method to query medications via `has_family_access`).
- Bottom-nav "Family" tab — user wants entry only from Settings.

## Verification

Build `assembleDebug`, install to OnePlus 8T (`acac8d4b`), launch app, navigate Profile → Family, capture logcat for crashes.
