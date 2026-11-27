-- 1. Performance indexes for existing tables
CREATE INDEX IF NOT EXISTS idx_noesis_sessions_user_date
  ON public.noesis_sessions (user_id, study_date DESC);
CREATE INDEX IF NOT EXISTS idx_noesis_calendar_events_user_start
  ON public.noesis_calendar_events (user_id, start_time ASC);
CREATE INDEX IF NOT EXISTS idx_noesis_documents_user_created
  ON public.noesis_documents (user_id, created_at DESC);

-- 2. Flashcard Decks (public.noesis_flashcard_decks)
CREATE TABLE IF NOT EXISTS public.noesis_flashcard_decks (
  id text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  subject text NOT NULL DEFAULT 'Geral',
  description text NOT NULL DEFAULT '',
  cards jsonb NOT NULL DEFAULT '[]'::jsonb,
  color_hex text NOT NULL DEFAULT '7C6CF0',
  icon_code integer NOT NULL DEFAULT 58849,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (user_id, id)
);

COMMENT ON TABLE public.noesis_flashcard_decks IS '🧠 [NOESIS] Baralhos e cartões de revisão espaçada 3D.';
ALTER TABLE public.noesis_flashcard_decks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_flashcard_decks' AND policyname = 'noesis_flashcard_decks_user_policy'
  ) THEN
    CREATE POLICY "noesis_flashcard_decks_user_policy"
      ON public.noesis_flashcard_decks
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_noesis_flashcard_decks_user_created
  ON public.noesis_flashcard_decks (user_id, created_at DESC);

-- 3. Study Notebooks (public.noesis_study_notebooks)
CREATE TABLE IF NOT EXISTS public.noesis_study_notebooks (
  id text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  subject text NOT NULL DEFAULT 'Geral',
  description text NOT NULL DEFAULT '',
  color_hex text NOT NULL DEFAULT '7C6CF0',
  icon_code integer NOT NULL DEFAULT 58342,
  notes jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (user_id, id)
);

COMMENT ON TABLE public.noesis_study_notebooks IS '🧠 [NOESIS] Cadernos e anotações de estudo estruturadas.';
ALTER TABLE public.noesis_study_notebooks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_study_notebooks' AND policyname = 'noesis_study_notebooks_user_policy'
  ) THEN
    CREATE POLICY "noesis_study_notebooks_user_policy"
      ON public.noesis_study_notebooks
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_noesis_study_notebooks_user_created
  ON public.noesis_study_notebooks (user_id, created_at DESC);

-- 4. Insight Ledger (public.noesis_insight_ledger)
CREATE TABLE IF NOT EXISTS public.noesis_insight_ledger (
  id text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount integer NOT NULL,
  description text NOT NULL DEFAULT '',
  source text NOT NULL DEFAULT 'study',
  reference text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (user_id, id)
);

COMMENT ON TABLE public.noesis_insight_ledger IS '🧠 [NOESIS] Razão contábil da Economia de Insights (✦).';
ALTER TABLE public.noesis_insight_ledger ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_insight_ledger' AND policyname = 'noesis_insight_ledger_user_policy'
  ) THEN
    CREATE POLICY "noesis_insight_ledger_user_policy"
      ON public.noesis_insight_ledger
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_noesis_insight_ledger_user_created
  ON public.noesis_insight_ledger (user_id, created_at DESC);

-- 5. Study Groups (public.noesis_study_groups)
CREATE TABLE IF NOT EXISTS public.noesis_study_groups (
  id text PRIMARY KEY,
  leader_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invite_code text NOT NULL UNIQUE,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.noesis_study_groups IS '🧠 [NOESIS] Grupos colaborativos de estudo e ranking interno.';
ALTER TABLE public.noesis_study_groups ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.noesis_is_study_group_member(
  p_payload jsonb,
  p_uid uuid
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(COALESCE(p_payload -> 'members', '[]'::jsonb)) AS m
    WHERE (m ->> 'user_id') = p_uid::text
  );
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_study_groups' AND policyname = 'noesis_study_groups_select_policy'
  ) THEN
    CREATE POLICY "noesis_study_groups_select_policy"
      ON public.noesis_study_groups
      FOR SELECT
      TO authenticated
      USING (
        auth.uid() = leader_id
        OR public.noesis_is_study_group_member(payload, auth.uid())
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_study_groups' AND policyname = 'noesis_study_groups_insert_policy'
  ) THEN
    CREATE POLICY "noesis_study_groups_insert_policy"
      ON public.noesis_study_groups
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = leader_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_study_groups' AND policyname = 'noesis_study_groups_update_policy'
  ) THEN
    CREATE POLICY "noesis_study_groups_update_policy"
      ON public.noesis_study_groups
      FOR UPDATE
      TO authenticated
      USING (
        auth.uid() = leader_id
        OR public.noesis_is_study_group_member(payload, auth.uid())
      )
      WITH CHECK (
        auth.uid() = leader_id
        OR public.noesis_is_study_group_member(payload, auth.uid())
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_study_groups' AND policyname = 'noesis_study_groups_delete_policy'
  ) THEN
    CREATE POLICY "noesis_study_groups_delete_policy"
      ON public.noesis_study_groups
      FOR DELETE
      TO authenticated
      USING (auth.uid() = leader_id);
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_noesis_study_groups_updated
  ON public.noesis_study_groups (updated_at DESC);

CREATE OR REPLACE FUNCTION public.noesis_join_study_group_by_code(
  p_invite_code text,
  p_member jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_code text := upper(trim(coalesce(p_invite_code, '')));
  v_group public.noesis_study_groups%ROWTYPE;
  v_members jsonb;
  v_updated_payload jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória para entrar em um grupo.';
  END IF;

  IF v_code = '' THEN
    RETURN NULL;
  END IF;

  IF coalesce(p_member ->> 'user_id', '') <> v_uid::text THEN
    RAISE EXCEPTION 'Identificador de membro inválido para o usuário autenticado.';
  END IF;

  SELECT *
    INTO v_group
    FROM public.noesis_study_groups
   WHERE upper(invite_code) = v_code
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF public.noesis_is_study_group_member(v_group.payload, v_uid) THEN
    RETURN v_group.payload;
  END IF;

  v_members := COALESCE(v_group.payload -> 'members', '[]'::jsonb) || jsonb_build_array(p_member);
  v_updated_payload := jsonb_set(
    jsonb_set(v_group.payload, '{members}', v_members, true),
    '{updated_at}',
    to_jsonb(timezone('utc'::text, now())),
    true
  );

  UPDATE public.noesis_study_groups
     SET payload = v_updated_payload,
         updated_at = timezone('utc'::text, now())
   WHERE id = v_group.id;

  RETURN v_updated_payload;
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.noesis_flashcard_decks,
  public.noesis_study_notebooks,
  public.noesis_insight_ledger,
  public.noesis_study_groups
TO authenticated, service_role;
