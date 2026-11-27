-- Harden noesis_join_study_group_by_code against member privilege/VIP spoofing
-- and protect leader_id / invite_code on noesis_study_groups from non-leader updates.

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
  v_is_vip boolean := false;
  v_allow_invites boolean := false;
  v_allow_edit boolean := false;
  v_safe_member jsonb;
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

  SELECT coalesce(is_vip, false)
    INTO v_is_vip
    FROM public.profiles
   WHERE id = v_uid;

  v_allow_invites := coalesce((v_group.payload ->> 'allow_member_invites')::boolean, false);
  v_allow_edit := coalesce((v_group.payload ->> 'allow_member_edit')::boolean, false);

  v_safe_member := coalesce(p_member, '{}'::jsonb) || jsonb_build_object(
    'user_id', v_uid::text,
    'is_leader', false,
    'can_invite', v_allow_invites,
    'can_edit', v_allow_edit,
    'is_vip', coalesce(v_is_vip, false)
  );

  v_members := COALESCE(v_group.payload -> 'members', '[]'::jsonb) || jsonb_build_array(v_safe_member);
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

REVOKE EXECUTE ON FUNCTION public.noesis_join_study_group_by_code(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.noesis_join_study_group_by_code(text, jsonb) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.noesis_protect_study_group_leader_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.jwt() IS NOT NULL AND coalesce(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    IF auth.uid() IS DISTINCT FROM OLD.leader_id THEN
      IF NEW.leader_id IS DISTINCT FROM OLD.leader_id THEN
        RAISE EXCEPTION 'Apenas o líder pode transferir a liderança do grupo.';
      END IF;
      IF NEW.invite_code IS DISTINCT FROM OLD.invite_code THEN
        RAISE EXCEPTION 'Apenas o líder pode alterar o código de convite.';
      END IF;
      IF (NEW.payload ->> 'leader_id') IS DISTINCT FROM (OLD.payload ->> 'leader_id') THEN
        RAISE EXCEPTION 'Apenas o líder pode alterar o líder no payload do grupo.';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.noesis_protect_study_group_leader_fields() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER trg_noesis_protect_study_group_leader_fields
  BEFORE UPDATE ON public.noesis_study_groups
  FOR EACH ROW
  EXECUTE FUNCTION public.noesis_protect_study_group_leader_fields();
