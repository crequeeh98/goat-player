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

-- 3. Saubere Policy für Pairing (erlaubt UPSERT und SELECT für anonyme Pairing-Sessions)
-- Zero-Knowledge Architektur (SEC-01):
-- Passwörter und Server-URLs werden im Webportal und TV-Client vor der Übertragung
-- per client-seitigem AES-256-GCM (aus dem Session-PIN abgeleitet) verschlüsselt.
-- In der Tabelle liegen keine Klartext-Zugangsdaten; Realtime-Payloads enthalten nur Chiffretext.
CREATE POLICY "anon_pairing_all" ON remote_devices 
FOR ALL USING (true) WITH CHECK (true);

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
