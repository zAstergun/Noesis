-- Configure Noesis in Aster CRM (crm_apps), create remote platform control table (noesis_platform_config),
-- and expose/upgrade CRM RPCs for full inspection and administration of the Noesis platform.

-- 1. Register / update official Noesis metadata in public.crm_apps & clean up legacy aster_study alias
INSERT INTO public.crm_apps (
  id, name, description, category, table_prefix, status, icon, color, homepage_url, created_at
)
VALUES (
  'noesis',
  'Noesis',
  'Sistema operacional cognitivo e motor de estudos com IA (RAG, Simulados, Flashcards 3D, Cadernos, Trilhas, Calendário, Grupos, Ranking de Elos e Economia de Insights).',
  'Education & Productivity',
  'noesis_',
  'active',
  '/logos/noesis.svg',
  '#7C6CF0',
  'https://noesis.asterdev.me',
  timezone('utc'::text, now())
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  table_prefix = EXCLUDED.table_prefix,
  status = EXCLUDED.status,
  icon = EXCLUDED.icon,
  color = EXCLUDED.color,
  homepage_url = EXCLUDED.homepage_url;

DELETE FROM public.crm_apps WHERE id = 'aster_study';

-- 2. Remote Platform Control Configuration Table (strictly prefixed with noesis_)
CREATE TABLE IF NOT EXISTS public.noesis_platform_config (
  id text PRIMARY KEY DEFAULT 'default',
  maintenance_mode boolean NOT NULL DEFAULT false,
  maintenance_message text NOT NULL DEFAULT 'O Noesis está passando por uma manutenção programada para melhorias. Voltamos em instantes!',
  allow_guest_mode boolean NOT NULL DEFAULT true,
  allow_registration boolean NOT NULL DEFAULT true,
  feature_flags jsonb NOT NULL DEFAULT '{
    "ai_agent": true,
    "quizzes": true,
    "flashcards": true,
    "notebooks": true,
    "roadmaps": true,
    "calendar": true,
    "study_groups": true,
    "ranking": true,
    "shop": true
  }'::jsonb,
  announcement jsonb NOT NULL DEFAULT '{
    "enabled": false,
    "title": "",
    "message": "",
    "type": "info",
    "cta_label": "",
    "cta_url": ""
  }'::jsonb,
  version_control jsonb NOT NULL DEFAULT '{
    "latest_version": "1.0.0",
    "min_supported_version": "1.0.0",
    "force_update": false,
    "release_notes": "Versão inicial Aster Soft Clay v1.0.0+1",
    "download_url": "https://github.com/zAstergun/Noesis/releases"
  }'::jsonb,
  economy_config jsonb NOT NULL DEFAULT '{
    "welcome_bonus": 100,
    "daily_soft_cap": 150,
    "vip_multiplier": 2,
    "daily_goal_hit": 15,
    "weekly_goal_hit": 150,
    "exam_completed": 20,
    "exam_high_score_bonus": 30
  }'::jsonb,
  ai_governance jsonb NOT NULL DEFAULT '{
    "default_provider": "google",
    "default_model": "gemini-flash-lite-latest",
    "max_attachments": 5,
    "system_notice": ""
  }'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.noesis_platform_config IS '🧠 [NOESIS] Configuração remota de governança, feature flags, manutenção e economia controlada pelo Aster CRM.';

ALTER TABLE public.noesis_platform_config ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_platform_config' AND policyname = 'noesis_platform_config_public_read'
  ) THEN
    CREATE POLICY "noesis_platform_config_public_read"
      ON public.noesis_platform_config
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'noesis_platform_config' AND policyname = 'noesis_platform_config_staff_write'
  ) THEN
    CREATE POLICY "noesis_platform_config_staff_write"
      ON public.noesis_platform_config
      FOR ALL
      TO authenticated
      USING (public.crm_is_staff(auth.uid()))
      WITH CHECK (public.crm_is_staff(auth.uid()));
  END IF;
END
$$;

GRANT SELECT ON TABLE public.noesis_platform_config TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.noesis_platform_config TO authenticated, service_role;

INSERT INTO public.noesis_platform_config (id)
VALUES ('default')
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'noesis_platform_config'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.noesis_platform_config;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END
$$;

-- 3. Touch user app usage in crm_user_apps when an authenticated user opens an Aster app
CREATE OR REPLACE FUNCTION public.crm_touch_user_app(
  p_app_id text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_app_id text := lower(trim(coalesce(p_app_id, '')));
BEGIN
  IF v_uid IS NULL OR v_app_id = '' THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.crm_apps WHERE id = v_app_id) THEN
    RETURN false;
  END IF;

  INSERT INTO public.crm_user_apps (
    user_id, app_id, first_used_at, last_used_at, use_count, metadata
  )
  VALUES (
    v_uid, v_app_id, now(), now(), 1, coalesce(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT (user_id, app_id) DO UPDATE SET
    last_used_at = now(),
    use_count = coalesce(public.crm_user_apps.use_count, 0) + 1,
    metadata = coalesce(public.crm_user_apps.metadata, '{}'::jsonb) || coalesce(EXCLUDED.metadata, '{}'::jsonb);

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.crm_touch_user_app(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crm_touch_user_app(text, jsonb) TO authenticated, service_role;

-- 4. Extend crm_get_app_table_data to support all Noesis tables + config
CREATE OR REPLACE FUNCTION public.crm_get_app_table_data(p_table text, p_limit integer DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 250));
BEGIN
  IF NOT public.crm_is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado: permissão de equipe necessária.';
  END IF;

  IF p_table = 'studioos_projects' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.studioos_projects ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'studioos_history' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.studioos_history ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'studioos_tasks' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.studioos_tasks ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'studioos_saved_categories' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.studioos_saved_categories ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'soulfighter_ranking' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.soulfighter_ranking ORDER BY score DESC, time_ms ASC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_sessions' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_sessions ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_calendar_events' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_calendar_events ORDER BY start_time DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_documents' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_documents ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_quizzes' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_quizzes ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_roadmaps' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_roadmaps ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_flashcard_decks' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_flashcard_decks ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_study_notebooks' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_study_notebooks ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_insight_ledger' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_insight_ledger ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_study_groups' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_study_groups ORDER BY created_at DESC LIMIT v_limit) t;

  ELSIF p_table = 'noesis_platform_config' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_res
    FROM (SELECT * FROM public.noesis_platform_config ORDER BY updated_at DESC LIMIT v_limit) t;

  ELSE
    v_res := '[]'::jsonb;
  END IF;

  RETURN v_res;
END;
$$;

-- 5. Extend crm_get_ecosystem_metrics with Noesis totals
CREATE OR REPLACE FUNCTION public.crm_get_ecosystem_metrics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_metrics jsonb;
BEGIN
  IF NOT public.crm_is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado: permissão de equipe necessária.';
  END IF;

  SELECT jsonb_build_object(
    'total_accounts', (SELECT count(*) FROM public.profiles),
    'vip_accounts', (SELECT count(*) FROM public.profiles WHERE is_vip = true),
    'total_staff', (SELECT count(*) FROM public.crm_staff WHERE is_active = true),
    'total_apps', (SELECT count(*) FROM public.crm_apps),
    'studioos_projects', (SELECT count(*) FROM public.studioos_projects),
    'studioos_history_records', (SELECT count(*) FROM public.studioos_history),
    'studioos_tasks', (SELECT count(*) FROM public.studioos_tasks),
    'noesis_sessions', (SELECT count(*) FROM public.noesis_sessions),
    'noesis_total_minutes', (SELECT coalesce(sum(duration_minutes), 0) FROM public.noesis_sessions),
    'noesis_calendar_events', (SELECT count(*) FROM public.noesis_calendar_events),
    'noesis_documents', (SELECT count(*) FROM public.noesis_documents),
    'noesis_quizzes', (SELECT count(*) FROM public.noesis_quizzes),
    'noesis_roadmaps', (SELECT count(*) FROM public.noesis_roadmaps),
    'noesis_flashcard_decks', (SELECT count(*) FROM public.noesis_flashcard_decks),
    'noesis_study_notebooks', (SELECT count(*) FROM public.noesis_study_notebooks),
    'noesis_insight_ledger', (SELECT count(*) FROM public.noesis_insight_ledger),
    'noesis_study_groups', (SELECT count(*) FROM public.noesis_study_groups),
    'recent_logs', (
      SELECT coalesce(jsonb_agg(row_to_json(l)), '[]'::jsonb)
      FROM (
        SELECT id, actor_name, actor_email, action, target_type, target_id, details, created_at
        FROM public.crm_audit_logs
        ORDER BY created_at DESC
        LIMIT 20
      ) l
    )
  ) INTO v_metrics;

  RETURN v_metrics;
END;
$$;

-- 6. Extend crm_get_users_directory with Noesis usage counts and stats
CREATE OR REPLACE FUNCTION public.crm_get_users_directory()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.crm_is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado: permissão de equipe necessária.';
  END IF;

  SELECT coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      p.id,
      u.email,
      p.full_name,
      p.channel,
      p.avatar_url,
      p.bio,
      p.is_vip,
      p.created_at,
      u.last_sign_in_at,
      u.email_confirmed_at,
      coalesce((SELECT count(*) FROM public.studioos_projects sp WHERE sp.owner_id = p.id), 0) AS studioos_projects_count,
      coalesce((SELECT count(*) FROM public.studioos_history sh WHERE sh.user_id = p.id), 0) AS studioos_history_count,
      coalesce((SELECT count(*) FROM public.studioos_tasks st WHERE st.assignee_id = p.id), 0) AS studioos_tasks_count,
      coalesce((SELECT count(*) FROM public.noesis_sessions ns WHERE ns.user_id = p.id), 0) AS noesis_sessions_count,
      coalesce((SELECT sum(ns.duration_minutes) FROM public.noesis_sessions ns WHERE ns.user_id = p.id), 0) AS noesis_study_minutes,
      coalesce((SELECT count(*) FROM public.noesis_quizzes nq WHERE nq.user_id = p.id), 0) AS noesis_quizzes_count,
      coalesce((SELECT count(*) FROM public.noesis_flashcard_decks nd WHERE nd.user_id = p.id), 0) AS noesis_decks_count,
      coalesce((SELECT count(*) FROM public.noesis_study_notebooks nn WHERE nn.user_id = p.id), 0) AS noesis_notebooks_count,
      coalesce((SELECT count(*) FROM public.noesis_roadmaps nr WHERE nr.user_id = p.id), 0) AS noesis_roadmaps_count,
      coalesce((SELECT sum(nl.amount) FROM public.noesis_insight_ledger nl WHERE nl.user_id = p.id), 0) AS noesis_insights_balance,
      coalesce((p.stats->>'noesis_ranking_elo_index')::int, 0) AS noesis_elo_index,
      (p.stats->>'noesis_weekly_goal_minutes')::int AS noesis_weekly_goal_minutes,
      (p.stats->>'noesis_daily_goal_minutes')::int AS noesis_daily_goal_minutes,
      s.role AS staff_role,
      s.permissions AS staff_permissions,
      s.notes AS staff_notes,
      coalesce((SELECT count(*) FROM public.crm_user_notes un WHERE un.user_id = p.id), 0) AS crm_notes_count,
      coalesce((
        SELECT jsonb_agg(jsonb_build_object(
          'app_id', a.id,
          'app_name', a.name,
          'app_color', a.color,
          'app_prefix', a.table_prefix,
          'status', a.status,
          'first_used_at', ua.first_used_at,
          'last_used_at', ua.last_used_at,
          'use_count', ua.use_count
        ))
        FROM public.crm_user_apps ua
        JOIN public.crm_apps a ON ua.app_id = a.id
        WHERE ua.user_id = p.id
      ), '[]'::jsonb) AS apps_used
    FROM public.profiles p
    LEFT JOIN auth.users u ON p.id = u.id
    LEFT JOIN public.crm_staff s ON p.id = s.id
    ORDER BY p.created_at DESC
  ) t;

  RETURN v_result;
END;
$$;

-- 7. Noesis Platform Overview RPC for NoesisAppView in CRM
CREATE OR REPLACE FUNCTION public.crm_get_noesis_platform_overview()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_config jsonb;
  v_stats jsonb;
  v_groups jsonb;
  v_leaderboard jsonb;
  v_ledger jsonb;
BEGIN
  IF NOT public.crm_is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado: permissão de equipe necessária.';
  END IF;

  SELECT to_jsonb(c.*) INTO v_config
  FROM public.noesis_platform_config c
  WHERE c.id = 'default';

  SELECT jsonb_build_object(
    'total_sessions', (SELECT count(*) FROM public.noesis_sessions),
    'total_minutes', (SELECT coalesce(sum(duration_minutes), 0) FROM public.noesis_sessions),
    'total_quizzes', (SELECT count(*) FROM public.noesis_quizzes),
    'avg_quiz_score', (SELECT round(coalesce(avg(score_percentage), 0)::numeric, 1) FROM public.noesis_quizzes WHERE score_percentage IS NOT NULL),
    'total_decks', (SELECT count(*) FROM public.noesis_flashcard_decks),
    'total_notebooks', (SELECT count(*) FROM public.noesis_study_notebooks),
    'total_roadmaps', (SELECT count(*) FROM public.noesis_roadmaps),
    'total_calendar_events', (SELECT count(*) FROM public.noesis_calendar_events),
    'total_documents', (SELECT count(*) FROM public.noesis_documents),
    'total_groups', (SELECT count(*) FROM public.noesis_study_groups),
    'total_insights_minted', (SELECT coalesce(sum(amount), 0) FROM public.noesis_insight_ledger WHERE amount > 0),
    'total_insights_spent', (SELECT coalesce(abs(sum(amount)), 0) FROM public.noesis_insight_ledger WHERE amount < 0),
    'net_insights_circulation', (SELECT coalesce(sum(amount), 0) FROM public.noesis_insight_ledger),
    'active_learners', (
      SELECT count(DISTINCT uid) FROM (
        SELECT user_id AS uid FROM public.noesis_sessions
        UNION SELECT user_id AS uid FROM public.noesis_quizzes
        UNION SELECT user_id AS uid FROM public.noesis_flashcard_decks
        UNION SELECT user_id AS uid FROM public.noesis_study_notebooks
        UNION SELECT user_id AS uid FROM public.noesis_roadmaps
        UNION SELECT user_id AS uid FROM public.noesis_calendar_events
        UNION SELECT user_id AS uid FROM public.noesis_insight_ledger
        UNION SELECT user_id AS uid FROM public.crm_user_apps WHERE app_id = 'noesis'
      ) u
    )
  ) INTO v_stats;

  SELECT coalesce(jsonb_agg(row_to_json(g)), '[]'::jsonb)
  INTO v_groups
  FROM (
    SELECT
      sg.id,
      sg.leader_id,
      p.full_name AS leader_name,
      p.channel AS leader_channel,
      sg.invite_code,
      sg.payload->>'name' AS name,
      sg.payload->>'description' AS description,
      sg.payload->>'subject' AS subject,
      coalesce(jsonb_array_length(sg.payload->'members'), 0) AS members_count,
      sg.payload,
      sg.created_at,
      sg.updated_at
    FROM public.noesis_study_groups sg
    LEFT JOIN public.profiles p ON p.id = sg.leader_id
    ORDER BY sg.updated_at DESC
    LIMIT 100
  ) g;

  SELECT coalesce(jsonb_agg(row_to_json(lb)), '[]'::jsonb)
  INTO v_leaderboard
  FROM (
    SELECT
      p.id AS user_id,
      p.full_name,
      p.channel,
      p.avatar_url,
      p.is_vip,
      coalesce((p.stats->>'noesis_ranking_elo_index')::int, 0) AS elo_index,
      coalesce((p.stats->>'noesis_ranking_weekly_insights')::int, 0) AS weekly_insights,
      coalesce((p.stats->>'noesis_ranking_weekly_minutes')::int, 0) AS weekly_minutes,
      coalesce((p.stats->>'noesis_ranking_streak_days')::int, 0) AS streak_days,
      coalesce((p.stats->>'noesis_ranking_accumulated_score')::int, 0) AS accumulated_score,
      p.stats->>'noesis_ranking_week_id' AS week_id,
      coalesce((SELECT sum(nl.amount) FROM public.noesis_insight_ledger nl WHERE nl.user_id = p.id), 0) AS insights_balance,
      coalesce((SELECT sum(ns.duration_minutes) FROM public.noesis_sessions ns WHERE ns.user_id = p.id), 0) AS total_study_minutes
    FROM public.profiles p
    ORDER BY
      coalesce((p.stats->>'noesis_ranking_elo_index')::int, 0) DESC,
      coalesce((p.stats->>'noesis_ranking_weekly_insights')::int, 0) DESC,
      total_study_minutes DESC
    LIMIT 100
  ) lb;

  SELECT coalesce(jsonb_agg(row_to_json(tx)), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT
      nl.id,
      nl.user_id,
      p.full_name AS user_name,
      p.channel AS user_channel,
      nl.amount,
      nl.description,
      nl.source,
      nl.reference,
      nl.created_at
    FROM public.noesis_insight_ledger nl
    LEFT JOIN public.profiles p ON p.id = nl.user_id
    ORDER BY nl.created_at DESC
    LIMIT 80
  ) tx;

  RETURN jsonb_build_object(
    'config', v_config,
    'stats', v_stats,
    'study_groups', v_groups,
    'leaderboard', v_leaderboard,
    'recent_ledger', v_ledger
  );
END;
$$;

-- 8. User-specific Noesis data RPC for AccountDetailView
CREATE OR REPLACE FUNCTION public.crm_get_user_noesis_data(target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stats jsonb := '{}'::jsonb;
  v_sessions jsonb := '[]'::jsonb;
  v_calendar jsonb := '[]'::jsonb;
  v_quizzes jsonb := '[]'::jsonb;
  v_documents jsonb := '[]'::jsonb;
  v_decks jsonb := '[]'::jsonb;
  v_notebooks jsonb := '[]'::jsonb;
  v_roadmaps jsonb := '[]'::jsonb;
  v_groups jsonb := '[]'::jsonb;
  v_ledger jsonb := '[]'::jsonb;
  v_summary jsonb := '{}'::jsonb;
BEGIN
  IF NOT public.crm_is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado: permissão de equipe necessária.';
  END IF;

  SELECT coalesce(stats, '{}'::jsonb) INTO v_stats
  FROM public.profiles
  WHERE id = target_user_id;

  SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_sessions
  FROM (SELECT * FROM public.noesis_sessions WHERE user_id = target_user_id ORDER BY study_date DESC, created_at DESC LIMIT 100) t;

  SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_calendar
  FROM (SELECT * FROM public.noesis_calendar_events WHERE user_id = target_user_id ORDER BY start_time DESC LIMIT 100) t;

  SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_quizzes
  FROM (
    SELECT id, title, subject, score_percentage, time_spent_seconds, correct_count, wrong_count, blank_count, difficulty, exam_model_name, topic, completed_at, created_at
    FROM public.noesis_quizzes
    WHERE user_id = target_user_id
    ORDER BY created_at DESC
    LIMIT 60
  ) t;

  SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_documents
  FROM (
    SELECT id, filename, file_path, file_type, summary, created_at
    FROM public.noesis_documents
    WHERE user_id = target_user_id
    ORDER BY created_at DESC
    LIMIT 60
  ) t;

  SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_decks
  FROM (
    SELECT id, title, subject, description, color_hex, jsonb_array_length(coalesce(cards, '[]'::jsonb)) AS cards_count, created_at, updated_at
    FROM public.noesis_flashcard_decks
    WHERE user_id = target_user_id
    ORDER BY updated_at DESC
    LIMIT 60
  ) t;

  SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_notebooks
  FROM (
    SELECT id, title, subject, description, color_hex, jsonb_array_length(coalesce(notes, '[]'::jsonb)) AS notes_count, created_at, updated_at
    FROM public.noesis_study_notebooks
    WHERE user_id = target_user_id
    ORDER BY updated_at DESC
    LIMIT 60
  ) t;

  SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_roadmaps
  FROM (
    SELECT id, title, goal, subject, level, estimated_weeks, jsonb_array_length(coalesce(steps, '[]'::jsonb)) AS steps_count, created_at, updated_at
    FROM public.noesis_roadmaps
    WHERE user_id = target_user_id
    ORDER BY updated_at DESC
    LIMIT 60
  ) t;

  SELECT coalesce(jsonb_agg(row_to_json(g)), '[]'::jsonb) INTO v_groups
  FROM (
    SELECT
      sg.id,
      sg.leader_id,
      sg.invite_code,
      sg.payload->>'name' AS name,
      sg.payload->>'subject' AS subject,
      coalesce(jsonb_array_length(sg.payload->'members'), 0) AS members_count,
      sg.created_at,
      sg.updated_at
    FROM public.noesis_study_groups sg
    WHERE sg.leader_id = target_user_id
       OR public.noesis_is_study_group_member(sg.payload, target_user_id)
    ORDER BY sg.updated_at DESC
    LIMIT 40
  ) g;

  SELECT coalesce(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_ledger
  FROM (
    SELECT * FROM public.noesis_insight_ledger
    WHERE user_id = target_user_id
    ORDER BY created_at DESC
    LIMIT 100
  ) t;

  SELECT jsonb_build_object(
    'total_sessions', (SELECT count(*) FROM public.noesis_sessions WHERE user_id = target_user_id),
    'total_minutes', (SELECT coalesce(sum(duration_minutes), 0) FROM public.noesis_sessions WHERE user_id = target_user_id),
    'total_quizzes', (SELECT count(*) FROM public.noesis_quizzes WHERE user_id = target_user_id),
    'avg_quiz_score', (SELECT round(coalesce(avg(score_percentage), 0)::numeric, 1) FROM public.noesis_quizzes WHERE user_id = target_user_id AND score_percentage IS NOT NULL),
    'total_decks', (SELECT count(*) FROM public.noesis_flashcard_decks WHERE user_id = target_user_id),
    'total_notebooks', (SELECT count(*) FROM public.noesis_study_notebooks WHERE user_id = target_user_id),
    'total_roadmaps', (SELECT count(*) FROM public.noesis_roadmaps WHERE user_id = target_user_id),
    'total_calendar_events', (SELECT count(*) FROM public.noesis_calendar_events WHERE user_id = target_user_id),
    'total_documents', (SELECT count(*) FROM public.noesis_documents WHERE user_id = target_user_id),
    'total_groups', (SELECT count(*) FROM public.noesis_study_groups WHERE leader_id = target_user_id OR public.noesis_is_study_group_member(payload, target_user_id)),
    'insights_balance', (SELECT coalesce(sum(amount), 0) FROM public.noesis_insight_ledger WHERE user_id = target_user_id),
    'elo_index', coalesce((v_stats->>'noesis_ranking_elo_index')::int, 0),
    'weekly_goal_minutes', coalesce((v_stats->>'noesis_weekly_goal_minutes')::int, 600),
    'daily_goal_minutes', coalesce((v_stats->>'noesis_daily_goal_minutes')::int, 90),
    'weekly_insights', coalesce((v_stats->>'noesis_ranking_weekly_insights')::int, 0),
    'streak_days', coalesce((v_stats->>'noesis_ranking_streak_days')::int, 0)
  ) INTO v_summary;

  RETURN jsonb_build_object(
    'stats', coalesce(v_stats, '{}'::jsonb),
    'summary', v_summary,
    'sessions', v_sessions,
    'calendar_events', v_calendar,
    'quizzes', v_quizzes,
    'documents', v_documents,
    'flashcard_decks', v_decks,
    'study_notebooks', v_notebooks,
    'roadmaps', v_roadmaps,
    'study_groups', v_groups,
    'insight_ledger', v_ledger
  );
END;
$$;

-- 9. Update Noesis Platform Config RPC (Super Admin or System Manager)
CREATE OR REPLACE FUNCTION public.crm_update_noesis_platform_config(p_patch jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_can_manage boolean := false;
  v_actor_email text;
  v_actor_name text;
  v_updated public.noesis_platform_config%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  SELECT
    public.crm_is_super_admin(v_uid)
    OR EXISTS (
      SELECT 1 FROM public.crm_staff
      WHERE id = v_uid
        AND is_active = true
        AND coalesce((permissions->>'can_manage_system')::boolean, false) = true
    )
  INTO v_can_manage;

  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Acesso negado: permissão de gestão de sistema necessária.';
  END IF;

  INSERT INTO public.noesis_platform_config (id) VALUES ('default') ON CONFLICT (id) DO NOTHING;

  UPDATE public.noesis_platform_config
  SET
    maintenance_mode = coalesce((p_patch->>'maintenance_mode')::boolean, maintenance_mode),
    maintenance_message = coalesce(p_patch->>'maintenance_message', maintenance_message),
    allow_guest_mode = coalesce((p_patch->>'allow_guest_mode')::boolean, allow_guest_mode),
    allow_registration = coalesce((p_patch->>'allow_registration')::boolean, allow_registration),
    feature_flags = CASE WHEN p_patch ? 'feature_flags' THEN coalesce(feature_flags, '{}'::jsonb) || (p_patch->'feature_flags') ELSE feature_flags END,
    announcement = CASE WHEN p_patch ? 'announcement' THEN coalesce(announcement, '{}'::jsonb) || (p_patch->'announcement') ELSE announcement END,
    version_control = CASE WHEN p_patch ? 'version_control' THEN coalesce(version_control, '{}'::jsonb) || (p_patch->'version_control') ELSE version_control END,
    economy_config = CASE WHEN p_patch ? 'economy_config' THEN coalesce(economy_config, '{}'::jsonb) || (p_patch->'economy_config') ELSE economy_config END,
    ai_governance = CASE WHEN p_patch ? 'ai_governance' THEN coalesce(ai_governance, '{}'::jsonb) || (p_patch->'ai_governance') ELSE ai_governance END,
    updated_at = timezone('utc'::text, now()),
    updated_by = v_uid
  WHERE id = 'default'
  RETURNING * INTO v_updated;

  SELECT email INTO v_actor_email FROM auth.users WHERE id = v_uid;
  SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = v_uid;

  INSERT INTO public.crm_audit_logs (
    actor_id, actor_email, actor_name, action, target_type, target_id, details
  )
  VALUES (
    v_uid,
    v_actor_email,
    v_actor_name,
    'update_noesis_config',
    'app',
    'noesis',
    p_patch
  );

  RETURN jsonb_build_object('success', true, 'config', to_jsonb(v_updated));
END;
$$;

-- 10. Grant or Deduct Insights (✦) for a user from CRM
CREATE OR REPLACE FUNCTION public.crm_grant_noesis_insights(
  target_user_id uuid,
  p_amount integer,
  p_reason text DEFAULT 'Ajuste administrativo CRM'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_allowed boolean := false;
  v_actor_email text;
  v_actor_name text;
  v_tx_id text;
  v_new_balance integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  SELECT
    public.crm_is_super_admin(v_uid)
    OR EXISTS (
      SELECT 1 FROM public.crm_staff
      WHERE id = v_uid AND is_active = true AND role IN ('super_admin', 'moderator', 'admin')
    )
  INTO v_allowed;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Acesso negado: apenas Super Admin ou Moderador podem ajustar Insights.';
  END IF;

  IF p_amount IS NULL OR p_amount = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Informe uma quantidade diferente de zero.');
  END IF;

  v_tx_id := 'crm_adj_' || floor(extract(epoch from now()) * 1000)::bigint::text || '_' || substr(md5(random()::text), 1, 6);

  INSERT INTO public.noesis_insight_ledger (
    id, user_id, amount, description, source, reference, created_at
  )
  VALUES (
    v_tx_id,
    target_user_id,
    p_amount,
    coalesce(nullif(trim(p_reason), ''), 'Ajuste administrativo CRM'),
    'crm_admin',
    'crm_operator:' || v_uid::text,
    timezone('utc'::text, now())
  );

  SELECT coalesce(sum(amount), 0) INTO v_new_balance
  FROM public.noesis_insight_ledger
  WHERE user_id = target_user_id;

  SELECT email INTO v_actor_email FROM auth.users WHERE id = v_uid;
  SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = v_uid;

  INSERT INTO public.crm_audit_logs (
    actor_id, actor_email, actor_name, action, target_type, target_id, details
  )
  VALUES (
    v_uid,
    v_actor_email,
    v_actor_name,
    CASE WHEN p_amount >= 0 THEN 'grant_noesis_insights' ELSE 'deduct_noesis_insights' END,
    'user',
    target_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason, 'tx_id', v_tx_id, 'new_balance', v_new_balance)
  );

  RETURN jsonb_build_object('success', true, 'tx_id', v_tx_id, 'new_balance', v_new_balance);
END;
$$;

-- 11. Update User Noesis Goals & Elo in profiles.stats from CRM
CREATE OR REPLACE FUNCTION public.crm_update_user_noesis_stats(
  target_user_id uuid,
  p_weekly_goal_minutes integer DEFAULT NULL,
  p_daily_goal_minutes integer DEFAULT NULL,
  p_elo_index integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_allowed boolean := false;
  v_actor_email text;
  v_actor_name text;
  v_stats jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  SELECT
    public.crm_is_super_admin(v_uid)
    OR EXISTS (
      SELECT 1 FROM public.crm_staff
      WHERE id = v_uid AND is_active = true AND role IN ('super_admin', 'moderator', 'admin')
    )
  INTO v_allowed;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Acesso negado: apenas Super Admin ou Moderador podem ajustar metas e Elo.';
  END IF;

  SELECT coalesce(stats, '{}'::jsonb) INTO v_stats
  FROM public.profiles
  WHERE id = target_user_id;

  IF v_stats IS NULL THEN
    v_stats := '{}'::jsonb;
  END IF;

  IF p_weekly_goal_minutes IS NOT NULL THEN
    v_stats := jsonb_set(v_stats, '{noesis_weekly_goal_minutes}', to_jsonb(greatest(30, least(p_weekly_goal_minutes, 6000))), true);
  END IF;

  IF p_daily_goal_minutes IS NOT NULL THEN
    v_stats := jsonb_set(v_stats, '{noesis_daily_goal_minutes}', to_jsonb(greatest(10, least(p_daily_goal_minutes, 1440))), true);
  END IF;

  IF p_elo_index IS NOT NULL THEN
    v_stats := jsonb_set(v_stats, '{noesis_ranking_elo_index}', to_jsonb(greatest(0, least(p_elo_index, 7))), true);
  END IF;

  UPDATE public.profiles
  SET stats = v_stats, updated_at = timezone('utc'::text, now())
  WHERE id = target_user_id;

  SELECT email INTO v_actor_email FROM auth.users WHERE id = v_uid;
  SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = v_uid;

  INSERT INTO public.crm_audit_logs (
    actor_id, actor_email, actor_name, action, target_type, target_id, details
  )
  VALUES (
    v_uid,
    v_actor_email,
    v_actor_name,
    'update_noesis_user_stats',
    'user',
    target_user_id::text,
    jsonb_build_object(
      'weekly_goal_minutes', p_weekly_goal_minutes,
      'daily_goal_minutes', p_daily_goal_minutes,
      'elo_index', p_elo_index
    )
  );

  RETURN jsonb_build_object('success', true, 'stats', v_stats);
END;
$$;

-- 12. Moderate / Delete a Noesis record from CRM
CREATE OR REPLACE FUNCTION public.crm_moderate_noesis_record(
  p_table text,
  p_record_id text,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_allowed boolean := false;
  v_actor_email text;
  v_actor_name text;
  v_deleted_count integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  SELECT
    public.crm_is_super_admin(v_uid)
    OR EXISTS (
      SELECT 1 FROM public.crm_staff
      WHERE id = v_uid AND is_active = true AND role IN ('super_admin', 'moderator', 'admin')
    )
  INTO v_allowed;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Acesso negado: apenas Super Admin ou Moderador podem moderar registros.';
  END IF;

  IF p_table = 'noesis_study_groups' THEN
    DELETE FROM public.noesis_study_groups WHERE id = p_record_id;
  ELSIF p_table = 'noesis_sessions' THEN
    DELETE FROM public.noesis_sessions WHERE id::text = p_record_id;
  ELSIF p_table = 'noesis_calendar_events' THEN
    DELETE FROM public.noesis_calendar_events WHERE id::text = p_record_id;
  ELSIF p_table = 'noesis_documents' THEN
    DELETE FROM public.noesis_documents WHERE id::text = p_record_id;
  ELSIF p_table = 'noesis_quizzes' THEN
    DELETE FROM public.noesis_quizzes WHERE id::text = p_record_id;
  ELSIF p_table = 'noesis_roadmaps' THEN
    DELETE FROM public.noesis_roadmaps WHERE id::text = p_record_id;
  ELSIF p_table = 'noesis_flashcard_decks' THEN
    DELETE FROM public.noesis_flashcard_decks WHERE id = p_record_id AND (p_user_id IS NULL OR user_id = p_user_id);
  ELSIF p_table = 'noesis_study_notebooks' THEN
    DELETE FROM public.noesis_study_notebooks WHERE id = p_record_id AND (p_user_id IS NULL OR user_id = p_user_id);
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Tabela não permitida para moderação.');
  END IF;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  SELECT email INTO v_actor_email FROM auth.users WHERE id = v_uid;
  SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = v_uid;

  INSERT INTO public.crm_audit_logs (
    actor_id, actor_email, actor_name, action, target_type, target_id, details
  )
  VALUES (
    v_uid,
    v_actor_email,
    v_actor_name,
    'moderate_noesis_record',
    'data',
    p_record_id,
    jsonb_build_object('table', p_table, 'user_id', p_user_id, 'deleted_count', v_deleted_count)
  );

  RETURN jsonb_build_object('success', true, 'deleted_count', v_deleted_count);
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.crm_get_noesis_platform_overview(),
  public.crm_get_user_noesis_data(uuid),
  public.crm_update_noesis_platform_config(jsonb),
  public.crm_grant_noesis_insights(uuid, integer, text),
  public.crm_update_user_noesis_stats(uuid, integer, integer, integer),
  public.crm_moderate_noesis_record(text, text, uuid)
TO authenticated, service_role;
