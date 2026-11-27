ALTER TABLE public.noesis_quizzes
  ADD COLUMN IF NOT EXISTS attempt_key text,
  ADD COLUMN IF NOT EXISTS group_key text,
  ADD COLUMN IF NOT EXISTS exam_model_id text,
  ADD COLUMN IF NOT EXISTS exam_model_name text,
  ADD COLUMN IF NOT EXISTS topic text,
  ADD COLUMN IF NOT EXISTS difficulty text,
  ADD COLUMN IF NOT EXISTS target_total_count integer,
  ADD COLUMN IF NOT EXISTS user_answers jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS correct_count integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS wrong_count integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS blank_count integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS time_expired boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS ai_review_markdown text;

CREATE INDEX IF NOT EXISTS idx_noesis_quizzes_user_attempt_key
  ON public.noesis_quizzes (user_id, attempt_key)
  WHERE attempt_key IS NOT NULL;
