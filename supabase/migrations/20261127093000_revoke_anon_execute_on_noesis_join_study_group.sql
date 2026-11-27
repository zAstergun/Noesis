REVOKE EXECUTE ON FUNCTION public.noesis_join_study_group_by_code(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.noesis_join_study_group_by_code(text, jsonb) TO authenticated, service_role;
