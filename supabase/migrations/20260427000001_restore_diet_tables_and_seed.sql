-- Migration: Restore diet schema + seed (idempotent)
-- Created: 2026-04-27
-- Description:
--   The original migrations 20260131000001 (create) and 20260131000002 + 20260302000001 (seed)
--   are recorded in supabase_migrations.schema_migrations as applied, but the tables they create
--   (diet_plans, diet_meals, food_items, diet_logs, diet_goals) DO NOT exist in production.
--   Result: every diet log/sync silently fails because the targeted relations are missing.
--   This migration safely re-creates the tables, indexes, RLS policies, triggers, and re-seeds
--   the food_items database. All operations are idempotent (CREATE IF NOT EXISTS,
--   DROP POLICY IF EXISTS before CREATE, CREATE OR REPLACE for functions).
--
-- Apply via: `supabase db push` from a developer machine, or run the SQL through Supabase Studio
-- (the MCP is in read-only mode and cannot execute DDL).

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.diet_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
CREATE INDEX IF NOT EXISTS idx_diet_plans_profile ON public.diet_plans(health_profile_id, is_active);
CREATE INDEX IF NOT EXISTS idx_diet_plans_dates ON public.diet_plans(start_date, end_date);

CREATE TABLE IF NOT EXISTS public.diet_meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    diet_plan_id UUID NOT NULL REFERENCES public.diet_plans(id) ON DELETE CASCADE,
    meal_type VARCHAR(20) NOT NULL CHECK (meal_type IN ('breakfast', 'morning_snack', 'lunch', 'evening_snack', 'dinner', 'late_night')),
    scheduled_time TIME,
    name VARCHAR(100) NOT NULL,
    order_index INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_diet_meals_plan ON public.diet_meals(diet_plan_id, order_index);

CREATE TABLE IF NOT EXISTS public.food_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
CREATE INDEX IF NOT EXISTS idx_food_items_name ON public.food_items(name);
CREATE INDEX IF NOT EXISTS idx_food_items_category ON public.food_items(category);
CREATE INDEX IF NOT EXISTS idx_food_items_search ON public.food_items USING gin(to_tsvector('english', name || ' ' || COALESCE(brand, '')));

CREATE TABLE IF NOT EXISTS public.diet_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
CREATE INDEX IF NOT EXISTS idx_diet_logs_profile_date ON public.diet_logs(health_profile_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_diet_logs_meal_type ON public.diet_logs(health_profile_id, meal_type, logged_at DESC);

CREATE TABLE IF NOT EXISTS public.diet_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    health_profile_id UUID NOT NULL UNIQUE REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    daily_calories INT DEFAULT 2000,
    protein_percent INT DEFAULT 25 CHECK (protein_percent >= 0 AND protein_percent <= 100),
    carbs_percent INT DEFAULT 50 CHECK (carbs_percent >= 0 AND carbs_percent <= 100),
    fat_percent INT DEFAULT 25 CHECK (fat_percent >= 0 AND fat_percent <= 100),
    water_goal_ml INT DEFAULT 2500,
    meal_reminders_enabled BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_diet_goals_profile ON public.diet_goals(health_profile_id);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.diet_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own diet plans" ON public.diet_plans;
CREATE POLICY "Users can view own diet plans" ON public.diet_plans
    FOR SELECT USING (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "Users can insert own diet plans" ON public.diet_plans;
CREATE POLICY "Users can insert own diet plans" ON public.diet_plans
    FOR INSERT WITH CHECK (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "Users can update own diet plans" ON public.diet_plans;
CREATE POLICY "Users can update own diet plans" ON public.diet_plans
    FOR UPDATE USING (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "Users can delete own diet plans" ON public.diet_plans;
CREATE POLICY "Users can delete own diet plans" ON public.diet_plans
    FOR DELETE USING (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Users can manage own diet meals" ON public.diet_meals;
CREATE POLICY "Users can manage own diet meals" ON public.diet_meals
    FOR ALL USING (diet_plan_id IN (
        SELECT id FROM public.diet_plans WHERE health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    ));

DROP POLICY IF EXISTS "Anyone can view food items" ON public.food_items;
CREATE POLICY "Anyone can view food items" ON public.food_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can insert food items" ON public.food_items;
CREATE POLICY "Authenticated users can insert food items" ON public.food_items
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can view own diet logs" ON public.diet_logs;
CREATE POLICY "Users can view own diet logs" ON public.diet_logs
    FOR SELECT USING (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "Users can insert own diet logs" ON public.diet_logs;
CREATE POLICY "Users can insert own diet logs" ON public.diet_logs
    FOR INSERT WITH CHECK (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "Users can update own diet logs" ON public.diet_logs;
CREATE POLICY "Users can update own diet logs" ON public.diet_logs
    FOR UPDATE USING (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "Users can delete own diet logs" ON public.diet_logs;
CREATE POLICY "Users can delete own diet logs" ON public.diet_logs
    FOR DELETE USING (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Users can view own diet goals" ON public.diet_goals;
CREATE POLICY "Users can view own diet goals" ON public.diet_goals
    FOR SELECT USING (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "Users can insert own diet goals" ON public.diet_goals;
CREATE POLICY "Users can insert own diet goals" ON public.diet_goals
    FOR INSERT WITH CHECK (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "Users can update own diet goals" ON public.diet_goals;
CREATE POLICY "Users can update own diet goals" ON public.diet_goals
    FOR UPDATE USING (health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid()));

-- ============================================================================
-- TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS diet_plans_updated_at ON public.diet_plans;
CREATE TRIGGER diet_plans_updated_at BEFORE UPDATE ON public.diet_plans
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
DROP TRIGGER IF EXISTS diet_goals_updated_at ON public.diet_goals;
CREATE TRIGGER diet_goals_updated_at BEFORE UPDATE ON public.diet_goals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================================
-- HELPER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_daily_nutrition_summary(p_health_profile_id UUID, p_date DATE)
RETURNS TABLE(total_calories DECIMAL, total_protein_g DECIMAL, total_carbs_g DECIMAL, total_fat_g DECIMAL, total_fiber_g DECIMAL, meal_count INT) AS $$
BEGIN
    RETURN QUERY
    SELECT COALESCE(SUM(calories), 0), COALESCE(SUM(protein_g), 0), COALESCE(SUM(carbs_g), 0),
           COALESCE(SUM(fat_g), 0), COALESCE(SUM(fiber_g), 0), COUNT(*)::INT
    FROM public.diet_logs
    WHERE health_profile_id = p_health_profile_id AND DATE(logged_at) = p_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SEED FOOD ITEMS (only if table is empty — guards against accidental dupes)
-- ============================================================================

DO $$
BEGIN
    IF (SELECT count(*) FROM public.food_items) = 0 THEN

        -- INDIAN GRAINS
        INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
        ('White Rice (Cooked)', 100, 'g', 130, 2.7, 28, 0.3, 0.4, true, true, 'grains'),
        ('Brown Rice (Cooked)', 100, 'g', 112, 2.6, 24, 0.9, 1.8, true, true, 'grains'),
        ('Roti (Whole Wheat)', 1, 'piece', 71, 3, 15, 0.4, 2, true, true, 'grains'),
        ('Naan', 1, 'piece', 262, 7, 45, 5, 2, true, false, 'grains'),
        ('Paratha (Plain)', 1, 'piece', 126, 3, 18, 5, 2, true, false, 'grains'),
        ('Idli', 1, 'piece', 39, 2, 8, 0.2, 0.5, true, true, 'grains'),
        ('Dosa (Plain)', 1, 'piece', 133, 3.6, 22, 3.7, 1.5, true, true, 'grains'),
        ('Upma', 1, 'bowl', 200, 5, 35, 4, 3, true, true, 'grains'),
        ('Poha', 1, 'bowl', 180, 3, 30, 5, 2, true, true, 'grains'),
        ('Puri', 1, 'piece', 81, 1.5, 10, 4, 0.5, true, false, 'grains'),
        ('Uttapam', 1, 'piece', 180, 5, 28, 5, 2, true, true, 'grains'),
        ('Pongal', 1, 'bowl', 250, 7, 38, 7, 2.5, true, false, 'grains'),
        ('Medu Vada', 1, 'piece', 130, 5, 15, 6, 1.5, true, true, 'grains'),
        ('Appam', 1, 'piece', 120, 2.5, 22, 2, 0.8, true, true, 'grains'),
        ('Puttu', 1, 'piece', 240, 4, 42, 6, 3, true, true, 'grains'),
        ('Sambar Rice', 1, 'bowl', 300, 9, 50, 6, 4, true, true, 'grains'),
        ('Lemon Rice', 1, 'bowl', 250, 4, 42, 7, 1.5, true, true, 'grains'),
        ('Curd Rice', 1, 'bowl', 220, 6, 36, 5, 1, true, false, 'grains'),
        ('Tomato Rice', 1, 'bowl', 260, 5, 44, 6, 2, true, true, 'grains'),
        ('Bisi Bele Bath', 1, 'bowl', 320, 10, 48, 9, 5, true, false, 'grains'),
        ('Pesarattu', 1, 'piece', 150, 7, 20, 4, 3, true, true, 'grains'),
        ('Rava Dosa', 1, 'piece', 160, 3, 24, 6, 1, true, true, 'grains'),
        ('Chole Bhature', 1, 'plate', 450, 14, 55, 19, 8, true, false, 'grains'),
        ('Aloo Paratha', 1, 'piece', 200, 4.5, 28, 8, 2, true, false, 'grains'),
        ('Stuffed Kulcha', 1, 'piece', 280, 7, 40, 10, 2, true, false, 'grains'),
        ('Jeera Rice', 1, 'bowl', 200, 4, 38, 4, 1, true, false, 'grains'),
        ('Methi Thepla', 1, 'piece', 110, 3.5, 16, 4, 2, true, false, 'grains'),
        ('Missi Roti', 1, 'piece', 100, 4, 15, 2.5, 2.5, true, true, 'grains'),
        ('Rumali Roti', 1, 'piece', 90, 3, 17, 1, 1, true, false, 'grains'),
        ('Tandoori Roti', 1, 'piece', 80, 3, 16, 0.5, 1.5, true, true, 'grains'),
        ('Luchi', 1, 'piece', 100, 2, 13, 5, 0.5, true, false, 'grains'),
        ('Thepla', 1, 'piece', 120, 3.5, 17, 4.5, 2, true, false, 'grains'),
        ('Dal Dhokli', 1, 'bowl', 280, 10, 40, 8, 5, true, false, 'grains'),
        ('Sabudana Khichdi', 1, 'bowl', 250, 3, 42, 8, 1, true, true, 'grains'),
        ('Masala Dosa', 1, 'piece', 200, 5, 30, 7, 2, true, true, 'grains'),
        ('Egg Dosa', 1, 'piece', 210, 9, 24, 9, 1, false, false, 'grains'),
        ('Paneer Dosa', 1, 'piece', 230, 9, 26, 10, 1.5, true, false, 'grains'),
        ('Oats Upma', 1, 'bowl', 200, 7, 30, 6, 4, true, true, 'grains'),
        ('Quinoa Khichdi', 1, 'bowl', 230, 9, 34, 6, 5, true, true, 'grains'),
        ('Ragi Dosa', 1, 'piece', 120, 3, 22, 2.5, 3, true, true, 'grains'),
        ('Multigrain Roti', 1, 'piece', 85, 3.5, 15, 1.5, 3, true, true, 'grains'),
        ('Sattu Paratha', 1, 'piece', 220, 8, 30, 7, 4, true, false, 'grains'),
        ('Bajra Roti', 1, 'piece', 100, 3, 20, 1.5, 2.5, true, true, 'grains'),
        ('Jowar Roti', 1, 'piece', 95, 3, 20, 1, 2.5, true, true, 'grains');

        -- PROTEIN
        INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
        ('Dal (Cooked)', 1, 'bowl', 198, 15, 30, 1, 8, true, true, 'protein'),
        ('Rajma (Kidney Beans)', 1, 'bowl', 225, 15, 40, 1, 13, true, true, 'protein'),
        ('Chana (Chickpeas)', 1, 'bowl', 269, 15, 45, 4, 12, true, true, 'protein'),
        ('Paneer', 100, 'g', 265, 18, 1.2, 20, 0, true, false, 'protein'),
        ('Chicken Breast (Cooked)', 100, 'g', 165, 31, 0, 3.6, 0, false, false, 'protein'),
        ('Egg (Boiled)', 1, 'piece', 78, 6.3, 0.6, 5.3, 0, false, false, 'protein'),
        ('Fish (Cooked)', 100, 'g', 206, 22, 0, 12, 0, false, false, 'protein'),
        ('Tofu', 100, 'g', 76, 8, 1.9, 4.8, 0.3, true, true, 'protein'),
        ('Soya Chunks', 100, 'g', 345, 52, 33, 0.5, 13, true, true, 'protein'),
        ('Dal Makhani', 1, 'bowl', 260, 12, 30, 10, 6, true, false, 'protein'),
        ('Fish Curry Bengali', 1, 'bowl', 220, 22, 8, 12, 1.5, false, false, 'protein'),
        ('Butter Chicken', 1, 'bowl', 440, 28, 14, 30, 2, false, false, 'protein'),
        ('Kadhai Chicken', 1, 'bowl', 350, 30, 10, 22, 2.5, false, false, 'protein'),
        ('Tandoori Chicken', 1, 'piece', 260, 30, 5, 14, 1, false, false, 'protein'),
        ('Chicken Tikka', 100, 'g', 200, 25, 6, 9, 1, false, false, 'protein'),
        ('Dal Tadka', 1, 'bowl', 180, 10, 25, 5, 5, true, true, 'protein'),
        ('Dal Fry', 1, 'bowl', 170, 10, 24, 4, 5, true, true, 'protein'),
        ('Paneer Tikka', 100, 'g', 250, 16, 8, 18, 1.5, true, false, 'protein'),
        ('Egg Bhurji', 2, 'piece', 190, 14, 3, 14, 0.5, false, false, 'protein'),
        ('Mutton Curry', 1, 'bowl', 380, 28, 8, 26, 1.5, false, false, 'protein'),
        ('Prawn Masala', 1, 'bowl', 240, 22, 10, 13, 2, false, false, 'protein'),
        ('Egg Curry', 1, 'bowl', 220, 14, 10, 14, 2, false, false, 'protein'),
        ('Sprouts Salad', 1, 'bowl', 120, 8, 16, 2, 5, true, true, 'protein'),
        ('Peanut Butter', 2, 'tbsp', 188, 8, 7, 16, 2, true, true, 'protein');

        -- VEGETABLES
        INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
        ('Aloo Sabzi (Potato Curry)', 1, 'bowl', 150, 3, 25, 4, 3, true, true, 'vegetables'),
        ('Palak Paneer', 1, 'bowl', 280, 12, 15, 20, 4, true, false, 'vegetables'),
        ('Mixed Vegetable Curry', 1, 'bowl', 120, 4, 18, 3, 5, true, true, 'vegetables'),
        ('Bhindi (Okra)', 100, 'g', 33, 1.9, 7, 0.2, 3.2, true, true, 'vegetables'),
        ('Baingan Bharta', 1, 'bowl', 180, 3, 20, 8, 6, true, true, 'vegetables'),
        ('Tomato', 1, 'piece', 22, 1.1, 4.8, 0.2, 1.5, true, true, 'vegetables'),
        ('Onion', 1, 'piece', 40, 1.1, 9.3, 0.1, 1.7, true, true, 'vegetables'),
        ('Carrot', 1, 'piece', 25, 0.6, 6, 0.1, 1.7, true, true, 'vegetables'),
        ('Cucumber', 100, 'g', 16, 0.7, 3.6, 0.1, 0.5, true, true, 'vegetables'),
        ('Spinach (Cooked)', 100, 'g', 23, 2.9, 3.6, 0.4, 2.2, true, true, 'vegetables'),
        ('Avial', 1, 'bowl', 160, 3.5, 14, 10, 4, true, true, 'vegetables'),
        ('Matar Paneer', 1, 'bowl', 290, 14, 18, 18, 4, true, false, 'vegetables'),
        ('Shahi Paneer', 1, 'bowl', 350, 15, 14, 26, 2, true, false, 'vegetables'),
        ('Kadhai Paneer', 1, 'bowl', 320, 16, 12, 24, 2.5, true, false, 'vegetables'),
        ('Aloo Gobi', 1, 'bowl', 180, 4, 24, 7, 4, true, true, 'vegetables'),
        ('Aloo Posto', 1, 'bowl', 200, 4, 22, 11, 3, true, true, 'vegetables'),
        ('Shukto', 1, 'bowl', 150, 4, 16, 8, 4, true, false, 'vegetables'),
        ('Undhiyu', 1, 'bowl', 250, 6, 28, 13, 6, true, false, 'vegetables'),
        ('Malai Kofta', 1, 'bowl', 350, 10, 22, 25, 3, true, false, 'vegetables'),
        ('Paneer Butter Masala', 1, 'bowl', 400, 16, 16, 30, 2, true, false, 'vegetables');

        -- FRUITS
        INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
        ('Banana', 1, 'piece', 105, 1.3, 27, 0.4, 3.1, 14, true, true, 'fruits'),
        ('Apple', 1, 'piece', 95, 0.5, 25, 0.3, 4.4, 19, true, true, 'fruits'),
        ('Mango', 1, 'piece', 202, 2.8, 50, 1.3, 5.4, 46, true, true, 'fruits'),
        ('Orange', 1, 'piece', 62, 1.2, 15, 0.2, 3.1, 12, true, true, 'fruits'),
        ('Papaya', 100, 'g', 43, 0.5, 11, 0.3, 1.7, 7.8, true, true, 'fruits'),
        ('Watermelon', 100, 'g', 30, 0.6, 7.6, 0.2, 0.4, 6.2, true, true, 'fruits'),
        ('Grapes', 100, 'g', 69, 0.7, 18, 0.2, 0.9, 15, true, true, 'fruits'),
        ('Pomegranate', 100, 'g', 83, 1.7, 19, 1.2, 4, 14, true, true, 'fruits'),
        ('Avocado', 1, 'piece', 234, 2.9, 12, 21, 10, NULL, true, true, 'fruits');

        -- DAIRY
        INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
        ('Milk (Full Fat)', 1, 'cup', 149, 7.7, 12, 8, 12, true, false, 'dairy'),
        ('Milk (Low Fat)', 1, 'cup', 102, 8.2, 12, 2.4, 13, true, false, 'dairy'),
        ('Curd (Yogurt)', 1, 'bowl', 98, 11, 4.7, 4.3, 4.7, true, false, 'dairy'),
        ('Buttermilk', 1, 'cup', 40, 2, 5, 0.9, 5, true, false, 'dairy'),
        ('Ghee', 1, 'tbsp', 112, 0, 0, 12.7, 0, true, false, 'dairy'),
        ('Cheese', 1, 'oz', 114, 7, 0.4, 9.4, 0.5, true, false, 'dairy'),
        ('Butter', 1, 'tbsp', 102, 0.1, 0, 11.5, 0, true, false, 'dairy');

        -- BEVERAGES
        INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
        ('Chai (Tea with Milk)', 1, 'cup', 60, 2, 8, 2, 6, true, false, 'beverages'),
        ('Black Tea', 1, 'cup', 2, 0, 0.7, 0, 0, true, true, 'beverages'),
        ('Green Tea', 1, 'cup', 2, 0, 0, 0, 0, true, true, 'beverages'),
        ('Coffee (Black)', 1, 'cup', 2, 0.3, 0, 0, 0, true, true, 'beverages'),
        ('Coffee with Milk', 1, 'cup', 38, 2, 3, 1.5, 3, true, false, 'beverages'),
        ('Lassi (Sweet)', 1, 'cup', 150, 5, 25, 3, 20, true, false, 'beverages'),
        ('Fresh Lime Water', 1, 'cup', 25, 0.3, 6, 0, 5, true, true, 'beverages'),
        ('Coconut Water', 1, 'cup', 46, 1.7, 9, 0.5, 6, true, true, 'beverages'),
        ('Filter Coffee', 1, 'cup', 80, 2, 10, 3, 8, true, false, 'beverages'),
        ('Masala Chai', 1, 'cup', 70, 2, 10, 2, 8, true, false, 'beverages'),
        ('Jaljeera', 1, 'cup', 30, 0.5, 7, 0.2, 5, true, true, 'beverages'),
        ('Aam Panna', 1, 'cup', 90, 0.5, 22, 0.3, 18, true, true, 'beverages'),
        ('Thandai', 1, 'cup', 200, 5, 28, 8, 22, true, false, 'beverages'),
        ('Badam Milk', 1, 'cup', 180, 6, 22, 8, 18, true, false, 'beverages'),
        ('Sugarcane Juice', 1, 'cup', 120, 0.3, 30, 0, 28, true, true, 'beverages'),
        ('Nimbu Pani', 1, 'cup', 25, 0.2, 6, 0, 5, true, true, 'beverages'),
        ('Mango Lassi', 1, 'cup', 180, 4, 30, 4, 24, true, false, 'beverages'),
        ('Rose Sharbat', 1, 'cup', 100, 0, 25, 0, 24, true, true, 'beverages'),
        ('Protein Shake', 1, 'cup', 120, 20, 5, 2, 1, true, false, 'beverages');

        -- SNACKS
        INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
        ('Samosa', 1, 'piece', 262, 4, 24, 17, 2, true, false, 'snacks'),
        ('Pakora', 100, 'g', 280, 6, 30, 15, 3, true, false, 'snacks'),
        ('Vada', 1, 'piece', 150, 4, 18, 7, 2, true, true, 'snacks'),
        ('Bhel Puri', 1, 'bowl', 200, 5, 35, 4, 3, true, true, 'snacks'),
        ('Pani Puri', 6, 'piece', 120, 3, 20, 3, 2, true, true, 'snacks'),
        ('Dhokla', 1, 'piece', 160, 5, 25, 4, 2, true, true, 'snacks'),
        ('Namkeen', 100, 'g', 540, 10, 50, 32, 5, true, true, 'snacks'),
        ('Roasted Peanuts', 100, 'g', 567, 26, 16, 49, 8, true, true, 'snacks'),
        ('Almonds', 100, 'g', 579, 21, 22, 50, 12, true, true, 'snacks'),
        ('Cashews', 100, 'g', 553, 18, 30, 44, 3, true, true, 'snacks'),
        ('Khandvi', 100, 'g', 160, 6, 20, 6, 1, true, false, 'snacks'),
        ('Handvo', 1, 'piece', 200, 6, 28, 7, 3, true, false, 'snacks'),
        ('Pav Bhaji', 1, 'plate', 400, 10, 52, 16, 5, true, false, 'snacks'),
        ('Sev Puri', 6, 'piece', 250, 5, 32, 12, 3, true, true, 'snacks'),
        ('Kachori', 1, 'piece', 200, 4, 22, 11, 2, true, false, 'snacks'),
        ('Aloo Tikki', 1, 'piece', 150, 3, 20, 7, 2, true, true, 'snacks'),
        ('Dahi Bhalla', 2, 'piece', 180, 5, 24, 7, 2, true, false, 'snacks'),
        ('Chole Tikki', 1, 'plate', 350, 12, 42, 14, 6, true, false, 'snacks'),
        ('Ragda Pattice', 1, 'plate', 300, 8, 40, 12, 5, true, true, 'snacks'),
        ('Dabeli', 1, 'piece', 250, 5, 35, 10, 3, true, true, 'snacks'),
        ('Vada Pav', 1, 'piece', 290, 6, 36, 13, 3, true, true, 'snacks'),
        ('Misal Pav', 1, 'plate', 400, 14, 50, 15, 7, true, true, 'snacks'),
        ('Poha Jalebi', 1, 'plate', 350, 5, 55, 12, 2, true, false, 'snacks'),
        ('French Fries', 100, 'g', 312, 3.4, 41, 15, 3.8, true, true, 'snacks');

        -- SWEETS
        INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
        ('Gulab Jamun', 1, 'piece', 175, 3, 25, 7, 20, true, false, 'sweets'),
        ('Rasgulla', 1, 'piece', 106, 2, 20, 1, 18, true, false, 'sweets'),
        ('Jalebi', 100, 'g', 150, 1, 28, 4, 25, true, false, 'sweets'),
        ('Ladoo', 1, 'piece', 186, 3, 28, 7, 22, true, false, 'sweets'),
        ('Barfi', 1, 'piece', 120, 2, 18, 5, 15, true, false, 'sweets'),
        ('Kheer', 1, 'bowl', 194, 5, 30, 6, 25, true, false, 'sweets'),
        ('Halwa', 100, 'g', 416, 3, 60, 17, 45, true, false, 'sweets'),
        ('Mishti Doi', 1, 'bowl', 200, 5, 32, 5, 26, true, false, 'sweets'),
        ('Sandesh', 1, 'piece', 90, 3, 12, 3.5, 10, true, false, 'sweets'),
        ('Kaju Katli', 1, 'piece', 100, 2.5, 12, 5, 9, true, false, 'sweets'),
        ('Mysore Pak', 1, 'piece', 150, 2, 16, 9, 12, true, false, 'sweets'),
        ('Peda', 1, 'piece', 80, 2, 10, 3.5, 8, true, false, 'sweets'),
        ('Ras Malai', 1, 'piece', 180, 5, 22, 8, 18, true, false, 'sweets'),
        ('Kalakand', 1, 'piece', 130, 3.5, 16, 6, 13, true, false, 'sweets'),
        ('Malpua', 1, 'piece', 200, 3, 28, 9, 20, true, false, 'sweets'),
        ('Imarti', 1, 'piece', 130, 1.5, 18, 6, 14, true, false, 'sweets'),
        ('Modak', 1, 'piece', 100, 2, 15, 4, 10, true, false, 'sweets'),
        ('Puran Poli', 1, 'piece', 240, 5, 40, 6, 28, true, false, 'sweets'),
        ('Payasam', 1, 'bowl', 250, 5, 38, 8, 30, true, false, 'sweets');

        -- INTERNATIONAL / OTHER
        INSERT INTO public.food_items (name, brand, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
        ('Pizza (Margherita)', NULL, 1, 'piece', 266, 11, 33, 10, 2, true, false, 'other'),
        ('Burger (Veg)', NULL, 1, 'piece', 390, 13, 44, 17, 4, true, false, 'other'),
        ('Pasta (Cooked)', NULL, 1, 'bowl', 220, 8, 43, 1.3, 2.5, true, true, 'grains'),
        ('Sandwich (Veg)', NULL, 1, 'piece', 250, 10, 35, 8, 3, true, false, 'other'),
        ('Oatmeal (Cooked)', NULL, 1, 'bowl', 158, 6, 27, 3, 4, true, true, 'grains'),
        ('Quinoa (Cooked)', NULL, 100, 'g', 120, 4.4, 21, 1.9, 2.8, true, true, 'grains'),
        ('Smoothie Bowl', NULL, 1, 'bowl', 300, 8, 50, 8, 6, true, true, 'other'),
        ('Muesli', NULL, 100, 'g', 400, 10, 68, 10, 7, true, false, 'grains'),
        ('Rasam', NULL, 1, 'bowl', 45, 1.5, 7, 1, 1.5, true, true, 'other'),
        ('Coconut Chutney', NULL, 2, 'tbsp', 60, 1, 4, 5, 1.5, true, true, 'other'),
        ('Chicken Biryani', NULL, 1, 'plate', 500, 25, 60, 16, 2, false, false, 'other'),
        ('Veg Biryani', NULL, 1, 'plate', 380, 9, 58, 12, 4, true, true, 'other'),
        ('Keema Pav', NULL, 1, 'plate', 420, 24, 38, 18, 3, false, false, 'other');

    END IF;
END $$;

COMMENT ON TABLE public.diet_plans IS 'User diet plans with nutritional targets';
COMMENT ON TABLE public.diet_meals IS 'Meal templates within diet plans';
COMMENT ON TABLE public.food_items IS 'Seeded with common Indian and international foods for diet tracking';
COMMENT ON TABLE public.diet_logs IS 'Daily food intake logs';
COMMENT ON TABLE public.diet_goals IS 'User nutritional goals and preferences';
