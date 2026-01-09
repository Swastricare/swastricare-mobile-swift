-- ============================================================================
-- WEARABLES & DEVICES MODULE
-- ============================================================================
-- Tables: connected_devices, device_readings

-- ============================================================================
-- CONNECTED DEVICES TABLE
-- ============================================================================
CREATE TABLE public.connected_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Device type
    device_type VARCHAR(30) NOT NULL CHECK (device_type IN (
        'smartwatch', 'fitness_band', 'glucometer', 'bp_monitor',
        'pulse_oximeter', 'smart_scale', 'thermometer', 'cgm',
        'ecg_monitor', 'sleep_tracker', 'inhaler', 'hearing_aid', 'other'
    )),
    
    -- Device info
    brand VARCHAR(100),
    model VARCHAR(100),
    device_name VARCHAR(100),
    device_id VARCHAR(200),
    serial_number VARCHAR(100),
    
    -- Connection
    connection_type VARCHAR(30) CHECK (connection_type IN (
        'bluetooth', 'bluetooth_le', 'wifi', 'usb',
        'healthkit', 'google_fit', 'samsung_health', 'fitbit',
        'garmin', 'withings', 'api', 'manual'
    )),
    
    -- Authentication
    auth_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    
    -- Status
    is_connected BOOLEAN DEFAULT true,
    connection_status VARCHAR(20) CHECK (connection_status IN (
        'connected', 'disconnected', 'pairing', 'error', 'not_supported'
    )),
    last_connected_at TIMESTAMPTZ,
    
    -- Sync settings
    sync_enabled BOOLEAN DEFAULT true,
    sync_frequency_mins INT DEFAULT 60,
    last_sync_at TIMESTAMPTZ,
    next_sync_at TIMESTAMPTZ,
    
    -- What metrics to sync
    metrics_to_sync TEXT[],
    
    -- Device status
    battery_level INT,
    firmware_version VARCHAR(50),
    needs_update BOOLEAN DEFAULT false,
    
    -- Settings
    device_settings JSONB,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DEVICE READINGS TABLE
-- ============================================================================
CREATE TABLE public.device_readings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES public.connected_devices(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Reading type
    reading_type VARCHAR(30) NOT NULL CHECK (reading_type IN (
        'heart_rate', 'heart_rate_variability', 'resting_heart_rate',
        'blood_pressure', 'blood_glucose', 'oxygen_saturation',
        'body_temperature', 'respiratory_rate',
        'steps', 'distance', 'calories', 'active_minutes', 'floors_climbed',
        'sleep', 'sleep_stages', 'sleep_quality',
        'weight', 'body_fat', 'muscle_mass', 'bmi', 'water_percentage',
        'ecg', 'afib_detection',
        'stress', 'energy',
        'blood_ketones', 'uric_acid',
        'other'
    )),
    
    -- Primary value
    value_primary DECIMAL(15,4) NOT NULL,
    value_secondary DECIMAL(15,4),
    value_tertiary DECIMAL(15,4),
    unit VARCHAR(30),
    
    -- For blood pressure specifically
    systolic INT,
    diastolic INT,
    pulse INT,
    
    -- For sleep specifically
    sleep_duration_mins INT,
    deep_sleep_mins INT,
    light_sleep_mins INT,
    rem_sleep_mins INT,
    awake_mins INT,
    
    -- Context
    context VARCHAR(30) CHECK (context IN (
        'at_rest', 'during_activity', 'post_activity',
        'fasting', 'post_meal', 'bedtime', 'waking',
        'manual_entry', 'automatic'
    )),
    activity_type VARCHAR(50),
    
    -- Quality indicators
    confidence_score DECIMAL(3,2),
    is_anomaly BOOLEAN DEFAULT false,
    anomaly_reason TEXT,
    
    -- Raw data
    raw_data JSONB,
    
    -- Timestamps
    recorded_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Source
    source_platform VARCHAR(30),
    source_id VARCHAR(100)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_connected_devices_profile ON public.connected_devices(health_profile_id);
CREATE INDEX idx_connected_devices_user ON public.connected_devices(user_id);
CREATE INDEX idx_connected_devices_type ON public.connected_devices(health_profile_id, device_type);
CREATE INDEX idx_connected_devices_connected ON public.connected_devices(health_profile_id) WHERE is_connected = true;
CREATE INDEX idx_device_readings_device ON public.device_readings(device_id);
CREATE INDEX idx_device_readings_profile ON public.device_readings(health_profile_id);
CREATE INDEX idx_device_readings_type_time ON public.device_readings(health_profile_id, reading_type, recorded_at DESC);
CREATE INDEX idx_device_readings_recorded ON public.device_readings(health_profile_id, recorded_at DESC);

-- Partial indexes for specific reading types
CREATE INDEX idx_device_readings_heart_rate ON public.device_readings(health_profile_id, recorded_at DESC) 
    WHERE reading_type = 'heart_rate';
CREATE INDEX idx_device_readings_blood_glucose ON public.device_readings(health_profile_id, recorded_at DESC) 
    WHERE reading_type = 'blood_glucose';
CREATE INDEX idx_device_readings_blood_pressure ON public.device_readings(health_profile_id, recorded_at DESC) 
    WHERE reading_type = 'blood_pressure';
CREATE INDEX idx_device_readings_steps ON public.device_readings(health_profile_id, recorded_at DESC) 
    WHERE reading_type = 'steps';
CREATE INDEX idx_device_readings_sleep ON public.device_readings(health_profile_id, recorded_at DESC) 
    WHERE reading_type = 'sleep';

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER connected_devices_updated_at
    BEFORE UPDATE ON public.connected_devices
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
