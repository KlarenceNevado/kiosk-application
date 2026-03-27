-- DIAGNOSTIC: VERIFY CHAT REALTIME SETTINGS
-- This script checks if the chat_messages table is ready for the hardened PWA chat.

DO $$
BEGIN
    -- 1. Ensure Table exists in Realtime Publication
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
        RAISE NOTICE '✅ Added chat_messages to supabase_realtime publication.';
    ELSE
        RAISE NOTICE '✅ chat_messages is already in supabase_realtime publication.';
    END IF;

    -- 2. Ensure REPLICA IDENTITY FULL
    -- Required for Realtime to broadcast full row data on UPDATE/DELETE
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'chat_messages' AND c.relreplident = 'f') THEN
        ALTER TABLE chat_messages REPLICA IDENTITY FULL;
        RAISE NOTICE '✅ Set REPLICA IDENTITY FULL for chat_messages.';
    ELSE
        RAISE NOTICE '✅ REPLICA IDENTITY FULL is already set for chat_messages.';
    END IF;

    -- 3. Verify RLS Policy for Realtime
    -- Realtime listeners (Postgres Changes) respect RLS. 
    -- We need a policy that allows the target roles (anon/authenticated) to SELECT.
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'chat_messages' AND policyname = 'Allow selective chat access') THEN
        CREATE POLICY "Allow selective chat access" ON chat_messages
        FOR ALL USING (true);
        RAISE NOTICE '✅ Created "Allow selective chat access" policy.';
    END IF;
END $$;
