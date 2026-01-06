//
//  Config.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import Foundation

struct SupabaseConfig {
    // Supabase Configuration
    
    static let projectURL = "https://jlumbeyukpnuicyxzvre.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdW1iZXl1a3BudWljeXh6dnJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc2Nzc2MzAsImV4cCI6MjA4MzI1MzYzMH0.JYn8tZGP5OomXh968K4zV7L9h7Gam1zVW5YZ81DLC98"
}

// MARK: - Usage Instructions
/*
 
 Step 1: Get your Supabase credentials
 ----------------------------------------
 1. Go to https://app.supabase.com
 2. Select your 'swastricare' project (or create one)
 3. Navigate to: Settings > API
 4. Copy the following:
    - Project URL (looks like: https://xxxxx.supabase.co)
    - anon/public key (starts with eyJ...)
 
 Step 2: Update this file
 ----------------------------------------
 Replace the placeholder values above with your actual credentials
 
 Step 3: Add Supabase Swift Package
 ----------------------------------------
 In Xcode:
 1. File > Add Package Dependencies
 2. Enter: https://github.com/supabase-community/supabase-swift
 3. Click "Add Package"
 4. Select all Supabase products and click "Add Package"
 
 */
