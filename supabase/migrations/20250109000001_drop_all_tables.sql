-- ============================================================================
-- DROP ALL TABLES - COMPLETE DATABASE RESET
-- ============================================================================
-- This migration drops ALL existing tables to prepare for fresh schema

-- Drop future module tables (if they exist)
DROP TABLE IF EXISTS public.pregnancy_logs CASCADE;
DROP TABLE IF EXISTS public.pregnancy_tracking CASCADE;
DROP TABLE IF EXISTS public.menstrual_cycles CASCADE;
DROP TABLE IF EXISTS public.user_programs CASCADE;
DROP TABLE IF EXISTS public.health_programs CASCADE;
DROP TABLE IF EXISTS public.goal_milestones CASCADE;
DROP TABLE IF EXISTS public.health_goals CASCADE;
DROP TABLE IF EXISTS public.device_readings CASCADE;
DROP TABLE IF EXISTS public.connected_devices CASCADE;
DROP TABLE IF EXISTS public.chat_messages CASCADE;
DROP TABLE IF EXISTS public.chat_consultations CASCADE;
DROP TABLE IF EXISTS public.video_consultations CASCADE;
DROP TABLE IF EXISTS public.medical_expenses CASCADE;
DROP TABLE IF EXISTS public.insurance_claims CASCADE;
DROP TABLE IF EXISTS public.insurance_policies CASCADE;
DROP TABLE IF EXISTS public.insurance_providers CASCADE;
DROP TABLE IF EXISTS public.my_pharmacies CASCADE;
DROP TABLE IF EXISTS public.medicine_orders CASCADE;
DROP TABLE IF EXISTS public.pharmacies CASCADE;
DROP TABLE IF EXISTS public.prescription_items CASCADE;
DROP TABLE IF EXISTS public.prescriptions CASCADE;
DROP TABLE IF EXISTS public.doctor_reviews CASCADE;
DROP TABLE IF EXISTS public.my_doctors CASCADE;
DROP TABLE IF EXISTS public.doctor_facilities CASCADE;
DROP TABLE IF EXISTS public.doctors CASCADE;
DROP TABLE IF EXISTS public.healthcare_facilities CASCADE;
DROP TABLE IF EXISTS public.medical_specializations CASCADE;
DROP TABLE IF EXISTS public.lab_report_shares CASCADE;
DROP TABLE IF EXISTS public.lab_test_results CASCADE;
DROP TABLE IF EXISTS public.lab_reports CASCADE;
DROP TABLE IF EXISTS public.lab_test_catalog CASCADE;

-- Drop engagement module tables
DROP TABLE IF EXISTS public.achievements CASCADE;
DROP TABLE IF EXISTS public.user_streaks CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.reminder_logs CASCADE;
DROP TABLE IF EXISTS public.reminders CASCADE;

-- Drop AI module tables
DROP TABLE IF EXISTS public.ai_usage_logs CASCADE;
DROP TABLE IF EXISTS public.ai_image_analysis CASCADE;
DROP TABLE IF EXISTS public.ai_insights CASCADE;
DROP TABLE IF EXISTS public.ai_conversations CASCADE;

-- Drop conditions module tables
DROP TABLE IF EXISTS public.emergency_contacts CASCADE;
DROP TABLE IF EXISTS public.allergies CASCADE;
DROP TABLE IF EXISTS public.chronic_conditions CASCADE;

-- Drop medical records module tables
DROP TABLE IF EXISTS public.appointment_notes CASCADE;
DROP TABLE IF EXISTS public.appointments CASCADE;
DROP TABLE IF EXISTS public.healthcare_providers CASCADE;
DROP TABLE IF EXISTS public.medical_documents CASCADE;
DROP TABLE IF EXISTS public.document_folders CASCADE;

-- Drop health metrics module tables
DROP TABLE IF EXISTS public.nutrition_logs CASCADE;
DROP TABLE IF EXISTS public.hydration_logs CASCADE;
DROP TABLE IF EXISTS public.activity_logs CASCADE;
DROP TABLE IF EXISTS public.vital_signs CASCADE;
DROP TABLE IF EXISTS public.daily_health_metrics CASCADE;

-- Drop medications module tables
DROP TABLE IF EXISTS public.medication_logs CASCADE;
DROP TABLE IF EXISTS public.medication_schedules CASCADE;
DROP TABLE IF EXISTS public.medications CASCADE;

-- Drop family module tables
DROP TABLE IF EXISTS public.family_members CASCADE;
DROP TABLE IF EXISTS public.family_groups CASCADE;

-- Drop core tables
DROP TABLE IF EXISTS public.user_settings CASCADE;
DROP TABLE IF EXISTS public.health_profiles CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Drop helper functions
DROP FUNCTION IF EXISTS public.has_family_access CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at CASCADE;
