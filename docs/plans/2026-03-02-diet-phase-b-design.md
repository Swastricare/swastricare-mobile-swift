# DietView Phase B — Food Search UX + Database Expansion

## Date: 2026-03-02

## Summary

Revamp AddFoodView with unified food discovery (recent, favorites, category browsing, search), add quantity adjustment before logging, implement heart-icon favorites, and expand the Indian food database by ~100 items.

## 1. Revamped AddFoodView

Replace current two-button layout with unified food discovery screen:

- Search bar at top (.searchable modifier)
- Recent Foods: horizontal scroll of compact food chips (last 10 unique logged foods)
- Favorites: horizontal scroll (only if favorites exist), toggled via heart icon
- Browse by Category: 3x3 LazyVGrid of 9 category tiles (emoji + name), tap opens filtered FoodSearchView
- "Add Custom Food" button at bottom
- Meal type shown as pill in toolbar

Tapping food from Recent/Favorites opens quantity sheet directly. Tapping category opens FoodSearchView filtered to that category.

## 2. Quantity Adjustment Sheet

New sheet after selecting any food:

- Food name + category emoji
- Serving info display
- Quantity stepper (0.5 increments, range 0.5–10)
- Live nutrition preview (calories, protein, carbs, fat — multiplied by quantity)
- Meal type selector (pre-filled from context)
- "Log Food" button

Replaces current behavior of logging default quantity immediately.

## 3. Favorites Storage

- `favoriteFoodIds: Set<UUID>` in UserDefaults (local-only)
- Heart icon toggle on FoodItemRow in search and recent
- DietViewModel methods: `toggleFavorite(foodId:)`, `isFavorite(foodId:) -> Bool`
- No Supabase sync

## 4. Recent Foods

- Computed from existing `dietLogs` — unique food names/IDs from last 20 logs
- `DietViewModel.recentFoods: [FoodItem]` computed property
- No new storage

## 5. Food Database Expansion

New Supabase migration adding ~100 Indian foods across categories:

- South Indian: uttapam, pongal, vada, appam, puttu, avial, rasam, sambar rice
- North Indian: chole bhature, rajma chawal, dal makhani, aloo paratha, stuffed kulcha
- Bengali: fish curry, mishti doi, sandesh, luchi
- Gujarati: dhokla, thepla, undhiyu, khandvi
- Street food: pav bhaji, pani puri, bhel puri, sev puri, kachori, aloo tikki
- Restaurant mains: biryani variants, butter chicken, palak paneer, kadhai paneer, tandoori chicken
- Modern/healthy: oats upma, quinoa khichdi, protein shake, smoothie bowl, sprouts salad
- Beverages: filter coffee, masala chai, buttermilk, jaljeera, aam panna

## Files Modified

| File | Change |
|------|--------|
| Views/Home/AddFoodView.swift | Full rewrite — search + recent + favorites + categories |
| Views/Home/FoodSearchView.swift | Add heart icon for favorites on food rows |
| ViewModels/DietViewModel.swift | Add recentFoods, favorite methods, quantity-aware logFood |
| supabase/migrations/ | New migration seeding ~100 more foods |
