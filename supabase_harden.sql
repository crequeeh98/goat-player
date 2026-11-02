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

-- 3. Strikte Policies für Pairing (SEC-01 & SEC-07)
-- Verhindert das Auslesen abgelaufener oder getrennter Sessions und beschränkt SELECT auf aktive Pairings.
CREATE POLICY "anon_pairing_select" ON remote_devices 
FOR SELECT 
USING (
  pin_expires_at > now() 
  AND status != 'disconnected'
);

CREATE POLICY "anon_pairing_insert" ON remote_devices 
FOR INSERT 
WITH CHECK (true);

CREATE POLICY "anon_pairing_update" ON remote_devices 
FOR UPDATE 
USING (
  pin_expires_at > (now() - interval '2 minutes')
)
WITH CHECK (true);

-- 4. Automatisches Aufräumen abgelaufener Sessions (verhindert Datenanhäufung)
CREATE OR REPLACE FUNCTION purge_expired_pairing_sessions()
RETURNS trigger AS $$
BEGIN
    DELETE FROM remote_devices 
    WHERE pin_expires_at < (now() - interval '10 minutes')
       OR (status = 'linked' AND updated_at < (now() - interval '5 minutes'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_purge_pairing ON remote_devices;
CREATE TRIGGER trg_purge_pairing
AFTER INSERT OR UPDATE ON remote_devices
FOR EACH STATEMENT
EXECUTE FUNCTION purge_expired_pairing_sessions();
