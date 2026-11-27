GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.noesis_calendar_events TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.noesis_sessions TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.noesis_documents TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.noesis_quizzes TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.noesis_roadmaps TO authenticated, service_role;

ALTER TABLE public.noesis_calendar_events REPLICA IDENTITY FULL;
ALTER TABLE public.noesis_sessions REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'noesis_calendar_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.noesis_calendar_events;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'noesis_sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.noesis_sessions;
  END IF;
END
$$;
