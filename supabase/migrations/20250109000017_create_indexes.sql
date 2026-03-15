-- ============================================================================
-- ADDITIONAL PERFORMANCE INDEXES
-- ============================================================================
-- Cross-module indexes and additional performance optimizations

-- ============================================================================
-- CROSS-MODULE INDEXES
-- ============================================================================

-- Activity timeline (for dashboard/feed)
CREATE INDEX IF NOT EXISTS idx_activity_timeline_medications ON public.medication_logs(health_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_timeline_appointments ON public.appointments(health_profile_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_timeline_vitals ON public.vital_signs(health_profile_id, measured_at DESC);

-- Search indexes
CREATE INDEX IF NOT EXISTS idx_medications_name_search ON public.medications USING gin(to_tsvector('english', name));
CREATE INDEX IF NOT EXISTS idx_doctors_name_search ON public.doctors USING gin(to_tsvector('english', name));
CREATE INDEX IF NOT EXISTS idx_healthcare_facilities_name_search ON public.healthcare_facilities USING gin(to_tsvector('english', name));

-- Date range queries (common pattern)
CREATE INDEX IF NOT EXISTS idx_medical_documents_date_range ON public.medical_documents(health_profile_id, document_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_medical_expenses_date_range ON public.medical_expenses(health_profile_id, expense_date DESC);

-- Active/pending items
CREATE INDEX IF NOT EXISTS idx_appointments_upcoming ON public.appointments(health_profile_id, scheduled_at) 
    WHERE status IN ('scheduled', 'confirmed') ;
CREATE INDEX IF NOT EXISTS idx_prescriptions_active ON public.prescriptions(health_profile_id) 
    WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_insurance_claims_pending ON public.insurance_claims(health_profile_id) 
    WHERE status IN ('submitted', 'under_review', 'query_raised');

-- ============================================================================
-- COMPOSITE INDEXES FOR COMMON QUERIES
-- ============================================================================

-- User dashboard queries
CREATE INDEX IF NOT EXISTS idx_user_dashboard_streaks ON public.user_streaks(health_profile_id, streak_type, current_streak DESC);
CREATE INDEX IF NOT EXISTS idx_user_dashboard_goals ON public.health_goals(health_profile_id, status, priority);
CREATE INDEX IF NOT EXISTS idx_user_dashboard_achievements ON public.achievements(health_profile_id, unlocked_at DESC) 
    WHERE is_unlocked = true;

-- Family member access patterns
CREATE INDEX IF NOT EXISTS idx_family_access_check ON public.family_members(health_profile_id, family_group_id, status);

-- Notification delivery
CREATE INDEX IF NOT EXISTS idx_notifications_delivery ON public.notifications(user_id, created_at DESC, is_read);

-- Chat consultation responses
CREATE INDEX IF NOT EXISTS idx_chat_response_time ON public.chat_messages(consultation_id, created_at, sender_type);

-- ============================================================================
-- ANALYTICS INDEXES
-- ============================================================================

-- Medication adherence tracking
CREATE INDEX IF NOT EXISTS idx_medication_adherence ON public.medication_logs(health_profile_id, status);

-- Health metrics aggregation
CREATE INDEX IF NOT EXISTS idx_daily_metrics_aggregation ON public.daily_health_metrics(health_profile_id, metric_date);
CREATE INDEX IF NOT EXISTS idx_hydration_aggregation ON public.hydration_logs(health_profile_id);
CREATE INDEX IF NOT EXISTS idx_nutrition_aggregation ON public.nutrition_logs(health_profile_id, meal_type);

-- Lab result trends
CREATE INDEX IF NOT EXISTS idx_lab_results_trends ON public.lab_test_results(health_profile_id, test_code, created_at);

-- Device reading analytics
CREATE INDEX IF NOT EXISTS idx_device_analytics ON public.device_readings(health_profile_id, reading_type);

-- ============================================================================
-- FOREIGN KEY INDEXES (ensuring FK columns are indexed)
-- ============================================================================

-- These indexes improve JOIN performance and FK constraint checks
CREATE INDEX IF NOT EXISTS idx_fk_medication_schedules_med ON public.medication_schedules(medication_id);
CREATE INDEX IF NOT EXISTS idx_fk_medication_logs_schedule ON public.medication_logs(schedule_id);
CREATE INDEX IF NOT EXISTS idx_fk_prescription_items_med ON public.prescription_items(medication_id);
CREATE INDEX IF NOT EXISTS idx_fk_lab_reports_document ON public.lab_reports(document_id);
CREATE INDEX IF NOT EXISTS idx_fk_insurance_claims_hospital ON public.insurance_claims(hospital_id);

-- ============================================================================
-- PARTIAL INDEXES FOR SPECIFIC QUERIES
-- ============================================================================

-- Premium users
CREATE INDEX IF NOT EXISTS idx_premium_users ON public.users(id) WHERE is_premium = true;

-- Verified doctors
CREATE INDEX IF NOT EXISTS idx_verified_doctors ON public.doctors(id, specialization_id) WHERE is_verified = true;

-- High priority insights
CREATE INDEX IF NOT EXISTS idx_high_priority_insights ON public.ai_insights(health_profile_id, created_at DESC) 
    WHERE priority IN ('high', 'urgent') AND is_dismissed = false;

-- Upcoming reminders
CREATE INDEX IF NOT EXISTS idx_upcoming_reminders ON public.reminders(health_profile_id, scheduled_time) 
    WHERE is_active = true;

-- ============================================================================
-- STATISTICS UPDATE
-- ============================================================================

-- Analyze tables for query planner (run this after initial data load)
-- ANALYZE public.users;
-- ANALYZE public.health_profiles;
-- ANALYZE public.medications;
-- etc.

-- ============================================================================
-- NOTES
-- ============================================================================
-- 
-- Index naming convention:
-- - idx_{table}_{column(s)} for single/multi-column indexes
-- - idx_{table}_{purpose} for functional/partial indexes
-- - idx_fk_{table}_{column} for foreign key indexes
--
-- Performance tips:
-- 1. Run ANALYZE after bulk data loads
-- 2. Monitor pg_stat_user_indexes for unused indexes
-- 3. Use EXPLAIN ANALYZE to verify index usage
-- 4. Consider partitioning for very large tables (device_readings, etc.)
