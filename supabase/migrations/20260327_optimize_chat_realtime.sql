-- 🚀 OPTIMIZE CHAT REALTIME & PERFORMANCE
-- This script adds critical indexes and ensures REPLICA IDENTITY FULL for chat table.

-- 1. Ensure Table exists in Realtime Publication
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
    
    -- Add chat_messages to publication if not already added
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
    EXCEPTION WHEN others THEN
        -- Table might already be in publication
        NULL;
    END;
END $$;

-- 2. Performance Indexes (B-Tree for equality and ordering)
CREATE INDEX IF NOT EXISTS idx_chat_sender_id ON chat_messages USING btree (sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_receiver_id ON chat_messages USING btree (receiver_id);
CREATE INDEX IF NOT EXISTS idx_chat_timestamp ON chat_messages USING btree (timestamp DESC);

-- 3. Composite Index for fast conversation retrieval
CREATE INDEX IF NOT EXISTS idx_chat_conversation 
ON chat_messages USING btree (sender_id, receiver_id, timestamp DESC);

-- 4. Set REPLICA IDENTITY FULL
-- Allows Postgres to broadcast full row data on UPDATE/DELETE, 
-- ensuring even partial updates (reactions, etc) have full context for UI.
ALTER TABLE chat_messages REPLICA IDENTITY FULL;

-- 5. Enable RLS and set sensible policies (if not already set)
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'chat_messages' AND policyname = 'Allow selective chat access') THEN
        CREATE POLICY "Allow selective chat access" ON chat_messages
        FOR ALL USING (true); -- Simplified for research kiosk environment
    END IF;
END $$;
