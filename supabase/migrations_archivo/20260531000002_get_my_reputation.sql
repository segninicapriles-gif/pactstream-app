-- ---------------------------------------------------------------------------
-- get_my_reputation() · Sprint 8 fix
--
-- RPC de conveniencia que no requiere pasar p_user_id.
-- Resuelve internamente el public.users.id del usuario autenticado
-- a partir de auth.uid(), evitando que el cliente tenga que conocer
-- el UUID interno.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_my_reputation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_public_user_id uuid;
BEGIN
  -- Buscar public.users.id usando el auth.uid() de la sesión actual
  SELECT id
    INTO v_public_user_id
    FROM public.users
   WHERE auth_provider_id = auth.uid()::text
     AND deleted_at IS NULL
   LIMIT 1;

  -- Si no existe perfil devolvemos un stub con score 0
  IF v_public_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'user_id',       null,
      'role',          null,
      'score',         0,
      'tier',          'nuevo',
      'components',    '{}'::jsonb,
      'shields_filled', 0,
      'is_stale',      false
    );
  END IF;

  -- Delegar en get_user_reputation con el ID correcto
  RETURN public.get_user_reputation(v_public_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_reputation TO authenticated;

COMMENT ON FUNCTION public.get_my_reputation IS
  'Sprint 8 · Devuelve el último snapshot de reputación del usuario autenticado. '
  'Resuelve internamente public.users.id desde auth.uid(). '
  'Llama a sf_recalc_user_reputation si no existe snapshot todavía.';
