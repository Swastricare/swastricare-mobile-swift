# AI Features Not Working - 401 Unauthorized Error

## Problem Identified

The Edge Functions are returning **401 Unauthorized** errors. This means authentication is failing.

## Root Cause

The Edge Functions have JWT verification enabled (`verify_jwt: true`), which requires:
1. User must be logged in to the app
2. Valid auth token must be sent with each request

## Quick Fix Options

### Option 1: Ensure User is Logged In (Recommended for Production)

**Before using AI features, make sure:**
1. User is signed in via AuthView
2. Session is active
3. Auth token is valid

**To test:**
- Make sure you're logged in before going to AI tab
- Check if other features (like health sync) work
- If not logged in, sign in first

### Option 2: Temporarily Disable JWT Verification (For Testing Only)

If you want to test AI features without authentication:

1. Redeploy functions without JWT verification:

```bash
cd "/Users/onwords/i do coding/swastricare-mobile-swift"

# For each function, we need to redeploy with verify_jwt: false
# This will be done via Supabase dashboard or MCP
```

**⚠️ Warning:** Disabling JWT verification means anyone can call your AI functions and use your API quota!

## Recommended Solution

**Add authentication check in AI views before making requests:**

Update `AIViews.swift` to check if user is authenticated before allowing AI features.

## Testing Steps

1. **Verify you're logged in:**
   - Open app
   - Check if you see AuthView or ContentView
   - If AuthView, sign in first

2. **Check auth status:**
   - Go to Profile tab
   - Verify user email is shown
   - This confirms authentication is working

3. **Try AI features again:**
   - Go to AI tab
   - Try chat or analysis
   - Check Xcode console for detailed error logs

## Console Logs to Look For

When testing, watch for these in Xcode console:

```
🔄 AIManager: Starting health analysis
📡 Calling Edge Function: ai-health-analysis
❌ Error in analyzeHealth: [error details]
```

If you see "401" or "unauthorized", authentication is the issue.

## Next Steps

1. **First**: Verify user is logged in
2. **Then**: Try AI features
3. **If still failing**: Check Supabase project settings for auth configuration
4. **Last resort**: Temporarily disable JWT verification for testing

---

**Current Status:**
- ✅ Edge Functions deployed
- ✅ API key configured
- ✅ iOS app code working
- ❌ Authentication failing (401 errors)

**Solution:** Ensure user is signed in before using AI features!
