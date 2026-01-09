-- ============================================================================
-- USER SYNC TRIGGER
-- ============================================================================
-- Automatically creates a public.users record when auth.users record is created
-- This ensures user data is always synced between auth and public schemas

-- Create function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert into public.users table
    INSERT INTO public.users (
        id,
        email,
        phone,
        full_name,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        NEW.email,
        NEW.phone,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Backfill existing users from auth.users to public.users
INSERT INTO public.users (
    id,
    email,
    phone,
    full_name,
    created_at,
    updated_at
)
SELECT 
    id,
    email,
    phone,
    COALESCE(raw_user_meta_data->>'full_name', ''),
    created_at,
    NOW()
FROM auth.users
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
    updated_at = NOW();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
