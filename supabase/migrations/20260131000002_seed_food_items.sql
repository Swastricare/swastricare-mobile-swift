-- Migration: Seed Food Items Database
-- Created: 2026-01-31
-- Description: Populate food_items table with common Indian and international foods

-- ============================================================================
-- INDIAN FOODS - GRAINS
-- ============================================================================

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
('Puri', 1, 'piece', 81, 1.5, 10, 4, 0.5, true, false, 'grains');

-- ============================================================================
-- INDIAN FOODS - PROTEIN
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Dal (Cooked)', 1, 'bowl', 198, 15, 30, 1, 8, true, true, 'protein'),
('Rajma (Kidney Beans)', 1, 'bowl', 225, 15, 40, 1, 13, true, true, 'protein'),
('Chana (Chickpeas)', 1, 'bowl', 269, 15, 45, 4, 12, true, true, 'protein'),
('Paneer', 100, 'g', 265, 18, 1.2, 20, 0, true, false, 'protein'),
('Chicken Breast (Cooked)', 100, 'g', 165, 31, 0, 3.6, 0, false, false, 'protein'),
('Egg (Boiled)', 1, 'piece', 78, 6.3, 0.6, 5.3, 0, false, false, 'protein'),
('Fish (Cooked)', 100, 'g', 206, 22, 0, 12, 0, false, false, 'protein'),
('Tofu', 100, 'g', 76, 8, 1.9, 4.8, 0.3, true, true, 'protein'),
('Soya Chunks', 100, 'g', 345, 52, 33, 0.5, 13, true, true, 'protein');

-- ============================================================================
-- INDIAN FOODS - VEGETABLES
-- ============================================================================

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
('Spinach (Cooked)', 100, 'g', 23, 2.9, 3.6, 0.4, 2.2, true, true, 'vegetables');

-- ============================================================================
-- FRUITS
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
('Banana', 1, 'piece', 105, 1.3, 27, 0.4, 3.1, 14, true, true, 'fruits'),
('Apple', 1, 'piece', 95, 0.5, 25, 0.3, 4.4, 19, true, true, 'fruits'),
('Mango', 1, 'piece', 202, 2.8, 50, 1.3, 5.4, 46, true, true, 'fruits'),
('Orange', 1, 'piece', 62, 1.2, 15, 0.2, 3.1, 12, true, true, 'fruits'),
('Papaya', 100, 'g', 43, 0.5, 11, 0.3, 1.7, 7.8, true, true, 'fruits'),
('Watermelon', 100, 'g', 30, 0.6, 7.6, 0.2, 0.4, 6.2, true, true, 'fruits'),
('Grapes', 100, 'g', 69, 0.7, 18, 0.2, 0.9, 15, true, true, 'fruits'),
('Pomegranate', 100, 'g', 83, 1.7, 19, 1.2, 4, 14, true, true, 'fruits');

-- ============================================================================
-- DAIRY
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
('Milk (Full Fat)', 1, 'cup', 149, 7.7, 12, 8, 12, true, false, 'dairy'),
('Milk (Low Fat)', 1, 'cup', 102, 8.2, 12, 2.4, 13, true, false, 'dairy'),
('Curd (Yogurt)', 1, 'bowl', 98, 11, 4.7, 4.3, 4.7, true, false, 'dairy'),
('Buttermilk', 1, 'cup', 40, 2, 5, 0.9, 5, true, false, 'dairy'),
('Ghee', 1, 'tbsp', 112, 0, 0, 12.7, 0, true, false, 'dairy'),
('Cheese', 1, 'oz', 114, 7, 0.4, 9.4, 0.5, true, false, 'dairy'),
('Butter', 1, 'tbsp', 102, 0.1, 0, 11.5, 0, true, false, 'dairy');

-- ============================================================================
-- BEVERAGES
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
('Chai (Tea with Milk)', 1, 'cup', 60, 2, 8, 2, 6, true, false, 'beverages'),
('Black Tea', 1, 'cup', 2, 0, 0.7, 0, 0, true, true, 'beverages'),
('Green Tea', 1, 'cup', 2, 0, 0, 0, 0, true, true, 'beverages'),
('Coffee (Black)', 1, 'cup', 2, 0.3, 0, 0, 0, true, true, 'beverages'),
('Coffee with Milk', 1, 'cup', 38, 2, 3, 1.5, 3, true, false, 'beverages'),
('Lassi (Sweet)', 1, 'cup', 150, 5, 25, 3, 20, true, false, 'beverages'),
('Fresh Lime Water', 1, 'cup', 25, 0.3, 6, 0, 5, true, true, 'beverages'),
('Coconut Water', 1, 'cup', 46, 1.7, 9, 0.5, 6, true, true, 'beverages');

-- ============================================================================
-- SNACKS
-- ============================================================================

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
('Cashews', 100, 'g', 553, 18, 30, 44, 3, true, true, 'snacks');

-- ============================================================================
-- SWEETS
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
('Gulab Jamun', 1, 'piece', 175, 3, 25, 7, 20, true, false, 'sweets'),
('Rasgulla', 1, 'piece', 106, 2, 20, 1, 18, true, false, 'sweets'),
('Jalebi', 100, 'g', 150, 1, 28, 4, 25, true, false, 'sweets'),
('Ladoo', 1, 'piece', 186, 3, 28, 7, 22, true, false, 'sweets'),
('Barfi', 1, 'piece', 120, 2, 18, 5, 15, true, false, 'sweets'),
('Kheer', 1, 'bowl', 194, 5, 30, 6, 25, true, false, 'sweets'),
('Halwa', 100, 'g', 416, 3, 60, 17, 45, true, false, 'sweets');

-- ============================================================================
-- INTERNATIONAL FOODS
-- ============================================================================

INSERT INTO public.food_items (name, brand, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Pizza (Margherita)', NULL, 1, 'piece', 266, 11, 33, 10, 2, true, false, 'other'),
('Burger (Veg)', NULL, 1, 'piece', 390, 13, 44, 17, 4, true, false, 'other'),
('Pasta (Cooked)', NULL, 1, 'bowl', 220, 8, 43, 1.3, 2.5, true, true, 'grains'),
('Sandwich (Veg)', NULL, 1, 'piece', 250, 10, 35, 8, 3, true, false, 'other'),
('French Fries', NULL, 100, 'g', 312, 3.4, 41, 15, 3.8, true, true, 'snacks'),
('Oatmeal (Cooked)', NULL, 1, 'bowl', 158, 6, 27, 3, 4, true, true, 'grains'),
('Quinoa (Cooked)', NULL, 100, 'g', 120, 4.4, 21, 1.9, 2.8, true, true, 'grains'),
('Avocado', NULL, 1, 'piece', 234, 2.9, 12, 21, 10, true, true, 'fruits'),
('Peanut Butter', NULL, 2, 'tbsp', 188, 8, 7, 16, 2, true, true, 'protein'),
('Protein Shake', NULL, 1, 'cup', 120, 20, 5, 2, 1, true, false, 'beverages');

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE public.food_items IS 'Seeded with common Indian and international foods for diet tracking';
