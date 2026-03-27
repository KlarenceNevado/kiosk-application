-- 🚀 FINAL REALTIME FIX: GRANT SCHEMA PERMISSIONS
-- WebSocket state error: 3 often happens because the 'anon' role is missing 
-- 'usage' permissions on the internal 'realtime' schema.

GRANT USAGE ON SCHEMA realtime TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- Ensure the chat_messages table is in the publication
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
    END IF;
END $$;
