// ── Feature category mappings ──
export const FEATURE_CATEGORIES: Record<string, string> = {
  // Hydration
  hydration_log: 'Hydration',
  hydration_goal_set: 'Hydration',
  hydration_reminder: 'Hydration',
  hydration_update: 'Hydration',
  hydration_delete: 'Hydration',
  water_intake_logged: 'Hydration',
  hydration_goal_completed: 'Hydration',

  // Medication
  medication_taken: 'Medication',
  medication_skipped: 'Medication',
  medication_snoozed: 'Medication',
  medication_added: 'Medication',
  medication_deleted: 'Medication',
  medication_updated: 'Medication',
  medication_reminder: 'Medication',

  // Workout
  workout_started: 'Workout',
  workout_completed: 'Workout',
  workout_paused: 'Workout',
  workout_resumed: 'Workout',
  workout_cancelled: 'Workout',
  run_started: 'Workout',
  run_completed: 'Workout',
  run_paused: 'Workout',
  activity_started: 'Workout',
  activity_completed: 'Workout',

  // AI
  ai_chat_sent: 'AI',
  ai_chat_received: 'AI',
  ai_conversation_started: 'AI',
  ai_mode_selected: 'AI',
  ai_image_sent: 'AI',

  // Vault
  vault_document_uploaded: 'Vault',
  vault_document_viewed: 'Vault',
  vault_document_deleted: 'Vault',
  vault_opened: 'Vault',

  // Heart Rate
  heart_rate_measured: 'Heart Rate',
  heart_rate_saved: 'Heart Rate',
  heart_rate_camera_started: 'Heart Rate',
  heart_rate_completed: 'Heart Rate',
  bpm_recorded: 'Heart Rate',

  // Auth
  login: 'Auth',
  login_success: 'Auth',
  login_failed: 'Auth',
  signup: 'Auth',
  signup_success: 'Auth',
  logout: 'Auth',
  password_reset: 'Auth',
  otp_sent: 'Auth',
  otp_verified: 'Auth',

  // Diet
  diet_logged: 'Diet',
  food_searched: 'Diet',
  food_added: 'Diet',
  meal_logged: 'Diet',
  diet_goal_set: 'Diet',
  calorie_logged: 'Diet',

  // Onboarding
  onboarding_started: 'Onboarding',
  onboarding_completed: 'Onboarding',
  onboarding_step: 'Onboarding',
  health_profile_completed: 'Onboarding',

  // Menstrual Cycle
  cycle_logged: 'Menstrual',
  period_started: 'Menstrual',
  period_ended: 'Menstrual',
  cycle_prediction_viewed: 'Menstrual',

  // Family
  family_created: 'Family',
  family_joined: 'Family',
  family_invite_sent: 'Family',
  family_member_removed: 'Family',
}

// ── Feature-specific event lists ──
export const FEATURE_EVENTS: Record<string, string[]> = {
  Hydration: Object.keys(FEATURE_CATEGORIES).filter(k => FEATURE_CATEGORIES[k] === 'Hydration'),
  Medication: Object.keys(FEATURE_CATEGORIES).filter(k => FEATURE_CATEGORIES[k] === 'Medication'),
  Workout: Object.keys(FEATURE_CATEGORIES).filter(k => FEATURE_CATEGORIES[k] === 'Workout'),
  AI: Object.keys(FEATURE_CATEGORIES).filter(k => FEATURE_CATEGORIES[k] === 'AI'),
  Vault: Object.keys(FEATURE_CATEGORIES).filter(k => FEATURE_CATEGORIES[k] === 'Vault'),
  'Heart Rate': Object.keys(FEATURE_CATEGORIES).filter(k => FEATURE_CATEGORIES[k] === 'Heart Rate'),
}

// ── Colors ──
export const CHART_COLORS = {
  indigo: '#4F46E5',
  green: '#22C55E',
  blue: '#3B82F6',
  purple: '#8B5CF6',
  amber: '#F59E0B',
  red: '#EF4444',
  cyan: '#06B6D4',
  pink: '#EC4899',
  orange: '#F97316',
  teal: '#14B8A6',
}

export const PLATFORM_COLORS: Record<string, string> = {
  iOS: '#3B82F6',
  Android: '#22C55E',
  Unknown: '#6B7280',
}

export const FEATURE_COLORS: Record<string, string> = {
  Hydration: '#3B82F6',
  Medication: '#8B5CF6',
  Workout: '#22C55E',
  AI: '#F59E0B',
  Vault: '#06B6D4',
  'Heart Rate': '#EF4444',
  Diet: '#F97316',
  Auth: '#EC4899',
  Onboarding: '#14B8A6',
  Menstrual: '#A855F7',
  Family: '#6366F1',
}

export const EVENT_TYPE_COLORS: Record<string, string> = {
  navigation: '#3B82F6',
  action: '#22C55E',
  error: '#EF4444',
  count: '#F59E0B',
  feature_usage: '#8B5CF6',
  auth: '#EC4899',
  screen: '#06B6D4',
}

export const PALETTE = [
  '#4F46E5', '#22C55E', '#F59E0B', '#EF4444', '#8B5CF6',
  '#06B6D4', '#EC4899', '#F97316', '#14B8A6', '#6366F1',
]

// ── Day names ──
export const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
export const DAY_NAMES_FULL = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

// ── Range options ──
export const RANGE_OPTIONS = [
  { label: '24h', value: '1' as const },
  { label: '7d', value: '7' as const },
  { label: '14d', value: '14' as const },
  { label: '30d', value: '30' as const },
  { label: '90d', value: '90' as const },
]

// ── Navigation ──
export const NAV_ITEMS = [
  { label: 'Overview', href: '/', icon: 'home' },
  { label: 'Platform', href: '/platform', icon: 'device' },
  { label: 'Screens', href: '/screens', icon: 'screen' },
  { label: 'Features', href: '/features', icon: 'feature' },
  { label: 'Users', href: '/users', icon: 'users' },
  { label: 'Engagement', href: '/engagement', icon: 'engagement' },
  { label: 'Errors', href: '/errors', icon: 'error' },
]
