-- ====================================================================
-- GOATPlayer - Supabase Pairing RLS Policy
-- Führe dies im Supabase Dashboard -> SQL Editor aus.
-- ====================================================================

-- 1. Alle bisherigen Policies auf remote_devices dynamisch entfernen
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'remote_devices') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON remote_devices', pol.policyname);
    END LOOP;
END $$;

-- 2. RLS aktivieren
ALTER TABLE remote_devices ENABLE ROW LEVEL SECURITY;

-- 3. Saubere Policy für Pairing (erlaubt UPSERT auch bei bestehenden Geräte-IDs)
-- Da Passwörter und Server-URLs im Code komplett entfernt wurden (Zero-Knowledge),
-- liegen in Supabase ohnehin nur noch Dummy-Playlist-Namen ("Github").
CREATE POLICY "anon_pairing_all" ON remote_devices 
FOR ALL USING (true) WITH CHECK (true);
