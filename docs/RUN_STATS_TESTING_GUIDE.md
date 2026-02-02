# Testing Guide: Enhanced Run Stats & Analytics

## Quick Start

### 1. Build & Run
```bash
cd /Users/syamsundar/Onwords/swastricare-mobile-swift
xcodebuild -project swastricare-mobile-swift.xcodeproj -scheme swastricare-mobile-swift -sdk iphoneos build
```

Or open in Xcode:
```bash
open swastricare-mobile-swift.xcodeproj
```

### 2. Navigate to Run Stats
1. Open the app
2. Go to the "Steps" or "Run Activity" tab
3. Tap "See All" button (if you have > 5 activities)
4. Or tap on the Run Stats option from the main menu

---

## What to Test

### ✅ Overview Tab

#### Enhanced Stat Cards
- [ ] All 4 cards display correctly (Steps, Distance, Calories, Points)
- [ ] Progress rings animate smoothly
- [ ] Trend badges show correct percentages and colors
  - Green for positive trends (↗️)
  - Red for negative trends (↘️)
- [ ] Numbers are properly formatted
- [ ] Subtitles are readable

#### Weekly Distance Chart
- [ ] Bar chart displays last 7 days
- [ ] Bars have gradient fill
- [ ] X-axis shows day names (Mon, Tue, Wed...)
- [ ] Y-axis shows distance values
- [ ] Total distance shown in header

#### Activity Streak Card
- [ ] Current streak displays correctly
- [ ] Longest streak displays correctly
- [ ] Flame icon on current streak
- [ ] Trophy icon on best streak
- [ ] Motivational message appears

#### Quick Stats Grid
- [ ] Average pace calculated correctly
- [ ] Average heart rate shown
- [ ] Total time formatted nicely (Xh Ym)
- [ ] Average distance per activity

---

### ✅ Performance Tab

#### Performance Insights Card
- [ ] Purple gradient background
- [ ] At least 2-3 insights display
- [ ] Icons match insight types
- [ ] Consistency insight shows active days
- [ ] Distance improvement percentage
- [ ] Morning/evening preference detection

#### Personal Records Section
- [ ] Yellow gradient background
- [ ] Longest distance record
- [ ] Longest duration record
- [ ] Most steps record
- [ ] Dates formatted correctly

#### Pace Distribution Chart
- [ ] Horizontal bar chart displays
- [ ] Shows pace ranges (< 5:00, 5:00-6:00, etc.)
- [ ] Activity counts are correct
- [ ] Bars are proportional

#### Time of Day Analysis
- [ ] Shows 4 time periods (Morning, Afternoon, Evening, Night)
- [ ] Bars show relative distribution
- [ ] Counts are accurate

#### Goals Progress
- [ ] Steps goal with progress bar
- [ ] Distance goal with progress bar
- [ ] Calories goal with progress bar
- [ ] Percentages match actual progress

---

### ✅ Calendar Tab

#### Calendar Display
- [ ] Current month shown
- [ ] Can navigate previous/next months
- [ ] Days with activities marked with dots
- [ ] Intensity indicated by dot color/opacity
- [ ] Today highlighted with blue border
- [ ] Selected date highlighted

#### Selected Date Details
- [ ] Tapping a date shows activities
- [ ] Activity list for that day displays
- [ ] No activities message for rest days
- [ ] Can navigate to activity detail

#### Monthly Summary
- [ ] Total distance for month
- [ ] Total activities count
- [ ] Active days count
- [ ] All three cards display

---

### ✅ Activities Tab

#### Activity List
- [ ] All activities listed
- [ ] Sorted by date (newest first)
- [ ] Each card shows:
  - Map preview
  - Activity name
  - Time range
  - Distance
  - Average BPM
- [ ] Tapping opens activity detail
- [ ] Empty state if no activities

---

## Visual Tests

### Colors
- [ ] Blue (#4F46E5): Distance, pace, primary actions
- [ ] Green (#22C55E): Steps, streaks, positive trends
- [ ] Orange: Calories, time
- [ ] Yellow: Points, records
- [ ] Purple: Insights
- [ ] Red: Negative trends

### Typography
- [ ] Large numbers are bold and rounded
- [ ] Labels are readable (secondary color)
- [ ] Proper font weights throughout
- [ ] No text truncation issues

### Spacing
- [ ] 20px margin on screen edges
- [ ] 24px between major sections
- [ ] 16px between cards
- [ ] 20px padding inside cards
- [ ] Consistent corner radius (20px)

### Animations
- [ ] Smooth fade-in on load
- [ ] Staggered animations (100ms delay between)
- [ ] Tab switch is smooth
- [ ] Progress ring animates nicely
- [ ] No jank or stuttering

---

## Interaction Tests

### Tab Switching
- [ ] Tap each tab
- [ ] Verify haptic feedback
- [ ] Content changes smoothly
- [ ] Selected state is clear
- [ ] Animation is quick (300ms)

### Scrolling
- [ ] Smooth 60fps scrolling
- [ ] No stuttering on charts
- [ ] Bounce effect at top/bottom
- [ ] Pull to refresh works (on main view)

### Navigation
- [ ] Back button works
- [ ] Activity detail opens correctly
- [ ] Navigation bar displays properly
- [ ] Title updates correctly

---

## Edge Cases

### No Data
- [ ] Empty state displays correctly
- [ ] Helpful message shown
- [ ] Icon and text centered
- [ ] No crashes or errors

### Single Activity
- [ ] Charts still render
- [ ] Stats calculate correctly
- [ ] No divide-by-zero errors
- [ ] Streak shows 1 day

### Large Numbers
- [ ] 10,000+ steps format nicely
- [ ] 100+ km doesn't overflow
- [ ] Percentages over 100% display

### Small Screen (iPhone SE)
- [ ] Cards resize appropriately
- [ ] No horizontal scrolling (except tabs)
- [ ] Text doesn't truncate badly
- [ ] Charts are readable

### Large Screen (iPad)
- [ ] Layout looks good
- [ ] Not stretched awkwardly
- [ ] Cards use appropriate width
- [ ] Spacing is pleasant

---

## Performance Tests

### Load Time
- [ ] Initial load < 1 second
- [ ] Tab switch < 300ms
- [ ] Scroll is smooth (60fps)
- [ ] No visible lag

### Memory
- [ ] No memory leaks
- [ ] Memory usage stable
- [ ] Charts don't cause spikes

### Battery
- [ ] No excessive CPU usage
- [ ] Animations don't drain battery
- [ ] Background processing minimal

---

## Accessibility Tests

### VoiceOver
- [ ] All buttons announced
- [ ] Stats read correctly
- [ ] Charts have labels
- [ ] Navigation works

### Dynamic Type
- [ ] Text scales appropriately
- [ ] Layout doesn't break
- [ ] Still readable at all sizes

### Dark Mode
- [ ] Colors adapt properly
- [ ] Contrast is sufficient
- [ ] Glass effect works
- [ ] Charts are visible

---

## Device Tests

Test on multiple devices:
- [ ] iPhone 15 Pro (latest)
- [ ] iPhone SE (small screen)
- [ ] iPhone 15 Pro Max (large screen)
- [ ] iPad (tablet)

iOS versions:
- [ ] iOS 17.0+ (Charts framework requirement)

---

## Common Issues & Fixes

### Charts Not Displaying
**Issue**: Charts show blank or crash
**Fix**: Ensure iOS 17+ and Charts framework imported

### Progress Ring Not Animating
**Issue**: Ring appears static
**Fix**: Check `isAnimating` state is set to true on appear

### Trend Badges Missing
**Issue**: No trend percentages
**Fix**: Ensure `percentageChange` data is available from ViewModel

### Tab Selector Cut Off
**Issue**: Tab buttons cut off on small screens
**Fix**: Ensure horizontal ScrollView for tabs

### Colors Look Off
**Issue**: Colors don't match design
**Fix**: Verify Color(hex:) extension is correct

---

## Debugging Tips

### Print Statements
```swift
print("📊 Activities count: \(viewModel.activities.count)")
print("📈 Weekly data: \(generateWeeklyData())")
print("🎯 Current streak: \(calculateCurrentStreak())")
```

### Xcode Preview
```swift
#Preview {
    NavigationStack {
        RunStatsAnalyticsView()
    }
}
```

### Breakpoints
- Set breakpoints in tab selection
- Check data calculation methods
- Verify chart data generation

---

## Screenshots to Capture

For documentation:
1. Overview tab - full scroll
2. Performance tab - insights section
3. Performance tab - records section
4. Calendar tab - month view
5. Calendar tab - selected day
6. Activities tab - list view
7. Empty states for each tab
8. Dark mode variants

---

## Feedback Checklist

User Experience:
- [ ] Intuitive navigation
- [ ] Information is clear
- [ ] Actions are obvious
- [ ] Helpful for tracking progress

Visual Design:
- [ ] Modern and appealing
- [ ] Consistent with app design
- [ ] Colors are meaningful
- [ ] Typography is readable

Performance:
- [ ] Feels fast and responsive
- [ ] No lag or stuttering
- [ ] Smooth animations
- [ ] Quick load times

---

## Next Steps After Testing

If everything works:
1. ✅ Commit changes
2. ✅ Create PR for review
3. ✅ Update changelog
4. ✅ Deploy to TestFlight

If issues found:
1. 🐛 Document bugs
2. 🔧 Fix critical issues
3. 📝 Create tickets for enhancements
4. 🔄 Re-test

---

## Questions to Ask

1. **Is the information hierarchy clear?**
   - Can users quickly find what they need?
   
2. **Are the insights valuable?**
   - Do they motivate users?
   
3. **Is the performance acceptable?**
   - Does it feel fast?
   
4. **Are the visualizations helpful?**
   - Do charts aid understanding?
   
5. **Is navigation intuitive?**
   - Can users find all features?

---

## Success Criteria

✅ All tabs load correctly
✅ Charts display with real data
✅ Animations are smooth (60fps)
✅ No crashes or errors
✅ Performance is good
✅ Design matches spec
✅ Accessibility works
✅ Dark mode looks good

---

*Test thoroughly and enjoy the improved Run Stats & Analytics experience!* 🎉
