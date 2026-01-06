# Swastricare Mobile - Supabase Setup

## ✅ Configuration Complete

Your Supabase integration is configured! Follow these steps to complete the setup:

---

## 📋 Step 1: Add Supabase Swift Package

1. Open your project in **Xcode**
2. Go to: **File > Add Package Dependencies**
3. Enter this URL: `https://github.com/supabase-community/supabase-swift`
4. Click **"Add Package"**
5. Select **all Supabase products** (Supabase, Auth, Realtime, Storage, Functions)
6. Click **"Add Package"** again

---

## 🔑 Step 2: Get Your Supabase Credentials

1. Go to: [https://app.supabase.com](https://app.supabase.com)
2. Select your **swastricare** project (or create a new one)
3. Navigate to: **Settings > API**
4. Copy these two values:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)

---

## 🛠️ Step 3: Update Config File

Open `Config.swift` and replace the placeholder values:

```swift
struct SupabaseConfig {
    static let projectURL = "https://YOUR_PROJECT_ID.supabase.co"  // ← Replace this
    static let anonKey = "YOUR_ANON_KEY_HERE"                      // ← Replace this
}
```

---

## 🎯 Usage Example

Once configured, you can use Supabase anywhere in your app:

```swift
// Access the Supabase client
let supabase = SupabaseManager.shared.client

// Example: Fetch data
let data = try await supabase
    .from("your_table")
    .select()
    .execute()

// Example: Insert data
try await supabase
    .from("health_data")
    .insert(["key": "value"])
    .execute()
```

---

## 📂 Files Created

- **SupabaseManager.swift** - Singleton class for Supabase client
- **Config.swift** - Configuration file for credentials
- **README_SUPABASE.md** - This file

---

## 🔒 Security Note

Never commit your actual Supabase keys to version control. Consider:
- Adding `Config.swift` to `.gitignore`
- Using environment variables for production
- Using Row Level Security (RLS) in Supabase

---

## 📚 Next Steps

1. Create your database tables in Supabase dashboard
2. Set up Row Level Security (RLS) policies
3. Integrate authentication (email/password, OAuth, etc.)
4. Start building your health tracker features!

---

## 📖 Documentation

- [Supabase Swift Docs](https://github.com/supabase-community/supabase-swift)
- [Supabase Dashboard](https://app.supabase.com)
- [Supabase Docs](https://supabase.com/docs)
