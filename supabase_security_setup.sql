-- ====================================================================
-- GOATPlayer - Supabase Security Lockdown
-- Führe dieses Skript im Supabase Dashboard unter "SQL Editor" aus.
-- ====================================================================

-- 1. Alte/bereits exponierte Test-Sessions sofort leeren
TRUNCATE TABLE remote_devices;

-- 2. Row Level Security (RLS) aktivieren
ALTER TABLE remote_devices ENABLE ROW LEVEL SECURITY;

-- 3. Bestehende unsichere Policies droppen
DROP POLICY IF EXISTS "Allow anon select" ON remote_devices;
DROP POLICY IF EXISTS "Enable read access for all users" ON remote_devices;
DROP POLICY IF EXISTS "Public select" ON remote_devices;
DROP POLICY IF EXISTS "Allow all for anon" ON remote_devices;
DROP POLICY IF EXISTS "Allow anon insert" ON remote_devices;
DROP POLICY IF EXISTS "Allow anon update" ON remote_devices;
DROP POLICY IF EXISTS "Allow anon delete" ON remote_devices;

-- 4. Sichere Policies:
-- a) Erlaube Erstellen von Pairing-Sessions (INSERT)
CREATE POLICY "Allow anon insert" ON remote_devices
FOR INSERT WITH CHECK (true);

-- b) Erlaube Aktualisieren von Pairing-Sessions (UPDATE)
CREATE POLICY "Allow anon update" ON remote_devices
FOR UPDATE USING (true) WITH CHECK (true);

-- c) Direkte SELECTs sperren: Niemand kann mehr "SELECT * FROM remote_devices" leersaugen!
-- (Ohne SELECT-Policy blockiert RLS automatisch jeden direkten anonymen Tabellen-Dump).

-- 5. Sichere RPC-Funktion für das Web-Portal:
-- Abfrage von Gerätedaten ist NUR möglich, wenn Device-ID UND 6-stelliger PIN exakt übereinstimmen
-- und der PIN noch nicht abgelaufen ist.
CREATE OR REPLACE FUNCTION get_device_pairing(p_device_id text, p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(r) INTO v_result
  FROM remote_devices r
  WHERE r.device_id = p_device_id
    AND r.pin = p_pin
    AND r.pin_expires_at > now()
    AND r.status != 'disconnected';

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_device_pairing(text, text) TO anon, authenticated;
