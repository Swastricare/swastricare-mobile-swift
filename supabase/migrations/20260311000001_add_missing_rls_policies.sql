-- ============================================================================
-- ADD MISSING ROW LEVEL SECURITY POLICIES
-- ============================================================================
-- This migration adds RLS policies to all tables that currently lack them.
-- Uses the has_family_access() function for health_profile_id based access.
-- Read-only catalog tables allow SELECT for all authenticated users.

-- ============================================================================
-- CORE BASE TABLES
-- ============================================================================

-- Users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own data" ON public.users;
CREATE POLICY "Users can view own data" ON public.users
    FOR SELECT USING (id = auth.uid());

DROP POLICY IF EXISTS "Users can update own data" ON public.users;
CREATE POLICY "Users can update own data" ON public.users
    FOR UPDATE USING (id = auth.uid());

-- Health profiles table
ALTER TABLE public.health_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profiles" ON public.health_profiles;
CREATE POLICY "Users can view own profiles" ON public.health_profiles
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own profiles" ON public.health_profiles;
CREATE POLICY "Users can insert own profiles" ON public.health_profiles
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own profiles" ON public.health_profiles;
CREATE POLICY "Users can update own profiles" ON public.health_profiles
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own profiles" ON public.health_profiles;
CREATE POLICY "Users can delete own profiles" ON public.health_profiles
    FOR DELETE USING (user_id = auth.uid());

-- User settings table
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own settings" ON public.user_settings;
CREATE POLICY "Users can view own settings" ON public.user_settings
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own settings" ON public.user_settings;
CREATE POLICY "Users can insert own settings" ON public.user_settings
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own settings" ON public.user_settings;
CREATE POLICY "Users can update own settings" ON public.user_settings
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own settings" ON public.user_settings;
CREATE POLICY "Users can delete own settings" ON public.user_settings
    FOR DELETE USING (user_id = auth.uid());

-- Family groups table
ALTER TABLE public.family_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own family groups" ON public.family_groups;
CREATE POLICY "Users can view own family groups" ON public.family_groups
    FOR SELECT USING (owner_user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own family groups" ON public.family_groups;
CREATE POLICY "Users can insert own family groups" ON public.family_groups
    FOR INSERT WITH CHECK (owner_user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own family groups" ON public.family_groups;
CREATE POLICY "Users can update own family groups" ON public.family_groups
    FOR UPDATE USING (owner_user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own family groups" ON public.family_groups;
CREATE POLICY "Users can delete own family groups" ON public.family_groups
    FOR DELETE USING (owner_user_id = auth.uid());

-- Family members table
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view family members" ON public.family_members;
CREATE POLICY "Users can view family members" ON public.family_members
    FOR SELECT USING (
        family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert family members" ON public.family_members;
CREATE POLICY "Users can insert family members" ON public.family_members
    FOR INSERT WITH CHECK (
        family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can update family members" ON public.family_members;
CREATE POLICY "Users can update family members" ON public.family_members
    FOR UPDATE USING (
        family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can delete family members" ON public.family_members;
CREATE POLICY "Users can delete family members" ON public.family_members
    FOR DELETE USING (
        family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
    );

-- ============================================================================
-- MEDICATIONS MODULE
-- ============================================================================

-- Medications table
ALTER TABLE public.medications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own medications" ON public.medications;
CREATE POLICY "Users can view own medications" ON public.medications
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own medications" ON public.medications;
CREATE POLICY "Users can insert own medications" ON public.medications
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own medications" ON public.medications;
CREATE POLICY "Users can update own medications" ON public.medications
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own medications" ON public.medications;
CREATE POLICY "Users can delete own medications" ON public.medications
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Medication schedules table
ALTER TABLE public.medication_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own medication schedules" ON public.medication_schedules;
CREATE POLICY "Users can view own medication schedules" ON public.medication_schedules
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own medication schedules" ON public.medication_schedules;
CREATE POLICY "Users can insert own medication schedules" ON public.medication_schedules
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own medication schedules" ON public.medication_schedules;
CREATE POLICY "Users can update own medication schedules" ON public.medication_schedules
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own medication schedules" ON public.medication_schedules;
CREATE POLICY "Users can delete own medication schedules" ON public.medication_schedules
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Medication logs table
ALTER TABLE public.medication_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own medication logs" ON public.medication_logs;
CREATE POLICY "Users can view own medication logs" ON public.medication_logs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own medication logs" ON public.medication_logs;
CREATE POLICY "Users can insert own medication logs" ON public.medication_logs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own medication logs" ON public.medication_logs;
CREATE POLICY "Users can update own medication logs" ON public.medication_logs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own medication logs" ON public.medication_logs;
CREATE POLICY "Users can delete own medication logs" ON public.medication_logs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- HEALTH METRICS MODULE
-- ============================================================================

-- Daily health metrics table
ALTER TABLE public.daily_health_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own daily metrics" ON public.daily_health_metrics;
CREATE POLICY "Users can view own daily metrics" ON public.daily_health_metrics
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own daily metrics" ON public.daily_health_metrics;
CREATE POLICY "Users can insert own daily metrics" ON public.daily_health_metrics
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own daily metrics" ON public.daily_health_metrics;
CREATE POLICY "Users can update own daily metrics" ON public.daily_health_metrics
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own daily metrics" ON public.daily_health_metrics;
CREATE POLICY "Users can delete own daily metrics" ON public.daily_health_metrics
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Vital signs table
ALTER TABLE public.vital_signs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own vital signs" ON public.vital_signs;
CREATE POLICY "Users can view own vital signs" ON public.vital_signs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own vital signs" ON public.vital_signs;
CREATE POLICY "Users can insert own vital signs" ON public.vital_signs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own vital signs" ON public.vital_signs;
CREATE POLICY "Users can update own vital signs" ON public.vital_signs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own vital signs" ON public.vital_signs;
CREATE POLICY "Users can delete own vital signs" ON public.vital_signs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Activity logs table
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own activity logs" ON public.activity_logs;
CREATE POLICY "Users can view own activity logs" ON public.activity_logs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own activity logs" ON public.activity_logs;
CREATE POLICY "Users can insert own activity logs" ON public.activity_logs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own activity logs" ON public.activity_logs;
CREATE POLICY "Users can update own activity logs" ON public.activity_logs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own activity logs" ON public.activity_logs;
CREATE POLICY "Users can delete own activity logs" ON public.activity_logs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Hydration logs table
ALTER TABLE public.hydration_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own hydration logs" ON public.hydration_logs;
CREATE POLICY "Users can view own hydration logs" ON public.hydration_logs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own hydration logs" ON public.hydration_logs;
CREATE POLICY "Users can insert own hydration logs" ON public.hydration_logs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own hydration logs" ON public.hydration_logs;
CREATE POLICY "Users can update own hydration logs" ON public.hydration_logs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own hydration logs" ON public.hydration_logs;
CREATE POLICY "Users can delete own hydration logs" ON public.hydration_logs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Nutrition logs table
ALTER TABLE public.nutrition_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own nutrition logs" ON public.nutrition_logs;
CREATE POLICY "Users can view own nutrition logs" ON public.nutrition_logs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own nutrition logs" ON public.nutrition_logs;
CREATE POLICY "Users can insert own nutrition logs" ON public.nutrition_logs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own nutrition logs" ON public.nutrition_logs;
CREATE POLICY "Users can update own nutrition logs" ON public.nutrition_logs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own nutrition logs" ON public.nutrition_logs;
CREATE POLICY "Users can delete own nutrition logs" ON public.nutrition_logs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- MEDICAL RECORDS MODULE
-- ============================================================================

-- Document folders table
ALTER TABLE public.document_folders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own document folders" ON public.document_folders;
CREATE POLICY "Users can view own document folders" ON public.document_folders
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own document folders" ON public.document_folders;
CREATE POLICY "Users can insert own document folders" ON public.document_folders
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own document folders" ON public.document_folders;
CREATE POLICY "Users can update own document folders" ON public.document_folders
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own document folders" ON public.document_folders;
CREATE POLICY "Users can delete own document folders" ON public.document_folders
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Medical documents table
ALTER TABLE public.medical_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own medical documents" ON public.medical_documents;
CREATE POLICY "Users can view own medical documents" ON public.medical_documents
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own medical documents" ON public.medical_documents;
CREATE POLICY "Users can insert own medical documents" ON public.medical_documents
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own medical documents" ON public.medical_documents;
CREATE POLICY "Users can update own medical documents" ON public.medical_documents
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own medical documents" ON public.medical_documents;
CREATE POLICY "Users can delete own medical documents" ON public.medical_documents
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Healthcare providers table
ALTER TABLE public.healthcare_providers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own healthcare providers" ON public.healthcare_providers;
CREATE POLICY "Users can view own healthcare providers" ON public.healthcare_providers
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own healthcare providers" ON public.healthcare_providers;
CREATE POLICY "Users can insert own healthcare providers" ON public.healthcare_providers
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own healthcare providers" ON public.healthcare_providers;
CREATE POLICY "Users can update own healthcare providers" ON public.healthcare_providers
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own healthcare providers" ON public.healthcare_providers;
CREATE POLICY "Users can delete own healthcare providers" ON public.healthcare_providers
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Appointments table
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own appointments" ON public.appointments;
CREATE POLICY "Users can view own appointments" ON public.appointments
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own appointments" ON public.appointments;
CREATE POLICY "Users can insert own appointments" ON public.appointments
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own appointments" ON public.appointments;
CREATE POLICY "Users can update own appointments" ON public.appointments
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own appointments" ON public.appointments;
CREATE POLICY "Users can delete own appointments" ON public.appointments
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Appointment notes table
ALTER TABLE public.appointment_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own appointment notes" ON public.appointment_notes;
CREATE POLICY "Users can view own appointment notes" ON public.appointment_notes
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own appointment notes" ON public.appointment_notes;
CREATE POLICY "Users can insert own appointment notes" ON public.appointment_notes
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own appointment notes" ON public.appointment_notes;
CREATE POLICY "Users can update own appointment notes" ON public.appointment_notes
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own appointment notes" ON public.appointment_notes;
CREATE POLICY "Users can delete own appointment notes" ON public.appointment_notes
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- CONDITIONS MODULE
-- ============================================================================

-- Chronic conditions table
ALTER TABLE public.chronic_conditions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own chronic conditions" ON public.chronic_conditions;
CREATE POLICY "Users can view own chronic conditions" ON public.chronic_conditions
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own chronic conditions" ON public.chronic_conditions;
CREATE POLICY "Users can insert own chronic conditions" ON public.chronic_conditions
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own chronic conditions" ON public.chronic_conditions;
CREATE POLICY "Users can update own chronic conditions" ON public.chronic_conditions
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own chronic conditions" ON public.chronic_conditions;
CREATE POLICY "Users can delete own chronic conditions" ON public.chronic_conditions
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Allergies table
ALTER TABLE public.allergies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own allergies" ON public.allergies;
CREATE POLICY "Users can view own allergies" ON public.allergies
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own allergies" ON public.allergies;
CREATE POLICY "Users can insert own allergies" ON public.allergies
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own allergies" ON public.allergies;
CREATE POLICY "Users can update own allergies" ON public.allergies
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own allergies" ON public.allergies;
CREATE POLICY "Users can delete own allergies" ON public.allergies
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Emergency contacts table
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own emergency contacts" ON public.emergency_contacts;
CREATE POLICY "Users can view own emergency contacts" ON public.emergency_contacts
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own emergency contacts" ON public.emergency_contacts;
CREATE POLICY "Users can insert own emergency contacts" ON public.emergency_contacts
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own emergency contacts" ON public.emergency_contacts;
CREATE POLICY "Users can update own emergency contacts" ON public.emergency_contacts
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own emergency contacts" ON public.emergency_contacts;
CREATE POLICY "Users can delete own emergency contacts" ON public.emergency_contacts
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- AI MODULE
-- ============================================================================

-- AI conversations table
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own AI conversations" ON public.ai_conversations;
CREATE POLICY "Users can view own AI conversations" ON public.ai_conversations
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own AI conversations" ON public.ai_conversations;
CREATE POLICY "Users can insert own AI conversations" ON public.ai_conversations
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own AI conversations" ON public.ai_conversations;
CREATE POLICY "Users can update own AI conversations" ON public.ai_conversations
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own AI conversations" ON public.ai_conversations;
CREATE POLICY "Users can delete own AI conversations" ON public.ai_conversations
    FOR DELETE USING (user_id = auth.uid());

-- AI insights table
ALTER TABLE public.ai_insights ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own AI insights" ON public.ai_insights;
CREATE POLICY "Users can view own AI insights" ON public.ai_insights
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own AI insights" ON public.ai_insights;
CREATE POLICY "Users can insert own AI insights" ON public.ai_insights
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Users can update own AI insights" ON public.ai_insights;
CREATE POLICY "Users can update own AI insights" ON public.ai_insights
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Users can delete own AI insights" ON public.ai_insights;
CREATE POLICY "Users can delete own AI insights" ON public.ai_insights
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

-- AI image analysis table
ALTER TABLE public.ai_image_analysis ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own AI image analysis" ON public.ai_image_analysis;
CREATE POLICY "Users can view own AI image analysis" ON public.ai_image_analysis
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own AI image analysis" ON public.ai_image_analysis;
CREATE POLICY "Users can insert own AI image analysis" ON public.ai_image_analysis
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own AI image analysis" ON public.ai_image_analysis;
CREATE POLICY "Users can update own AI image analysis" ON public.ai_image_analysis
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own AI image analysis" ON public.ai_image_analysis;
CREATE POLICY "Users can delete own AI image analysis" ON public.ai_image_analysis
    FOR DELETE USING (user_id = auth.uid());

-- AI usage logs table
ALTER TABLE public.ai_usage_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own AI usage logs" ON public.ai_usage_logs;
CREATE POLICY "Users can view own AI usage logs" ON public.ai_usage_logs
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own AI usage logs" ON public.ai_usage_logs;
CREATE POLICY "Users can insert own AI usage logs" ON public.ai_usage_logs
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- ENGAGEMENT MODULE
-- ============================================================================

-- Reminders table
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own reminders" ON public.reminders;
CREATE POLICY "Users can view own reminders" ON public.reminders
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own reminders" ON public.reminders;
CREATE POLICY "Users can insert own reminders" ON public.reminders
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own reminders" ON public.reminders;
CREATE POLICY "Users can update own reminders" ON public.reminders
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own reminders" ON public.reminders;
CREATE POLICY "Users can delete own reminders" ON public.reminders
    FOR DELETE USING (user_id = auth.uid());

-- Reminder logs table
ALTER TABLE public.reminder_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own reminder logs" ON public.reminder_logs;
CREATE POLICY "Users can view own reminder logs" ON public.reminder_logs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own reminder logs" ON public.reminder_logs;
CREATE POLICY "Users can insert own reminder logs" ON public.reminder_logs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own reminder logs" ON public.reminder_logs;
CREATE POLICY "Users can update own reminder logs" ON public.reminder_logs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own reminder logs" ON public.reminder_logs;
CREATE POLICY "Users can delete own reminder logs" ON public.reminder_logs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Notifications table
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own notifications" ON public.notifications;
CREATE POLICY "Users can insert own notifications" ON public.notifications
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications" ON public.notifications
    FOR DELETE USING (user_id = auth.uid());

-- User streaks table
ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own user streaks" ON public.user_streaks;
CREATE POLICY "Users can view own user streaks" ON public.user_streaks
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own user streaks" ON public.user_streaks;
CREATE POLICY "Users can insert own user streaks" ON public.user_streaks
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Users can update own user streaks" ON public.user_streaks;
CREATE POLICY "Users can update own user streaks" ON public.user_streaks
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Users can delete own user streaks" ON public.user_streaks;
CREATE POLICY "Users can delete own user streaks" ON public.user_streaks
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

-- Achievements table
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own achievements" ON public.achievements;
CREATE POLICY "Users can view own achievements" ON public.achievements
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own achievements" ON public.achievements;
CREATE POLICY "Users can insert own achievements" ON public.achievements
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Users can update own achievements" ON public.achievements;
CREATE POLICY "Users can update own achievements" ON public.achievements
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Users can delete own achievements" ON public.achievements;
CREATE POLICY "Users can delete own achievements" ON public.achievements
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    );

-- ============================================================================
-- LAB REPORTS MODULE
-- ============================================================================

-- Lab test catalog table (READ-ONLY CATALOG)
ALTER TABLE public.lab_test_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view lab test catalog" ON public.lab_test_catalog;
CREATE POLICY "Authenticated users can view lab test catalog" ON public.lab_test_catalog
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Lab reports table
ALTER TABLE public.lab_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own lab reports" ON public.lab_reports;
CREATE POLICY "Users can view own lab reports" ON public.lab_reports
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own lab reports" ON public.lab_reports;
CREATE POLICY "Users can insert own lab reports" ON public.lab_reports
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own lab reports" ON public.lab_reports;
CREATE POLICY "Users can update own lab reports" ON public.lab_reports
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own lab reports" ON public.lab_reports;
CREATE POLICY "Users can delete own lab reports" ON public.lab_reports
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Lab test results table
ALTER TABLE public.lab_test_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own lab test results" ON public.lab_test_results;
CREATE POLICY "Users can view own lab test results" ON public.lab_test_results
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own lab test results" ON public.lab_test_results;
CREATE POLICY "Users can insert own lab test results" ON public.lab_test_results
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own lab test results" ON public.lab_test_results;
CREATE POLICY "Users can update own lab test results" ON public.lab_test_results
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own lab test results" ON public.lab_test_results;
CREATE POLICY "Users can delete own lab test results" ON public.lab_test_results
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Lab report shares table
ALTER TABLE public.lab_report_shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own lab report shares" ON public.lab_report_shares;
CREATE POLICY "Users can view own lab report shares" ON public.lab_report_shares
    FOR SELECT USING (shared_by = auth.uid());

DROP POLICY IF EXISTS "Users can insert own lab report shares" ON public.lab_report_shares;
CREATE POLICY "Users can insert own lab report shares" ON public.lab_report_shares
    FOR INSERT WITH CHECK (shared_by = auth.uid());

DROP POLICY IF EXISTS "Users can update own lab report shares" ON public.lab_report_shares;
CREATE POLICY "Users can update own lab report shares" ON public.lab_report_shares
    FOR UPDATE USING (shared_by = auth.uid());

DROP POLICY IF EXISTS "Users can delete own lab report shares" ON public.lab_report_shares;
CREATE POLICY "Users can delete own lab report shares" ON public.lab_report_shares
    FOR DELETE USING (shared_by = auth.uid());

-- ============================================================================
-- DOCTORS MODULE
-- ============================================================================

-- Medical specializations table (READ-ONLY CATALOG)
ALTER TABLE public.medical_specializations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view medical specializations" ON public.medical_specializations;
CREATE POLICY "Authenticated users can view medical specializations" ON public.medical_specializations
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Healthcare facilities table (READ-ONLY CATALOG)
ALTER TABLE public.healthcare_facilities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view healthcare facilities" ON public.healthcare_facilities;
CREATE POLICY "Authenticated users can view healthcare facilities" ON public.healthcare_facilities
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Doctors table (READ-ONLY CATALOG)
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view doctors" ON public.doctors;
CREATE POLICY "Authenticated users can view doctors" ON public.doctors
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Doctor facilities table (READ-ONLY CATALOG)
ALTER TABLE public.doctor_facilities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view doctor facilities" ON public.doctor_facilities;
CREATE POLICY "Authenticated users can view doctor facilities" ON public.doctor_facilities
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- My doctors table
ALTER TABLE public.my_doctors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own my doctors" ON public.my_doctors;
CREATE POLICY "Users can view own my doctors" ON public.my_doctors
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own my doctors" ON public.my_doctors;
CREATE POLICY "Users can insert own my doctors" ON public.my_doctors
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own my doctors" ON public.my_doctors;
CREATE POLICY "Users can update own my doctors" ON public.my_doctors
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own my doctors" ON public.my_doctors;
CREATE POLICY "Users can delete own my doctors" ON public.my_doctors
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Doctor reviews table
ALTER TABLE public.doctor_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all doctor reviews" ON public.doctor_reviews;
CREATE POLICY "Users can view all doctor reviews" ON public.doctor_reviews
    FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can insert own doctor reviews" ON public.doctor_reviews;
CREATE POLICY "Users can insert own doctor reviews" ON public.doctor_reviews
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own doctor reviews" ON public.doctor_reviews;
CREATE POLICY "Users can update own doctor reviews" ON public.doctor_reviews
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own doctor reviews" ON public.doctor_reviews;
CREATE POLICY "Users can delete own doctor reviews" ON public.doctor_reviews
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================================
-- PRESCRIPTIONS & PHARMACY MODULE
-- ============================================================================

-- Prescriptions table
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own prescriptions" ON public.prescriptions;
CREATE POLICY "Users can view own prescriptions" ON public.prescriptions
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own prescriptions" ON public.prescriptions;
CREATE POLICY "Users can insert own prescriptions" ON public.prescriptions
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own prescriptions" ON public.prescriptions;
CREATE POLICY "Users can update own prescriptions" ON public.prescriptions
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own prescriptions" ON public.prescriptions;
CREATE POLICY "Users can delete own prescriptions" ON public.prescriptions
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Prescription items table
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own prescription items" ON public.prescription_items;
CREATE POLICY "Users can view own prescription items" ON public.prescription_items
    FOR SELECT USING (
        prescription_id IN (
            SELECT id FROM public.prescriptions WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_view'::text)
        )
    );

DROP POLICY IF EXISTS "Users can insert own prescription items" ON public.prescription_items;
CREATE POLICY "Users can insert own prescription items" ON public.prescription_items
    FOR INSERT WITH CHECK (
        prescription_id IN (
            SELECT id FROM public.prescriptions WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

DROP POLICY IF EXISTS "Users can update own prescription items" ON public.prescription_items;
CREATE POLICY "Users can update own prescription items" ON public.prescription_items
    FOR UPDATE USING (
        prescription_id IN (
            SELECT id FROM public.prescriptions WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

DROP POLICY IF EXISTS "Users can delete own prescription items" ON public.prescription_items;
CREATE POLICY "Users can delete own prescription items" ON public.prescription_items
    FOR DELETE USING (
        prescription_id IN (
            SELECT id FROM public.prescriptions WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

-- Pharmacies table (READ-ONLY CATALOG)
ALTER TABLE public.pharmacies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view pharmacies" ON public.pharmacies;
CREATE POLICY "Authenticated users can view pharmacies" ON public.pharmacies
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Medicine orders table
ALTER TABLE public.medicine_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own medicine orders" ON public.medicine_orders;
CREATE POLICY "Users can view own medicine orders" ON public.medicine_orders
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own medicine orders" ON public.medicine_orders;
CREATE POLICY "Users can insert own medicine orders" ON public.medicine_orders
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own medicine orders" ON public.medicine_orders;
CREATE POLICY "Users can update own medicine orders" ON public.medicine_orders
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own medicine orders" ON public.medicine_orders;
CREATE POLICY "Users can delete own medicine orders" ON public.medicine_orders
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- My pharmacies table
ALTER TABLE public.my_pharmacies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own my pharmacies" ON public.my_pharmacies;
CREATE POLICY "Users can view own my pharmacies" ON public.my_pharmacies
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own my pharmacies" ON public.my_pharmacies;
CREATE POLICY "Users can insert own my pharmacies" ON public.my_pharmacies
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own my pharmacies" ON public.my_pharmacies;
CREATE POLICY "Users can update own my pharmacies" ON public.my_pharmacies
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own my pharmacies" ON public.my_pharmacies;
CREATE POLICY "Users can delete own my pharmacies" ON public.my_pharmacies
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- INSURANCE & BILLING MODULE
-- ============================================================================

-- Insurance providers table (READ-ONLY CATALOG)
ALTER TABLE public.insurance_providers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view insurance providers" ON public.insurance_providers;
CREATE POLICY "Authenticated users can view insurance providers" ON public.insurance_providers
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Insurance policies table
ALTER TABLE public.insurance_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own insurance policies" ON public.insurance_policies;
CREATE POLICY "Users can view own insurance policies" ON public.insurance_policies
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own insurance policies" ON public.insurance_policies;
CREATE POLICY "Users can insert own insurance policies" ON public.insurance_policies
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own insurance policies" ON public.insurance_policies;
CREATE POLICY "Users can update own insurance policies" ON public.insurance_policies
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own insurance policies" ON public.insurance_policies;
CREATE POLICY "Users can delete own insurance policies" ON public.insurance_policies
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Insurance claims table
ALTER TABLE public.insurance_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own insurance claims" ON public.insurance_claims;
CREATE POLICY "Users can view own insurance claims" ON public.insurance_claims
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own insurance claims" ON public.insurance_claims;
CREATE POLICY "Users can insert own insurance claims" ON public.insurance_claims
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own insurance claims" ON public.insurance_claims;
CREATE POLICY "Users can update own insurance claims" ON public.insurance_claims
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own insurance claims" ON public.insurance_claims;
CREATE POLICY "Users can delete own insurance claims" ON public.insurance_claims
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Medical expenses table
ALTER TABLE public.medical_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own medical expenses" ON public.medical_expenses;
CREATE POLICY "Users can view own medical expenses" ON public.medical_expenses
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own medical expenses" ON public.medical_expenses;
CREATE POLICY "Users can insert own medical expenses" ON public.medical_expenses
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own medical expenses" ON public.medical_expenses;
CREATE POLICY "Users can update own medical expenses" ON public.medical_expenses
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own medical expenses" ON public.medical_expenses;
CREATE POLICY "Users can delete own medical expenses" ON public.medical_expenses
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- TELEMEDICINE MODULE
-- ============================================================================

-- Video consultations table
ALTER TABLE public.video_consultations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own video consultations" ON public.video_consultations;
CREATE POLICY "Users can view own video consultations" ON public.video_consultations
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own video consultations" ON public.video_consultations;
CREATE POLICY "Users can insert own video consultations" ON public.video_consultations
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own video consultations" ON public.video_consultations;
CREATE POLICY "Users can update own video consultations" ON public.video_consultations
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own video consultations" ON public.video_consultations;
CREATE POLICY "Users can delete own video consultations" ON public.video_consultations
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Chat consultations table
ALTER TABLE public.chat_consultations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own chat consultations" ON public.chat_consultations;
CREATE POLICY "Users can view own chat consultations" ON public.chat_consultations
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own chat consultations" ON public.chat_consultations;
CREATE POLICY "Users can insert own chat consultations" ON public.chat_consultations
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own chat consultations" ON public.chat_consultations;
CREATE POLICY "Users can update own chat consultations" ON public.chat_consultations
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own chat consultations" ON public.chat_consultations;
CREATE POLICY "Users can delete own chat consultations" ON public.chat_consultations
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Chat messages table
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own chat messages" ON public.chat_messages;
CREATE POLICY "Users can view own chat messages" ON public.chat_messages
    FOR SELECT USING (
        consultation_id IN (
            SELECT id FROM public.chat_consultations WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_view'::text)
        )
    );

DROP POLICY IF EXISTS "Users can insert own chat messages" ON public.chat_messages;
CREATE POLICY "Users can insert own chat messages" ON public.chat_messages
    FOR INSERT WITH CHECK (
        consultation_id IN (
            SELECT id FROM public.chat_consultations WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

DROP POLICY IF EXISTS "Users can update own chat messages" ON public.chat_messages;
CREATE POLICY "Users can update own chat messages" ON public.chat_messages
    FOR UPDATE USING (
        consultation_id IN (
            SELECT id FROM public.chat_consultations WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

DROP POLICY IF EXISTS "Users can delete own chat messages" ON public.chat_messages;
CREATE POLICY "Users can delete own chat messages" ON public.chat_messages
    FOR DELETE USING (
        consultation_id IN (
            SELECT id FROM public.chat_consultations WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

-- ============================================================================
-- WEARABLES & DEVICES MODULE
-- ============================================================================

-- Connected devices table
ALTER TABLE public.connected_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own connected devices" ON public.connected_devices;
CREATE POLICY "Users can view own connected devices" ON public.connected_devices
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own connected devices" ON public.connected_devices;
CREATE POLICY "Users can insert own connected devices" ON public.connected_devices
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own connected devices" ON public.connected_devices;
CREATE POLICY "Users can update own connected devices" ON public.connected_devices
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own connected devices" ON public.connected_devices;
CREATE POLICY "Users can delete own connected devices" ON public.connected_devices
    FOR DELETE USING (user_id = auth.uid());

-- Device readings table
ALTER TABLE public.device_readings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own device readings" ON public.device_readings;
CREATE POLICY "Users can view own device readings" ON public.device_readings
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own device readings" ON public.device_readings;
CREATE POLICY "Users can insert own device readings" ON public.device_readings
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own device readings" ON public.device_readings;
CREATE POLICY "Users can update own device readings" ON public.device_readings
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own device readings" ON public.device_readings;
CREATE POLICY "Users can delete own device readings" ON public.device_readings
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- HEALTH GOALS & PROGRAMS MODULE
-- ============================================================================

-- Health goals table
ALTER TABLE public.health_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own health goals" ON public.health_goals;
CREATE POLICY "Users can view own health goals" ON public.health_goals
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own health goals" ON public.health_goals;
CREATE POLICY "Users can insert own health goals" ON public.health_goals
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own health goals" ON public.health_goals;
CREATE POLICY "Users can update own health goals" ON public.health_goals
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own health goals" ON public.health_goals;
CREATE POLICY "Users can delete own health goals" ON public.health_goals
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Goal milestones table
ALTER TABLE public.goal_milestones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own goal milestones" ON public.goal_milestones;
CREATE POLICY "Users can view own goal milestones" ON public.goal_milestones
    FOR SELECT USING (
        goal_id IN (
            SELECT id FROM public.health_goals WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_view'::text)
        )
    );

DROP POLICY IF EXISTS "Users can insert own goal milestones" ON public.goal_milestones;
CREATE POLICY "Users can insert own goal milestones" ON public.goal_milestones
    FOR INSERT WITH CHECK (
        goal_id IN (
            SELECT id FROM public.health_goals WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

DROP POLICY IF EXISTS "Users can update own goal milestones" ON public.goal_milestones;
CREATE POLICY "Users can update own goal milestones" ON public.goal_milestones
    FOR UPDATE USING (
        goal_id IN (
            SELECT id FROM public.health_goals WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

DROP POLICY IF EXISTS "Users can delete own goal milestones" ON public.goal_milestones;
CREATE POLICY "Users can delete own goal milestones" ON public.goal_milestones
    FOR DELETE USING (
        goal_id IN (
            SELECT id FROM public.health_goals WHERE
            health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
            OR has_family_access(health_profile_id, 'can_edit'::text)
        )
    );

-- Health programs table (READ-ONLY CATALOG)
ALTER TABLE public.health_programs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view health programs" ON public.health_programs;
CREATE POLICY "Authenticated users can view health programs" ON public.health_programs
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- User programs table
ALTER TABLE public.user_programs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own user programs" ON public.user_programs;
CREATE POLICY "Users can view own user programs" ON public.user_programs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own user programs" ON public.user_programs;
CREATE POLICY "Users can insert own user programs" ON public.user_programs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own user programs" ON public.user_programs;
CREATE POLICY "Users can update own user programs" ON public.user_programs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own user programs" ON public.user_programs;
CREATE POLICY "Users can delete own user programs" ON public.user_programs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- WOMEN'S HEALTH MODULE
-- ============================================================================

-- Menstrual cycles table
ALTER TABLE public.menstrual_cycles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own menstrual cycles" ON public.menstrual_cycles;
CREATE POLICY "Users can view own menstrual cycles" ON public.menstrual_cycles
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own menstrual cycles" ON public.menstrual_cycles;
CREATE POLICY "Users can insert own menstrual cycles" ON public.menstrual_cycles
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own menstrual cycles" ON public.menstrual_cycles;
CREATE POLICY "Users can update own menstrual cycles" ON public.menstrual_cycles
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own menstrual cycles" ON public.menstrual_cycles;
CREATE POLICY "Users can delete own menstrual cycles" ON public.menstrual_cycles
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Pregnancy tracking table
ALTER TABLE public.pregnancy_tracking ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own pregnancy tracking" ON public.pregnancy_tracking;
CREATE POLICY "Users can view own pregnancy tracking" ON public.pregnancy_tracking
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own pregnancy tracking" ON public.pregnancy_tracking;
CREATE POLICY "Users can insert own pregnancy tracking" ON public.pregnancy_tracking
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own pregnancy tracking" ON public.pregnancy_tracking;
CREATE POLICY "Users can update own pregnancy tracking" ON public.pregnancy_tracking
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own pregnancy tracking" ON public.pregnancy_tracking;
CREATE POLICY "Users can delete own pregnancy tracking" ON public.pregnancy_tracking
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- Pregnancy logs table
ALTER TABLE public.pregnancy_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own pregnancy logs" ON public.pregnancy_logs;
CREATE POLICY "Users can view own pregnancy logs" ON public.pregnancy_logs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

DROP POLICY IF EXISTS "Users can insert own pregnancy logs" ON public.pregnancy_logs;
CREATE POLICY "Users can insert own pregnancy logs" ON public.pregnancy_logs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can update own pregnancy logs" ON public.pregnancy_logs;
CREATE POLICY "Users can update own pregnancy logs" ON public.pregnancy_logs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

DROP POLICY IF EXISTS "Users can delete own pregnancy logs" ON public.pregnancy_logs;
CREATE POLICY "Users can delete own pregnancy logs" ON public.pregnancy_logs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );
