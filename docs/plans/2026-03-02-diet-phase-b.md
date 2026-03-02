# DietView Phase B — Food Search UX + Database Expansion

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Revamp AddFoodView with unified food discovery (recent, favorites, category browsing, search), add quantity adjustment before logging, and expand the Indian food database by ~100 items.

**Architecture:** Add favorites (UserDefaults) and recent foods (computed from dietLogs) to DietViewModel, rewrite AddFoodView as a discovery hub with sections, add a quantity sheet before logging, add heart-icon favorites to FoodSearchView rows, and seed ~100 more Indian foods via a new Supabase migration.

**Tech Stack:** SwiftUI, UserDefaults, Supabase SQL migration

---

### Task 1: Add favorites and recent foods to DietViewModel

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/DietViewModel.swift`

**Step 1: Add favorites storage and recent foods computed property**

Add these properties and methods to `DietViewModel`:

```swift
// Below existing @Published properties (after line 28)
@Published var favoriteFoodIds: Set<String> = []

// In init, load favorites from UserDefaults
// After self.localStorage = localStorage (line 87):
self.favoriteFoodIds = Set(UserDefaults.standard.stringArray(forKey: "favoriteFoodIds") ?? [])
```

Add computed property for recent foods (after `searchFoods` method, ~line 274):

```swift
/// Recent foods from last 20 logged entries (unique by name)
var recentFoods: [FoodItem] {
    var seen = Set<String>()
    var result: [FoodItem] = []

    let sortedLogs = dietLogs.sorted { $0.loggedAt > $1.loggedAt }

    for log in sortedLogs {
        guard !seen.contains(log.foodName) else { continue }
        seen.insert(log.foodName)

        // Try to find matching FoodItem in cache
        if let item = foodItemsCache.first(where: { $0.name == log.foodName }) {
            result.append(item)
        }

        if result.count >= 10 { break }
    }

    return result
}

/// Favorite food items resolved from cache
var favoriteFoods: [FoodItem] {
    foodItemsCache.filter { favoriteFoodIds.contains($0.id.uuidString) }
}

/// Toggle favorite status for a food item
func toggleFavorite(foodId: UUID) {
    let idString = foodId.uuidString
    if favoriteFoodIds.contains(idString) {
        favoriteFoodIds.remove(idString)
    } else {
        favoriteFoodIds.insert(idString)
    }
    UserDefaults.standard.set(Array(favoriteFoodIds), forKey: "favoriteFoodIds")
}

/// Check if a food item is favorited
func isFavorite(foodId: UUID) -> Bool {
    favoriteFoodIds.contains(foodId.uuidString)
}
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/DietViewModel.swift
git commit -m "feat(diet): add favorites storage and recent foods to DietViewModel"
```

---

### Task 2: Rewrite AddFoodView with unified food discovery

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/AddFoodView.swift`

**Step 1: Full rewrite of AddFoodView**

Replace the entire contents of AddFoodView.swift with the new discovery layout:

- **Meal type pill** in toolbar (keep existing `currentMealType` state)
- **Search bar** using `.searchable` modifier
- **Recent Foods section**: horizontal scroll of compact food chips (last 10 unique logged foods). Tapping opens quantity sheet.
- **Favorites section**: horizontal scroll (only shown if favorites exist). Tapping opens quantity sheet. Each chip has a heart icon.
- **Browse by Category**: 3-column `LazyVGrid` of 9 `FoodCategory` tiles (emoji + name). Tapping opens `FoodSearchView` filtered to that category.
- **"Add Custom Food" button** at bottom
- **Quantity sheet** presented when a food is selected from recent/favorites/search

State variables needed:
```swift
@State private var searchText = ""
@State private var currentMealType: MealType
@State private var showCustomEntry = false
@State private var selectedFoodForQuantity: FoodItem? // triggers quantity sheet
@State private var showCategorySearch = false
@State private var selectedCategory: FoodCategory?
```

The `.searchable` modifier filters `viewModel.foodItemsCache` live. When search text is non-empty, show matching results as a list (reuse `FoodItemRow`). Tapping a search result sets `selectedFoodForQuantity`.

Category tiles layout:
```swift
let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

LazyVGrid(columns: columns, spacing: 12) {
    ForEach(FoodCategory.allCases) { category in
        Button { ... } label: {
            VStack(spacing: 8) {
                Text(category.icon).font(.system(size: 32))
                Text(category.displayName).font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}
```

Recent/Favorites chips (horizontal scroll):
```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 10) {
        ForEach(items) { food in
            Button { selectedFoodForQuantity = food } label: {
                HStack(spacing: 6) {
                    Text(food.category.icon)
                    Text(food.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
            }
        }
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/AddFoodView.swift
git commit -m "feat(diet): rewrite AddFoodView with unified food discovery"
```

---

### Task 3: Add quantity adjustment sheet

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/AddFoodView.swift` (add `FoodQuantitySheet` struct at bottom)

**Step 1: Create FoodQuantitySheet**

Add a new struct `FoodQuantitySheet` in AddFoodView.swift:

```swift
struct FoodQuantitySheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DietViewModel
    let food: FoodItem
    let mealType: MealType
    let onLog: () -> Void

    @State private var quantity: Double = 1.0

    // Computed nutrition based on quantity
    private var multiplier: Double { quantity * food.servingSize / food.servingSize }
    // Actually: multiplier = quantity (since we multiply servingSize by quantity)
    private var adjustedCalories: Int { Int(food.calories * quantity) }
    private var adjustedProtein: Int { Int(food.proteinG * quantity) }
    private var adjustedCarbs: Int { Int(food.carbsG * quantity) }
    private var adjustedFat: Int { Int(food.fatG * quantity) }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Food header
                HStack(spacing: 12) {
                    Text(food.category.icon).font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(.headline)
                        Text(food.displayServingSize).font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    // Favorite button
                    Button { viewModel.toggleFavorite(foodId: food.id) } label: {
                        Image(systemName: viewModel.isFavorite(foodId: food.id) ? "heart.fill" : "heart")
                            .foregroundColor(viewModel.isFavorite(foodId: food.id) ? .red : .secondary)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal)

                // Quantity stepper
                VStack(spacing: 8) {
                    Text("Servings").font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 20) {
                        Button { if quantity > 0.5 { quantity -= 0.5 } } label: {
                            Image(systemName: "minus.circle.fill").font(.title).foregroundColor(.green)
                        }
                        Text("\(quantity, specifier: "%.1f")")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .frame(minWidth: 60)
                        Button { if quantity < 10 { quantity += 0.5 } } label: {
                            Image(systemName: "plus.circle.fill").font(.title).foregroundColor(.green)
                        }
                    }
                }

                // Nutrition preview
                HStack(spacing: 0) {
                    nutritionPill(value: "\(adjustedCalories)", label: "cal", color: .green)
                    nutritionPill(value: "\(adjustedProtein)g", label: "protein", color: .orange)
                    nutritionPill(value: "\(adjustedCarbs)g", label: "carbs", color: .blue)
                    nutritionPill(value: "\(adjustedFat)g", label: "fat", color: .purple)
                }
                .padding(.horizontal)

                Spacer()

                // Log button
                Button {
                    Task {
                        await viewModel.logFood(
                            item: food,
                            quantity: food.servingSize * quantity,
                            mealType: mealType
                        )
                        onLog()
                    }
                } label: {
                    Text("Log Food")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(14)
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .navigationTitle("Adjust Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func nutritionPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}
```

Wire it up in AddFoodView via:
```swift
.sheet(item: $selectedFoodForQuantity) { food in
    FoodQuantitySheet(
        viewModel: viewModel,
        food: food,
        mealType: currentMealType,
        onLog: { dismiss() }
    )
}
```

Update `FoodItem` to conform to `Identifiable` (already does) — for `.sheet(item:)` it also needs to be `Hashable` or use `Identifiable`. Since `FoodItem` is already `Identifiable`, use `selectedFoodForQuantity` as `FoodItem?` and present via `.sheet(item:)`.

**Step 2: Update FoodSearchView to use quantity sheet**

Change the `onFoodSelected` callback in AddFoodView's category search sheet to set `selectedFoodForQuantity` instead of immediately logging:

```swift
// In the FoodSearchView sheet:
FoodSearchView(
    viewModel: viewModel,
    selectedMealType: currentMealType,
    onFoodSelected: { food in
        showCategorySearch = false
        selectedFoodForQuantity = food
    }
)
```

**Step 3: Build and verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/AddFoodView.swift
git commit -m "feat(diet): add quantity adjustment sheet before logging"
```

---

### Task 4: Add heart icon favorites to FoodSearchView

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/FoodSearchView.swift`

**Step 1: Add heart toggle to FoodItemRow**

Update `FoodItemRow` to accept an optional favorite toggle. Add parameters:

```swift
struct FoodItemRow: View {
    let food: FoodItem
    let onSelect: () -> Void
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    // ... existing body
}
```

In the row's HStack, before the `plus.circle.fill` button, add:

```swift
if let onToggleFavorite {
    Button(action: onToggleFavorite) {
        Image(systemName: isFavorite ? "heart.fill" : "heart")
            .font(.system(size: 18))
            .foregroundColor(isFavorite ? .red : .secondary)
    }
    .buttonStyle(.plain)
}
```

**Step 2: Pass viewModel favorites to FoodItemRow in FoodSearchView**

In `FoodSearchView`, update the `ForEach` to pass favorite state:

```swift
ForEach(filteredFoods) { food in
    FoodItemRow(
        food: food,
        onSelect: { onFoodSelected(food) },
        isFavorite: viewModel.isFavorite(foodId: food.id),
        onToggleFavorite: { viewModel.toggleFavorite(foodId: food.id) }
    )
}
```

**Step 3: Build and verify**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/FoodSearchView.swift
git commit -m "feat(diet): add heart icon favorites toggle to food search rows"
```

---

### Task 5: Expand Indian food database (~100 new items)

**Files:**
- Create: `supabase/migrations/20260302000001_seed_more_food_items.sql`

**Step 1: Write the migration**

Create a new SQL migration file with ~100 more Indian foods across categories:

**South Indian:**
- Uttapam, Pongal, Medu Vada, Appam, Puttu, Avial, Rasam, Sambar Rice, Lemon Rice, Curd Rice, Coconut Chutney, Tomato Rice, Bisi Bele Bath, Pesarattu, Rava Dosa

**North Indian:**
- Chole Bhature, Rajma Chawal, Dal Makhani, Aloo Paratha, Stuffed Kulcha, Matar Paneer, Shahi Paneer, Kadhai Paneer, Aloo Gobi, Jeera Rice, Methi Thepla, Missi Roti, Rumali Roti, Tandoori Roti

**Bengali:**
- Fish Curry (Bengali), Mishti Doi, Sandesh, Luchi, Aloo Posto, Shukto

**Gujarati:**
- Thepla, Undhiyu, Khandvi, Handvo, Dal Dhokli

**Street food:**
- Pav Bhaji, Sev Puri, Kachori, Aloo Tikki, Dahi Bhalla, Chole Tikki, Ragda Pattice, Dabeli, Vada Pav, Misal Pav

**Restaurant mains:**
- Chicken Biryani, Veg Biryani, Butter Chicken, Kadhai Chicken, Tandoori Chicken, Chicken Tikka, Malai Kofta, Dal Tadka, Dal Fry, Paneer Tikka, Paneer Butter Masala

**Modern/healthy:**
- Oats Upma, Quinoa Khichdi, Smoothie Bowl, Sprouts Salad, Muesli, Ragi Dosa, Multigrain Roti, Sattu Paratha, Bajra Roti, Jowar Roti

**Beverages:**
- Filter Coffee, Masala Chai, Jaljeera, Aam Panna, Thandai, Badam Milk, Sugarcane Juice, Nimbu Pani, Mango Lassi, Rose Sharbat

**Sweets:**
- Kaju Katli, Mysore Pak, Peda, Ras Malai, Kalakand, Malpua, Imarti, Modak, Puran Poli, Payasam

Each entry uses realistic nutritional values for Indian portions.

**Step 2: Apply migration**

Run: `supabase db push` (or apply via Supabase dashboard)

**Step 3: Commit**

```bash
git add supabase/migrations/20260302000001_seed_more_food_items.sql
git commit -m "feat(diet): expand food database with ~100 more Indian foods"
```

---

### Task 6: Update cloud food fetch limit

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/DietViewModel.swift`

**Step 1: Increase food items fetch limit**

In `syncWithCloud()` method (line 322), change the fetch limit from 100 to 500 to accommodate the expanded database:

```swift
let cloudFoodItems = try await SupabaseManager.shared.fetchFoodItems(limit: 500)
```

**Step 2: Build final verification**

Run: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/DietViewModel.swift
git commit -m "feat(diet): increase food items fetch limit for expanded database"
```

---

## Verification Checklist

1. Build succeeds: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
2. AddFoodView shows: search bar, recent foods chips, favorites chips (if any), 3x3 category grid, custom food button
3. Tapping a food from recent/favorites/search opens quantity sheet
4. Quantity stepper adjusts 0.5–10.0, nutrition preview updates live
5. Heart icon toggles on FoodSearchView rows and quantity sheet
6. Favorites persist across app launches (UserDefaults)
7. FoodSearchView opens filtered when tapping a category tile
8. Migration seeds ~100 new foods with correct categories and nutrition
