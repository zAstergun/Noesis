-- Base schema for Noesis core study tables (deployed on Aster shared Supabase)

CREATE TABLE IF NOT EXISTS public.noesis_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subject text NOT NULL,
    topic text NOT NULL,
    duration_minutes integer NOT NULL CHECK (duration_minutes > 0),
    study_date date NOT NULL DEFAULT current_date,
    notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.noesis_calendar_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    category text DEFAULT 'study',
    color text,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone NOT NULL,
    is_completed boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.noesis_documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    filename text NOT NULL,
    file_path text NOT NULL,
    file_type text NOT NULL,
    extracted_text text,
    summary text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.noesis_quizzes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id uuid REFERENCES public.noesis_documents(id) ON DELETE SET NULL,
    title text NOT NULL,
    subject text NOT NULL,
    questions_data jsonb NOT NULL,
    score_percentage numeric(5,2),
    time_spent_seconds integer,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.noesis_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.noesis_calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.noesis_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.noesis_quizzes ENABLE ROW LEVEL SECURITY;
