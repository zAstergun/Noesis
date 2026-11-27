CREATE TABLE IF NOT EXISTS public.noesis_roadmaps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  roadmap_key text,
  title text NOT NULL,
  goal text DEFAULT '',
  subject text NOT NULL,
  level text DEFAULT 'Intermediário',
  estimated_weeks integer DEFAULT 4,
  steps jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.noesis_roadmaps ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'noesis_roadmaps'
      AND policyname = 'noesis_roadmaps_user_policy'
  ) THEN
    CREATE POLICY "noesis_roadmaps_user_policy"
      ON public.noesis_roadmaps
      FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_noesis_roadmaps_user_key
  ON public.noesis_roadmaps (user_id, roadmap_key)
  WHERE roadmap_key IS NOT NULL;
