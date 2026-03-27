# Refer & Earn Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Gate AI feature behind a referral — refer 1 friend who signs up to unlock AI for life.

**Architecture:** New `referrals` table + `ai_unlocked` flag on `users` table in Supabase. New `ReferralService` (protocol + implementation) handles all referral CRUD. `ReferralViewModel` manages state. `AIReferralGateView` replaces AI chat when locked. Deep link `swastricareapp://referral?code=XXX` handled by existing `DeepLinkHandler`. On signup, pending referral code is applied server-side.

**Tech Stack:** Swift/SwiftUI, Supabase (Postgres + RLS), existing DesignSystem (PremiumBackground, ScaleButtonStyle, AppColors)

**Design Doc:** `docs/plans/2026-03-26-refer-and-earn-design.md`

---

### Task 1: Supabase Migration — Add referral schema

**Files:**
- Create: `supabase/migrations/20260326000001_create_referrals.sql`

**Step 1: Write the migration**

```sql
-- Referral system for AI access gating
-- Each user gets a unique referral_code on their users row.
-- When a referred user signs up, referrals row is completed and referrer's ai_unlocked flips to true.

-- Add columns to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS ai_unlocked BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS referral_code VARCHAR(8) UNIQUE;

-- Referrals tracking table
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    referred_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    referral_code VARCHAR(8) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON public.referrals(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code) WHERE referral_code IS NOT NULL;

-- Trigger for updated_at
CREATE TRIGGER referrals_updated_at
    BEFORE UPDATE ON public.referrals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- RLS
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- Users can read their own referrals (as referrer)
CREATE POLICY "Users can read own referrals"
    ON public.referrals FOR SELECT
    USING (auth.uid() = referrer_user_id);

-- Users can insert referrals they sent
CREATE POLICY "Users can create own referrals"
    ON public.referrals FOR INSERT
    WITH CHECK (auth.uid() = referrer_user_id);

-- Server function to complete a referral (called during signup)
CREATE OR REPLACE FUNCTION public.complete_referral(p_referral_code VARCHAR, p_referred_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_referrer_id UUID;
BEGIN
    -- Find the referrer by code
    SELECT id INTO v_referrer_id
    FROM public.users
    WHERE referral_code = p_referral_code;

    IF v_referrer_id IS NULL THEN
        RETURN false;  -- Invalid code
    END IF;

    -- Prevent self-referral
    IF v_referrer_id = p_referred_user_id THEN
        RETURN false;
    END IF;

    -- Check if this referred user already completed a referral for this referrer (idempotent)
    IF EXISTS (
        SELECT 1 FROM public.referrals
        WHERE referrer_user_id = v_referrer_id
        AND referred_user_id = p_referred_user_id
        AND status = 'completed'
    ) THEN
        RETURN true;  -- Already done
    END IF;

    -- Insert or update the referral
    INSERT INTO public.referrals (referrer_user_id, referred_user_id, referral_code, status, completed_at)
    VALUES (v_referrer_id, p_referred_user_id, p_referral_code, 'completed', NOW())
    ON CONFLICT DO NOTHING;

    -- Unlock AI for the referrer
    UPDATE public.users SET ai_unlocked = true WHERE id = v_referrer_id;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate a unique referral code for a user
CREATE OR REPLACE FUNCTION public.generate_referral_code(p_user_id UUID)
RETURNS VARCHAR AS $$
DECLARE
    v_name VARCHAR;
    v_prefix VARCHAR(3);
    v_code VARCHAR(8);
    v_attempts INT := 0;
BEGIN
    -- Check if user already has a code
    SELECT referral_code INTO v_code FROM public.users WHERE id = p_user_id;
    IF v_code IS NOT NULL THEN
        RETURN v_code;
    END IF;

    -- Get user's name for prefix
    SELECT COALESCE(full_name, 'USR') INTO v_name FROM public.users WHERE id = p_user_id;
    v_prefix := UPPER(LEFT(REGEXP_REPLACE(v_name, '[^a-zA-Z]', '', 'g'), 3));
    IF LENGTH(v_prefix) < 3 THEN
        v_prefix := RPAD(v_prefix, 3, 'X');
    END IF;

    -- Generate code with retries
    LOOP
        v_code := v_prefix || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 3));
        BEGIN
            UPDATE public.users SET referral_code = v_code WHERE id = p_user_id;
            RETURN v_code;
        EXCEPTION WHEN unique_violation THEN
            v_attempts := v_attempts + 1;
            IF v_attempts >= 5 THEN
                -- Fallback: use longer random suffix
                v_code := v_prefix || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 5));
                UPDATE public.users SET referral_code = v_code WHERE id = p_user_id;
                RETURN v_code;
            END IF;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Allow users to read their own ai_unlocked status (already covered by existing users RLS)
-- Allow the complete_referral function to update users (SECURITY DEFINER handles this)
```

**Step 2: Apply the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

**Step 3: Commit**

```bash
git add supabase/migrations/20260326000001_create_referrals.sql
git commit -m "feat(db): add referral schema for AI access gating"
```

---

### Task 2: ReferralService — Protocol + Implementation

**Files:**
- Create: `swastricare-mobile-swift/Services/ReferralService.swift`

**Step 1: Write the service**

```swift
//
//  ReferralService.swift
//  swastricare-mobile-swift
//

import Foundation
import Supabase

// MARK: - Referral Service Protocol

protocol ReferralServiceProtocol {
    func getOrCreateReferralCode() async throws -> String
    func checkAIUnlocked() async throws -> Bool
    func applyReferralCode(_ code: String) async throws -> Bool
    func getReferralCount() async throws -> Int
}

// MARK: - Referral Models

struct ReferralRecord: Codable {
    let id: UUID
    let referrer_user_id: UUID
    let referred_user_id: UUID?
    let referral_code: String
    let status: String
    let completed_at: String?
    let created_at: String
}

// MARK: - Referral Service Implementation

final class ReferralService: ReferralServiceProtocol {

    static let shared = ReferralService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    func getOrCreateReferralCode() async throws -> String {
        let session = try await client.auth.session
        let userId = session.user.id

        // Call the DB function to generate (or return existing) code
        let response: PostgrestResponse<[AnyJSON]> = try await client
            .rpc("generate_referral_code", params: ["p_user_id": AnyJSON.string(userId.uuidString)])
            .execute()

        // The function returns a single varchar value
        if let data = try? JSONSerialization.jsonObject(with: response.data) as? String {
            return data
        }

        // Fallback: read from users table
        struct UserCode: Decodable {
            let referral_code: String?
        }
        let user: UserCode = try await client
            .from("users")
            .select("referral_code")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        guard let code = user.referral_code else {
            throw ReferralError.codeGenerationFailed
        }
        return code
    }

    func checkAIUnlocked() async throws -> Bool {
        let session = try await client.auth.session
        let userId = session.user.id

        struct UserAI: Decodable {
            let ai_unlocked: Bool?
        }

        let user: UserAI = try await client
            .from("users")
            .select("ai_unlocked")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return user.ai_unlocked ?? false
    }

    func applyReferralCode(_ code: String) async throws -> Bool {
        let session = try await client.auth.session
        let userId = session.user.id

        struct RpcResult: Decodable {
            // The function returns a single boolean
        }

        let response: PostgrestResponse<[AnyJSON]> = try await client
            .rpc("complete_referral", params: [
                "p_referral_code": AnyJSON.string(code),
                "p_referred_user_id": AnyJSON.string(userId.uuidString)
            ])
            .execute()

        if let data = try? JSONSerialization.jsonObject(with: response.data) as? Bool {
            return data
        }
        return false
    }

    func getReferralCount() async throws -> Int {
        let session = try await client.auth.session
        let userId = session.user.id

        let response = try await client
            .from("referrals")
            .select("id", head: false, count: .exact)
            .eq("referrer_user_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .execute()

        return response.count ?? 0
    }
}

// MARK: - Referral Errors

enum ReferralError: LocalizedError {
    case codeGenerationFailed
    case invalidCode
    case selfReferral
    case networkError

    var errorDescription: String? {
        switch self {
        case .codeGenerationFailed: return "Failed to generate referral code. Please try again."
        case .invalidCode: return "Invalid referral code. Please check and try again."
        case .selfReferral: return "You can't use your own referral code."
        case .networkError: return "Network error. Please check your connection."
        }
    }
}
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/Services/ReferralService.swift
git commit -m "feat: add ReferralService with protocol and Supabase integration"
```

---

### Task 3: ReferralViewModel

**Files:**
- Create: `swastricare-mobile-swift/ViewModels/ReferralViewModel.swift`

**Step 1: Write the ViewModel**

```swift
//
//  ReferralViewModel.swift
//  swastricare-mobile-swift
//

import Foundation
import UIKit

@MainActor
final class ReferralViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isAIUnlocked: Bool = false
    @Published private(set) var referralCode: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var showCodeEntry: Bool = false
    @Published var enteredCode: String = ""
    @Published private(set) var isApplyingCode: Bool = false
    @Published private(set) var applyCodeError: String?

    // MARK: - Dependencies

    private let referralService: ReferralServiceProtocol

    // MARK: - Cache Keys

    private static let aiUnlockedKey = "referral_ai_unlocked"
    private static let referralCodeKey = "referral_code"

    // MARK: - Init

    init(referralService: ReferralServiceProtocol = ReferralService.shared) {
        self.referralService = referralService
        // Load cached state immediately (no flicker)
        self.isAIUnlocked = UserDefaults.standard.bool(forKey: Self.aiUnlockedKey)
        self.referralCode = UserDefaults.standard.string(forKey: Self.referralCodeKey)
    }

    // MARK: - Load State

    func loadReferralState() async {
        // Don't show loading if we have cached state
        if referralCode == nil {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            // Check AI unlock status
            let unlocked = try await referralService.checkAIUnlocked()
            isAIUnlocked = unlocked
            UserDefaults.standard.set(unlocked, forKey: Self.aiUnlockedKey)

            // Get or create referral code
            if !unlocked {
                let code = try await referralService.getOrCreateReferralCode()
                referralCode = code
                UserDefaults.standard.set(code, forKey: Self.referralCodeKey)
            }
        } catch {
            // Use cached values on error — don't block the user
            print("Failed to load referral state: \(error.localizedDescription)")
        }
    }

    // MARK: - Share

    func shareReferralCode() {
        guard let code = referralCode else { return }

        let message = "Join me on SwasthiCare - your personal health companion! Use my referral code: \(code)\n\nswastricareapp://referral?code=\(code)"

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        // Present from the top-most view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            // iPad popover anchor
            activityVC.popoverPresentationController?.sourceView = topVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0
            )
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Apply Code (for referred users)

    func applyEnteredCode() async {
        let code = enteredCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            applyCodeError = "Please enter a referral code."
            return
        }

        isApplyingCode = true
        applyCodeError = nil
        defer { isApplyingCode = false }

        do {
            let success = try await referralService.applyReferralCode(code)
            if success {
                showCodeEntry = false
                enteredCode = ""
            } else {
                applyCodeError = "Invalid referral code. Please check and try again."
            }
        } catch {
            applyCodeError = UserFriendlyError.message(from: error)
        }
    }

    // MARK: - Sign Out Cleanup

    func clearOnSignOut() {
        isAIUnlocked = false
        referralCode = nil
        isLoading = false
        errorMessage = nil
        showCodeEntry = false
        enteredCode = ""
        isApplyingCode = false
        applyCodeError = nil
        UserDefaults.standard.removeObject(forKey: Self.aiUnlockedKey)
        UserDefaults.standard.removeObject(forKey: Self.referralCodeKey)
    }
}
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/ReferralViewModel.swift
git commit -m "feat: add ReferralViewModel with caching and share support"
```

---

### Task 4: DependencyContainer — Register ReferralService + ViewModel

**Files:**
- Modify: `swastricare-mobile-swift/Core/DependencyContainer.swift`

**Step 1: Add referral service and viewmodel**

Add to the services section (after `cacheService` at line 38):
```swift
let referralService: ReferralServiceProtocol
```

Add to the lazy viewmodels section (after `familyViewModel`):
```swift
lazy var referralViewModel: ReferralViewModel = {
    ReferralViewModel(referralService: referralService)
}()
```

Add to `init()` (after `self.cacheService = CacheService.shared` at line 128):
```swift
self.referralService = ReferralService.shared
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/Core/DependencyContainer.swift
git commit -m "feat: register ReferralService and ReferralViewModel in DI container"
```

---

### Task 5: AIReferralGateView — The gate screen

**Files:**
- Create: `swastricare-mobile-swift/Views/AI/AIReferralGateView.swift`

**Step 1: Write the gate view**

```swift
//
//  AIReferralGateView.swift
//  swastricare-mobile-swift
//

import SwiftUI

struct AIReferralGateView: View {

    @ObservedObject var viewModel: ReferralViewModel

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 60)

                    // AI Icon
                    ZStack {
                        Circle()
                            .fill(AppColors.accentBlue.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "sparkles")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accentBlue, AppColors.onboardingPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Title
                    VStack(spacing: 10) {
                        Text("Unlock SwasthiCare AI")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text("Refer a friend to unlock AI — free, forever")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // How it works
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How it works")
                            .font(.system(size: 18, weight: .semibold))

                        howItWorksStep(number: "1", title: "Share your code", subtitle: "Send your unique code to a friend")
                        howItWorksStep(number: "2", title: "Friend signs up", subtitle: "They join SwasthiCare using your code")
                        howItWorksStep(number: "3", title: "AI unlocked!", subtitle: "You get lifetime access to SwasthiCare AI")
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppDimensions.cardRadius))

                    // Referral code display
                    if let code = viewModel.referralCode {
                        VStack(spacing: 12) {
                            Text("Your referral code")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            HStack {
                                Text(code)
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .tracking(4)

                                Button {
                                    UIPasteboard.general.string = code
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.accentBlue)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Share button (primary CTA)
                    Button {
                        viewModel.shareReferralCode()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Share with a Friend")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accentBlue, AppColors.onboardingPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(viewModel.referralCode == nil)

                    // "I have a referral code" secondary action
                    Button {
                        viewModel.showCodeEntry = true
                    } label: {
                        Text("I have a referral code")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.accentBlue)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            // Loading overlay
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .sheet(isPresented: $viewModel.showCodeEntry) {
            referralCodeEntrySheet
        }
    }

    // MARK: - How It Works Step

    private func howItWorksStep(number: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [AppColors.accentBlue, AppColors.onboardingPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Code Entry Sheet

    private var referralCodeEntrySheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter Referral Code")
                    .font(.system(size: 22, weight: .bold))

                Text("Enter the code your friend shared with you")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("e.g. SYA7K2", text: $viewModel.enteredCode)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                if let error = viewModel.applyCodeError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accentRed)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await viewModel.applyEnteredCode()
                    }
                } label: {
                    HStack {
                        if viewModel.isApplyingCode {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Apply Code")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.enteredCode.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isApplyingCode)

                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        viewModel.showCodeEntry = false
                        viewModel.enteredCode = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/Views/AI/AIReferralGateView.swift
git commit -m "feat: add AIReferralGateView with share, code entry, and how-it-works UI"
```

---

### Task 6: AIView — Add referral gate

**Files:**
- Modify: `swastricare-mobile-swift/Views/AI/AIView.swift`

**Step 1: Add referral ViewModel to AIView**

At the top of `AIView` (after line 20, the existing `@StateObject` declarations), add:
```swift
@StateObject private var referralViewModel = DependencyContainer.shared.referralViewModel
```

**Step 2: Wrap body with gate check**

In `var body: some View` (line 79), change:
```swift
var body: some View {
    NavigationStack {
        chatView
```
to:
```swift
var body: some View {
    NavigationStack {
        if referralViewModel.isAIUnlocked {
            chatView
        } else {
            AIReferralGateView(viewModel: referralViewModel)
                .task {
                    await referralViewModel.loadReferralState()
                }
        }
    }
```

Keep all existing modifiers (`.navigationBarTitleDisplayMode`, `.toolbar`, etc.) — they apply to the NavigationStack regardless.

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/AI/AIView.swift
git commit -m "feat: gate AI chat behind referral check in AIView"
```

---

### Task 7: DeepLinkHandler — Add referral route

**Files:**
- Modify: `swastricare-mobile-swift/Helpers/DeepLinkHandler.swift`

**Step 1: Add referral case to DeepLink enum**

At line 22 (after `familyJoin(code: String)`), add:
```swift
case referral(code: String)
```

**Step 2: Add referral route in the switch**

In the `init?(url:)` switch (before `default:` at line 72), add:
```swift
case "referral":
    if let code = queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty {
        self = .referral(code: code)
    } else {
        return nil
    }
```

**Step 3: Add notification name**

After line 85 (`deepLinkFamilyJoin`), add:
```swift
static let deepLinkReferral = Notification.Name("DeepLink.Referral")
```

**Step 4: Add referral code key**

After line 90 (`familyInviteCode`), add:
```swift
static let referralCode = "referralCode"
```

**Step 5: Handle referral in DeepLinkHandler.handle()**

In the `handle(_ url:)` method (after the family invite handling at line 128), add:
```swift
if case .referral(let code) = deepLink {
    print("🔗 Referral deep link with code: \(code)")
    pendingReferralCode = code
    NotificationCenter.default.post(
        name: .deepLinkReferral,
        object: nil,
        userInfo: [DeepLinkUserInfoKey.referralCode: code]
    )
}
```

**Step 6: Add pendingReferralCode property**

After `pendingFamilyInviteCode` (line 107), add:
```swift
@Published var pendingReferralCode: String?
```

**Step 7: Add clear method**

After `clearFamilyInviteCode()` (line 135), add:
```swift
func clearReferralCode() {
    pendingReferralCode = nil
}
```

**Step 8: Commit**

```bash
git add swastricare-mobile-swift/Helpers/DeepLinkHandler.swift
git commit -m "feat: add referral deep link route to DeepLinkHandler"
```

---

### Task 8: AuthViewModel — Apply referral code on signup

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/AuthViewModel.swift`

**Step 1: Add pending referral code property**

Add near the top of `AuthViewModel` (with other published properties):
```swift
@Published var pendingReferralCode: String?
```

**Step 2: Apply referral code after successful signup**

In the `signUp()` method, after `clearForm()` (line 99), add:
```swift
// Apply pending referral code if present
if let code = pendingReferralCode {
    Task {
        let referralService = ReferralService.shared
        let _ = try? await referralService.applyReferralCode(code)
        pendingReferralCode = nil
    }
}
```

**Step 3: Also apply after signIn (in case user signed up but code wasn't applied)**

In `signIn()`, after `clearForm()` (line 129), add the same block:
```swift
if let code = pendingReferralCode {
    Task {
        let referralService = ReferralService.shared
        let _ = try? await referralService.applyReferralCode(code)
        pendingReferralCode = nil
    }
}
```

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/AuthViewModel.swift
git commit -m "feat: apply pending referral code on signup/signin"
```

---

### Task 9: App Entry Point — Wire referral deep link to AuthViewModel

**Files:**
- Modify: `swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift`

**Step 1: Pass referral code from deep link to AuthViewModel**

In the `.onOpenURL` handler (line 201-209), after `deepLinkHandler.handle(url)`, add:
```swift
// Pass referral code to auth for signup flow
if let deepLink = DeepLink(url: url), case .referral(let code) = deepLink {
    authViewModel.pendingReferralCode = code
}
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/App/swastricare_mobile_swiftApp.swift
git commit -m "feat: wire referral deep link to AuthViewModel in app entry"
```

---

### Task 10: Sign-out cleanup

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/AuthViewModel.swift`
- Modify: `swastricare-mobile-swift/ViewModels/AIViewModel.swift`

**Step 1: Clear referral state on sign out**

Find the sign-out method in `AuthViewModel` and add after existing cleanup:
```swift
DependencyContainer.shared.referralViewModel.clearOnSignOut()
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/AuthViewModel.swift
git commit -m "feat: clear referral state on sign out"
```

---

### Task 11: Build verification

**Step 1: Build the project**

Run:
```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

**Step 2: Fix any compilation errors**

Address issues from the build output.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: refer-and-earn AI access gate - complete implementation"
```
