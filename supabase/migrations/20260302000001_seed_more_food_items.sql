-- Migration: Seed Additional Indian Food Items
-- Created: 2026-03-02
-- Description: Populate food_items table with ~100 more regional Indian foods

-- ============================================================================
-- SOUTH INDIAN - GRAINS & OTHER
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Uttapam', 1, 'piece', 180, 5, 28, 5, 2, true, true, 'grains'),
('Pongal', 1, 'bowl', 250, 7, 38, 7, 2.5, true, false, 'grains'),
('Medu Vada', 1, 'piece', 130, 5, 15, 6, 1.5, true, true, 'grains'),
('Appam', 1, 'piece', 120, 2.5, 22, 2, 0.8, true, true, 'grains'),
('Puttu', 1, 'piece', 240, 4, 42, 6, 3, true, true, 'grains'),
('Avial', 1, 'bowl', 160, 3.5, 14, 10, 4, true, true, 'vegetables'),
('Rasam', 1, 'bowl', 45, 1.5, 7, 1, 1.5, true, true, 'other'),
('Sambar Rice', 1, 'bowl', 300, 9, 50, 6, 4, true, true, 'grains'),
('Lemon Rice', 1, 'bowl', 250, 4, 42, 7, 1.5, true, true, 'grains'),
('Curd Rice', 1, 'bowl', 220, 6, 36, 5, 1, true, false, 'grains'),
('Coconut Chutney', 2, 'tbsp', 60, 1, 4, 5, 1.5, true, true, 'other'),
('Tomato Rice', 1, 'bowl', 260, 5, 44, 6, 2, true, true, 'grains'),
('Bisi Bele Bath', 1, 'bowl', 320, 10, 48, 9, 5, true, false, 'grains'),
('Pesarattu', 1, 'piece', 150, 7, 20, 4, 3, true, true, 'grains'),
('Rava Dosa', 1, 'piece', 160, 3, 24, 6, 1, true, true, 'grains');

-- ============================================================================
-- NORTH INDIAN - GRAINS, PROTEIN & VEGETABLES
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Chole Bhature', 1, 'plate', 450, 14, 55, 19, 8, true, false, 'grains'),
('Dal Makhani', 1, 'bowl', 260, 12, 30, 10, 6, true, false, 'protein'),
('Aloo Paratha', 1, 'piece', 200, 4.5, 28, 8, 2, true, false, 'grains'),
('Stuffed Kulcha', 1, 'piece', 280, 7, 40, 10, 2, true, false, 'grains'),
('Matar Paneer', 1, 'bowl', 290, 14, 18, 18, 4, true, false, 'vegetables'),
('Shahi Paneer', 1, 'bowl', 350, 15, 14, 26, 2, true, false, 'vegetables'),
('Kadhai Paneer', 1, 'bowl', 320, 16, 12, 24, 2.5, true, false, 'vegetables'),
('Aloo Gobi', 1, 'bowl', 180, 4, 24, 7, 4, true, true, 'vegetables'),
('Jeera Rice', 1, 'bowl', 200, 4, 38, 4, 1, true, false, 'grains'),
('Methi Thepla', 1, 'piece', 110, 3.5, 16, 4, 2, true, false, 'grains'),
('Missi Roti', 1, 'piece', 100, 4, 15, 2.5, 2.5, true, true, 'grains'),
('Rumali Roti', 1, 'piece', 90, 3, 17, 1, 1, true, false, 'grains'),
('Tandoori Roti', 1, 'piece', 80, 3, 16, 0.5, 1.5, true, true, 'grains');

-- ============================================================================
-- BENGALI - PROTEIN & SWEETS
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Fish Curry Bengali', 1, 'bowl', 220, 22, 8, 12, 1.5, false, false, 'protein'),
('Luchi', 1, 'piece', 100, 2, 13, 5, 0.5, true, false, 'grains'),
('Aloo Posto', 1, 'bowl', 200, 4, 22, 11, 3, true, true, 'vegetables'),
('Shukto', 1, 'bowl', 150, 4, 16, 8, 4, true, false, 'vegetables');

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
('Mishti Doi', 1, 'bowl', 200, 5, 32, 5, 26, true, false, 'sweets'),
('Sandesh', 1, 'piece', 90, 3, 12, 3.5, 10, true, false, 'sweets');

-- ============================================================================
-- GUJARATI - SNACKS & GRAINS
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Thepla', 1, 'piece', 120, 3.5, 17, 4.5, 2, true, false, 'grains'),
('Undhiyu', 1, 'bowl', 250, 6, 28, 13, 6, true, false, 'vegetables'),
('Khandvi', 100, 'g', 160, 6, 20, 6, 1, true, false, 'snacks'),
('Handvo', 1, 'piece', 200, 6, 28, 7, 3, true, false, 'snacks'),
('Dal Dhokli', 1, 'bowl', 280, 10, 40, 8, 5, true, false, 'grains');

-- ============================================================================
-- STREET FOOD - SNACKS
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Pav Bhaji', 1, 'plate', 400, 10, 52, 16, 5, true, false, 'snacks'),
('Sev Puri', 6, 'piece', 250, 5, 32, 12, 3, true, true, 'snacks'),
('Kachori', 1, 'piece', 200, 4, 22, 11, 2, true, false, 'snacks'),
('Aloo Tikki', 1, 'piece', 150, 3, 20, 7, 2, true, true, 'snacks'),
('Dahi Bhalla', 2, 'piece', 180, 5, 24, 7, 2, true, false, 'snacks'),
('Chole Tikki', 1, 'plate', 350, 12, 42, 14, 6, true, false, 'snacks'),
('Ragda Pattice', 1, 'plate', 300, 8, 40, 12, 5, true, true, 'snacks'),
('Dabeli', 1, 'piece', 250, 5, 35, 10, 3, true, true, 'snacks'),
('Vada Pav', 1, 'piece', 290, 6, 36, 13, 3, true, true, 'snacks'),
('Misal Pav', 1, 'plate', 400, 14, 50, 15, 7, true, true, 'snacks');

-- ============================================================================
-- RESTAURANT MAINS - PROTEIN & OTHER
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Chicken Biryani', 1, 'plate', 500, 25, 60, 16, 2, false, false, 'other'),
('Veg Biryani', 1, 'plate', 380, 9, 58, 12, 4, true, true, 'other'),
('Butter Chicken', 1, 'bowl', 440, 28, 14, 30, 2, false, false, 'protein'),
('Kadhai Chicken', 1, 'bowl', 350, 30, 10, 22, 2.5, false, false, 'protein'),
('Tandoori Chicken', 1, 'piece', 260, 30, 5, 14, 1, false, false, 'protein'),
('Chicken Tikka', 100, 'g', 200, 25, 6, 9, 1, false, false, 'protein'),
('Malai Kofta', 1, 'bowl', 350, 10, 22, 25, 3, true, false, 'vegetables'),
('Dal Tadka', 1, 'bowl', 180, 10, 25, 5, 5, true, true, 'protein'),
('Dal Fry', 1, 'bowl', 170, 10, 24, 4, 5, true, true, 'protein'),
('Paneer Tikka', 100, 'g', 250, 16, 8, 18, 1.5, true, false, 'protein'),
('Paneer Butter Masala', 1, 'bowl', 400, 16, 16, 30, 2, true, false, 'vegetables');

-- ============================================================================
-- MODERN / HEALTHY - GRAINS, PROTEIN & OTHER
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Oats Upma', 1, 'bowl', 200, 7, 30, 6, 4, true, true, 'grains'),
('Quinoa Khichdi', 1, 'bowl', 230, 9, 34, 6, 5, true, true, 'grains'),
('Smoothie Bowl', 1, 'bowl', 300, 8, 50, 8, 6, true, true, 'other'),
('Sprouts Salad', 1, 'bowl', 120, 8, 16, 2, 5, true, true, 'protein'),
('Muesli', 100, 'g', 400, 10, 68, 10, 7, true, false, 'grains'),
('Ragi Dosa', 1, 'piece', 120, 3, 22, 2.5, 3, true, true, 'grains'),
('Multigrain Roti', 1, 'piece', 85, 3.5, 15, 1.5, 3, true, true, 'grains'),
('Sattu Paratha', 1, 'piece', 220, 8, 30, 7, 4, true, false, 'grains'),
('Bajra Roti', 1, 'piece', 100, 3, 20, 1.5, 2.5, true, true, 'grains'),
('Jowar Roti', 1, 'piece', 95, 3, 20, 1, 2.5, true, true, 'grains');

-- ============================================================================
-- BEVERAGES
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
('Filter Coffee', 1, 'cup', 80, 2, 10, 3, 8, true, false, 'beverages'),
('Masala Chai', 1, 'cup', 70, 2, 10, 2, 8, true, false, 'beverages'),
('Jaljeera', 1, 'cup', 30, 0.5, 7, 0.2, 5, true, true, 'beverages'),
('Aam Panna', 1, 'cup', 90, 0.5, 22, 0.3, 18, true, true, 'beverages'),
('Thandai', 1, 'cup', 200, 5, 28, 8, 22, true, false, 'beverages'),
('Badam Milk', 1, 'cup', 180, 6, 22, 8, 18, true, false, 'beverages'),
('Sugarcane Juice', 1, 'cup', 120, 0.3, 30, 0, 28, true, true, 'beverages'),
('Nimbu Pani', 1, 'cup', 25, 0.2, 6, 0, 5, true, true, 'beverages'),
('Mango Lassi', 1, 'cup', 180, 4, 30, 4, 24, true, false, 'beverages'),
('Rose Sharbat', 1, 'cup', 100, 0, 25, 0, 24, true, true, 'beverages');

-- ============================================================================
-- SWEETS
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, sugar_g, is_vegetarian, is_vegan, category) VALUES
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

-- ============================================================================
-- ADDITIONAL REGIONAL & POPULAR ITEMS
-- ============================================================================

INSERT INTO public.food_items (name, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, is_vegetarian, is_vegan, category) VALUES
('Egg Bhurji', 2, 'piece', 190, 14, 3, 14, 0.5, false, false, 'protein'),
('Mutton Curry', 1, 'bowl', 380, 28, 8, 26, 1.5, false, false, 'protein'),
('Prawn Masala', 1, 'bowl', 240, 22, 10, 13, 2, false, false, 'protein'),
('Keema Pav', 1, 'plate', 420, 24, 38, 18, 3, false, false, 'other'),
('Egg Curry', 1, 'bowl', 220, 14, 10, 14, 2, false, false, 'protein'),
('Sabudana Khichdi', 1, 'bowl', 250, 3, 42, 8, 1, true, true, 'grains'),
('Poha Jalebi', 1, 'plate', 350, 5, 55, 12, 2, true, false, 'snacks'),
('Masala Dosa', 1, 'piece', 200, 5, 30, 7, 2, true, true, 'grains'),
('Egg Dosa', 1, 'piece', 210, 9, 24, 9, 1, false, false, 'grains'),
('Paneer Dosa', 1, 'piece', 230, 9, 26, 10, 1.5, true, false, 'grains');

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE public.food_items IS 'Seeded with common Indian and international foods for diet tracking (extended with regional Indian foods)';
