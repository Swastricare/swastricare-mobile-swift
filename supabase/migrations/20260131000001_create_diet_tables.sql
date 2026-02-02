-- Migration: Create Diet Chart Tables
-- Created: 2026-01-31
-- Description: Tables for diet planning, food logging, and nutritional tracking

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TABLE: diet_plans
-- Description: User's diet plans with nutritional targets
-- ============================================================================

CREATE TABLE public.diet_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    goal_type VARCHAR(30) NOT NULL CHECK (goal_type IN ('weight_loss', 'weight_gain', 'maintenance', 'muscle_building')),
    target_calories INT NOT NULL DEFAULT 2000,
    target_protein_g INT NOT NULL DEFAULT 100,
    target_carbs_g INT NOT NULL DEFAULT 250,
    target_fat_g INT NOT NULL DEFAULT 65,
    is_active BOOLEAN DEFAULT true,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for diet_plans
CREATE INDEX idx_diet_plans_profile ON public.diet_plans(health_profile_id, is_active);
CREATE INDEX idx_diet_plans_dates ON public.diet_plans(start_date, end_date);

-- ============================================================================
-- TABLE: diet_meals
-- Description: Meal templates within a diet plan
-- ============================================================================

CREATE TABLE public.diet_meals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    diet_plan_id UUID NOT NULL REFERENCES public.diet_plans(id) ON DELETE CASCADE,
    meal_type VARCHAR(20) NOT NULL CHECK (meal_type IN ('breakfast', 'morning_snack', 'lunch', 'evening_snack', 'dinner', 'late_night')),
    scheduled_time TIME,
    name VARCHAR(100) NOT NULL,
    order_index INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for diet_meals
CREATE INDEX idx_diet_meals_plan ON public.diet_meals(diet_plan_id, order_index);

-- ============================================================================
-- TABLE: food_items
-- Description: Food database with nutritional information
-- ============================================================================

CREATE TABLE public.food_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    brand VARCHAR(100),
    serving_size DECIMAL(10,2) NOT NULL,
    serving_unit VARCHAR(20) NOT NULL CHECK (serving_unit IN ('g', 'ml', 'piece', 'cup', 'tbsp', 'tsp', 'oz', 'bowl', 'plate')),
    calories DECIMAL(10,2) NOT NULL,
    protein_g DECIMAL(10,2) NOT NULL DEFAULT 0,
    carbs_g DECIMAL(10,2) NOT NULL DEFAULT 0,
    fat_g DECIMAL(10,2) NOT NULL DEFAULT 0,
    fiber_g DECIMAL(10,2),
    sugar_g DECIMAL(10,2),
    sodium_mg DECIMAL(10,2),
    is_vegetarian BOOLEAN DEFAULT true,
    is_vegan BOOLEAN DEFAULT false,
    category VARCHAR(50) CHECK (category IN ('fruits', 'vegetables', 'grains', 'protein', 'dairy', 'beverages', 'snacks', 'sweets', 'other')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for food_items
CREATE INDEX idx_food_items_name ON public.food_items(name);
CREATE INDEX idx_food_items_category ON public.food_items(category);
CREATE INDEX idx_food_items_search ON public.food_items USING gin(to_tsvector('english', name || ' ' || COALESCE(brand, '')));

-- ============================================================================
-- TABLE: diet_logs
-- Description: Daily food intake logs
-- ============================================================================

CREATE TABLE public.diet_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    food_item_id UUID REFERENCES public.food_items(id) ON DELETE SET NULL,
    meal_type VARCHAR(20) NOT NULL CHECK (meal_type IN ('breakfast', 'morning_snack', 'lunch', 'evening_snack', 'dinner', 'late_night')),
    food_name VARCHAR(150) NOT NULL,
    quantity DECIMAL(10,2) NOT NULL,
    serving_unit VARCHAR(20) NOT NULL,
    calories DECIMAL(10,2) NOT NULL,
    protein_g DECIMAL(10,2) NOT NULL DEFAULT 0,
    carbs_g DECIMAL(10,2) NOT NULL DEFAULT 0,
    fat_g DECIMAL(10,2) NOT NULL DEFAULT 0,
    fiber_g DECIMAL(10,2),
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for diet_logs
CREATE INDEX idx_diet_logs_profile_date ON public.diet_logs(health_profile_id, logged_at DESC);
CREATE INDEX idx_diet_logs_meal_type ON public.diet_logs(health_profile_id, meal_type, logged_at DESC);

-- ============================================================================
-- TABLE: diet_goals
-- Description: User's nutritional goals and preferences
-- ============================================================================

CREATE TABLE public.diet_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL UNIQUE REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    daily_calories INT DEFAULT 2000,
    protein_percent INT DEFAULT 25 CHECK (protein_percent >= 0 AND protein_percent <= 100),
    carbs_percent INT DEFAULT 50 CHECK (carbs_percent >= 0 AND carbs_percent <= 100),
    fat_percent INT DEFAULT 25 CHECK (fat_percent >= 0 AND fat_percent <= 100),
    water_goal_ml INT DEFAULT 2500,
    meal_reminders_enabled BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for diet_goals
CREATE INDEX idx_diet_goals_profile ON public.diet_goals(health_profile_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.diet_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_goals ENABLE ROW LEVEL SECURITY;

-- RLS Policies for diet_plans
CREATE POLICY "Users can view own diet plans" ON public.diet_plans
    FOR SELECT USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own diet plans" ON public.diet_plans
    FOR INSERT WITH CHECK (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own diet plans" ON public.diet_plans
    FOR UPDATE USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own diet plans" ON public.diet_plans
    FOR DELETE USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

-- RLS Policies for diet_meals
CREATE POLICY "Users can manage own diet meals" ON public.diet_meals
    FOR ALL USING (
        diet_plan_id IN (
            SELECT id FROM public.diet_plans WHERE health_profile_id IN (
                SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
            )
        )
    );

-- RLS Policies for food_items (public read, authenticated write)
CREATE POLICY "Anyone can view food items" ON public.food_items
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert food items" ON public.food_items
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- RLS Policies for diet_logs
CREATE POLICY "Users can view own diet logs" ON public.diet_logs
    FOR SELECT USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own diet logs" ON public.diet_logs
    FOR INSERT WITH CHECK (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own diet logs" ON public.diet_logs
    FOR UPDATE USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own diet logs" ON public.diet_logs
    FOR DELETE USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

-- RLS Policies for diet_goals
CREATE POLICY "Users can view own diet goals" ON public.diet_goals
    FOR SELECT USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own diet goals" ON public.diet_goals
    FOR INSERT WITH CHECK (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own diet goals" ON public.diet_goals
    FOR UPDATE USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger to update updated_at timestamp for diet_plans
CREATE TRIGGER diet_plans_updated_at
    BEFORE UPDATE ON public.diet_plans
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Trigger to update updated_at timestamp for diet_goals
CREATE TRIGGER diet_goals_updated_at
    BEFORE UPDATE ON public.diet_goals
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to calculate daily nutrition summary
CREATE OR REPLACE FUNCTION public.get_daily_nutrition_summary(
    p_health_profile_id UUID,
    p_date DATE
)
RETURNS TABLE(
    total_calories DECIMAL,
    total_protein_g DECIMAL,
    total_carbs_g DECIMAL,
    total_fat_g DECIMAL,
    total_fiber_g DECIMAL,
    meal_count INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(calories), 0) as total_calories,
        COALESCE(SUM(protein_g), 0) as total_protein_g,
        COALESCE(SUM(carbs_g), 0) as total_carbs_g,
        COALESCE(SUM(fat_g), 0) as total_fat_g,
        COALESCE(SUM(fiber_g), 0) as total_fiber_g,
        COUNT(*)::INT as meal_count
    FROM public.diet_logs
    WHERE health_profile_id = p_health_profile_id
        AND DATE(logged_at) = p_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE public.diet_plans IS 'User diet plans with nutritional targets';
COMMENT ON TABLE public.diet_meals IS 'Meal templates within diet plans';
COMMENT ON TABLE public.food_items IS 'Food database with nutritional information';
COMMENT ON TABLE public.diet_logs IS 'Daily food intake logs';
COMMENT ON TABLE public.diet_goals IS 'User nutritional goals and preferences';
