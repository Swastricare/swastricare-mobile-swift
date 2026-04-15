# Android Light Theme Color Update — Design

**Date:** 2026-04-14  
**Scope:** Android only — light mode only

## Problem

The current light theme uses pure white (`#FFFFFF`) for both screen backgrounds and card surfaces, making screens feel flat with no visual hierarchy between page background and card content.

## Goal

Introduce a three-token light mode color system with subtle off-white backgrounds so cards visually lift off the page.

## Color Tokens

| Token | Hex | Role |
|---|---|---|
| Main Background | `#F6F7F9` | Screen/page background (off-white) |
| Card Background | `#FFFFFF` | Card / sheet surface (pure white) |
| Soft Card Shadow / Divider | `#E6E8EB` | Borders, dividers, card outlines |

Dark mode: **unchanged**.

## Changes (Option B — Theme tokens + AppColors)

### `ui/theme/Color.kt`

1. `BackgroundLight`: `0xFFFFFFFF` → `0xFFF6F7F9`
2. `SurfaceLight`: unchanged (`0xFFFFFFFF`)
3. Add `DividerLight = Color(0xFFE6E8EB)`
4. `AppColors.cardBorder` (light): `Color.Black.copy(alpha = 0.3f)` → `DividerLight`
5. Add `AppColors.divider`: light → `DividerLight`, dark → `Color(0xFF3C3C3E)`

### `ui/theme/Theme.kt`

No changes needed — `LightColorScheme` already references `BackgroundLight` and `SurfaceLight`.

## Cascade Coverage

- Screens using `MaterialTheme.colorScheme.background` → automatically get `#F6F7F9`
- Screens using `MaterialTheme.colorScheme.surface` → stay `#FFFFFF`
- Screens using `AppColors.cardBorder` → automatically get `#E6E8EB`

## Out of Scope

- Hardcoded `Color.White` / `Color(0xFFFFFFFF)` raw values in individual screens — these are a separate follow-up pass
- Onboarding, splash, auth, live workout — use intentional dark/gradient backgrounds, should not be touched
- Feature-specific tinted card colors (hydration cyan, medication purple, etc.)
