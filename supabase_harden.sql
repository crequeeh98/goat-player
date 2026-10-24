-- ====================================================================
-- GOATPlayer - Supabase Definitiver RLS Lockdown
-- Führe dies im Supabase Dashboard -> SQL Editor aus.
-- ====================================================================

-- 1. Lösche JEDE bisherige Policy auf remote_devices (egal welcher Name)
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'remote_devices') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON remote_devices', pol.policyname);
    END LOOP;
END $$;

-- 2. RLS zwingend für alle Rollen (inkl. Table Owner) erzwingen
ALTER TABLE remote_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE remote_devices FORCE ROW LEVEL SECURITY;

-- 3. Schreib-Zugriff für das Pairing erlauben
CREATE POLICY "anon_insert_pairing" ON remote_devices 
FOR INSERT WITH CHECK (true);

CREATE POLICY "anon_update_pairing" ON remote_devices 
FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "anon_delete_pairing" ON remote_devices 
FOR DELETE USING (true);

-- 4. Lese-Zugriff: Nur für Sessions des aktuellen Zeitfensters (max 1 Stunde).
-- Verhindert das Auslesen von alten Sessions und erlaubt sauberes Beenden.
CREATE POLICY "anon_select_window" ON remote_devices 
FOR SELECT USING (pin_expires_at > now() - interval '1 hour');
