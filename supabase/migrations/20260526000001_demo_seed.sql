-- =====================================================================
-- Demo Seed — PactStream Sprint 8
-- =====================================================================
-- Datos de demostración completos:
--   · 3 usuarios demo (Promotor / Constructor / Técnico)
--   · 2 pactos en ejecución con hitos, transiciones y scores
--   · Reputaciones pre-calculadas para Trust Score
--
-- Credenciales:
--   demo.promotor@pactstream.app    → Demo1234!
--   demo.constructor@pactstream.app → Demo1234!
--   demo.tecnico@pactstream.app     → Demo1234!
--
-- Estrategia de idempotencia: DELETE + INSERT limpio.
-- UUIDs fijos y deterministas.
-- =====================================================================

DO $seed$
DECLARE
  -- Auth UIDs (Supabase auth.users.id)
  v_auth_promotor    constant uuid := '00000000-0000-0000-aaaa-000000000001';
  v_auth_constructor constant uuid := '00000000-0000-0000-bbbb-000000000002';
  v_auth_tecnico     constant uuid := '00000000-0000-0000-cccc-000000000003';

  -- Public user IDs (public.users.id)
  v_uid_marta  constant uuid := '00000000-0000-0000-0000-00000000aa01';
  v_uid_perez  constant uuid := '00000000-0000-0000-0000-00000000cc03';
  v_uid_jorge  constant uuid := '00000000-0000-0000-0000-00000000bb02';

  -- Pactos
  v_pact1_id   constant uuid := '00000000-0000-0000-0000-00000000dd01';
  v_pact2_id   constant uuid := '00000000-0000-0000-0000-00000000dd02';

  -- Hitos pacto 1
  v_m1_id  constant uuid := '00000000-0000-0000-0001-000000000001';
  v_m2_id  constant uuid := '00000000-0000-0000-0001-000000000002';
  v_m3_id  constant uuid := '00000000-0000-0000-0001-000000000003';
  v_m4_id  constant uuid := '00000000-0000-0000-0001-000000000004';
  v_m5_id  constant uuid := '00000000-0000-0000-0001-000000000005';

  -- Hitos pacto 2
  v_m6_id  constant uuid := '00000000-0000-0000-0002-000000000001';
  v_m7_id  constant uuid := '00000000-0000-0000-0002-000000000002';
  v_m8_id  constant uuid := '00000000-0000-0000-0002-000000000003';

BEGIN

  -- ============================================================
  -- 0 · LIMPIEZA — borramos en orden FK
  --     La cascada ON DELETE CASCADE se encarga de:
  --       pacts → milestones → milestone_state_transitions
  --       pacts → pact_parties
  --       pacts → pact_health_scores  (si tiene FK con cascade)
  -- ============================================================

  DELETE FROM public.user_reputations   WHERE user_id IN (v_uid_marta, v_uid_perez, v_uid_jorge);
  DELETE FROM public.pact_health_scores WHERE pact_id  IN (v_pact1_id, v_pact2_id);
  DELETE FROM public.pacts              WHERE id        IN (v_pact1_id, v_pact2_id);
  DELETE FROM public.users              WHERE id        IN (v_uid_marta, v_uid_perez, v_uid_jorge);
  DELETE FROM auth.identities           WHERE user_id   IN (v_auth_promotor, v_auth_constructor, v_auth_tecnico);
  DELETE FROM auth.users                WHERE id        IN (v_auth_promotor, v_auth_constructor, v_auth_tecnico);

  -- ============================================================
  -- 1 · USUARIOS AUTH
  -- ============================================================

  INSERT INTO auth.users (
    id, instance_id, aud, role,
    email, encrypted_password,
    email_confirmed_at, confirmation_sent_at,
    created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, is_sso_user, is_anonymous,
    recovery_sent_at,
    -- Campos de token: deben ser '' no NULL para que GoTrue procese el login
    confirmation_token, recovery_token,
    email_change, email_change_token_new, email_change_token_current
  ) VALUES
    (
      v_auth_promotor,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      'demo.promotor@pactstream.app',
      '$2a$10$0EJa2yfcjSRbYVbA2yUWCO8dITueN.cghofHKGWeVupNr91ptZrZe',
      now(), now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Marta García Fernández"}'::jsonb,
      false, false, false, null,
      '', '', '', '', ''
    ),
    (
      v_auth_constructor,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      'demo.constructor@pactstream.app',
      '$2a$10$0EJa2yfcjSRbYVbA2yUWCO8dITueN.cghofHKGWeVupNr91ptZrZe',
      now(), now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Carlos Pérez Rodríguez"}'::jsonb,
      false, false, false, null,
      '', '', '', '', ''
    ),
    (
      v_auth_tecnico,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      'demo.tecnico@pactstream.app',
      '$2a$10$0EJa2yfcjSRbYVbA2yUWCO8dITueN.cghofHKGWeVupNr91ptZrZe',
      now(), now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Jorge Martínez Sánchez"}'::jsonb,
      false, false, false, null,
      '', '', '', '', ''
    );

  INSERT INTO auth.identities (
    id, user_id, provider_id, provider,
    identity_data, last_sign_in_at,
    created_at, updated_at
  ) VALUES
    (
      v_auth_promotor, v_auth_promotor,
      'demo.promotor@pactstream.app', 'email',
      jsonb_build_object('sub', v_auth_promotor::text, 'email', 'demo.promotor@pactstream.app', 'email_verified', true),
      now(), now(), now()
    ),
    (
      v_auth_constructor, v_auth_constructor,
      'demo.constructor@pactstream.app', 'email',
      jsonb_build_object('sub', v_auth_constructor::text, 'email', 'demo.constructor@pactstream.app', 'email_verified', true),
      now(), now(), now()
    ),
    (
      v_auth_tecnico, v_auth_tecnico,
      'demo.tecnico@pactstream.app', 'email',
      jsonb_build_object('sub', v_auth_tecnico::text, 'email', 'demo.tecnico@pactstream.app', 'email_verified', true),
      now(), now(), now()
    );

  -- ============================================================
  -- 2 · PERFILES (public.users)
  -- ============================================================

  INSERT INTO public.users (
    id, auth_provider, auth_provider_id,
    full_name, email, primary_role,
    city, province, country_iso,
    kyc_status, kyc_verified_at,
    created_at, updated_at
  ) VALUES
    (
      v_uid_marta, 'supabase', v_auth_promotor::text,
      'Marta García Fernández', 'demo.promotor@pactstream.app', 'promotor',
      'Madrid', 'Madrid', 'ES',
      'verified', now() - interval '30 days',
      now() - interval '60 days', now()
    ),
    (
      v_uid_perez, 'supabase', v_auth_constructor::text,
      'Carlos Pérez Rodríguez', 'demo.constructor@pactstream.app', 'constructor',
      'Madrid', 'Madrid', 'ES',
      'verified', now() - interval '45 days',
      now() - interval '90 days', now()
    ),
    (
      v_uid_jorge, 'supabase', v_auth_tecnico::text,
      'Jorge Martínez Sánchez', 'demo.tecnico@pactstream.app', 'tecnico',
      'Madrid', 'Madrid', 'ES',
      'verified', now() - interval '120 days',
      now() - interval '150 days', now()
    );

  -- ============================================================
  -- 3 · PACTO 1 — Reforma Integral Calle Mayor 24
  --   85.000 € | in_execution | 2 hitos pagados de 5
  -- ============================================================

  INSERT INTO public.pacts (
    id, display_id, title, description,
    obra_address_line, obra_city, obra_province, obra_type,
    total_amount_cents, iva_rate_pct, iva_included, platform_fee_pct,
    estimated_start_date, estimated_end_date,
    state, state_updated_at, funding_mode,
    deposit_required_pct, deposit_current_cents, budget_consumed_cents,
    model_version, created_by_user_id, created_at, updated_at
  ) VALUES (
    v_pact1_id, 'PS-PCT-260401-0001',
    'Reforma Integral Calle Mayor 24',
    'Reforma integral de vivienda de 120m² incluyendo cocina, baños, instalaciones y acabados.',
    'Calle Mayor 24, 3ºB', 'Madrid', 'Madrid', 'reforma_integral',
    8500000, 10.00, false, 1.00,
    '2026-04-15', '2026-10-15',
    'in_execution', now() - interval '45 days', 'fund_first',
    30.00, 1275000, 3400000,
    'v2', v_uid_marta, now() - interval '60 days', now()
  );

  INSERT INTO public.pact_parties (id, pact_id, user_id, role, invited_at, accepted_at, signed_at, snapshot_full_name, snapshot_email, signature_state)
  VALUES
    (gen_random_uuid(), v_pact1_id, v_uid_marta, 'promotor',    now()-'62 days'::interval, now()-'60 days'::interval, now()-'55 days'::interval, 'Marta García Fernández',  'demo.promotor@pactstream.app',    'signed'),
    (gen_random_uuid(), v_pact1_id, v_uid_perez, 'constructor', now()-'60 days'::interval, now()-'58 days'::interval, now()-'55 days'::interval, 'Carlos Pérez Rodríguez',  'demo.constructor@pactstream.app', 'signed'),
    (gen_random_uuid(), v_pact1_id, v_uid_jorge, 'tecnico',     now()-'60 days'::interval, now()-'59 days'::interval, now()-'55 days'::interval, 'Jorge Martínez Sánchez',  'demo.tecnico@pactstream.app',     'signed');

  INSERT INTO public.milestones (id, pact_id, display_id, ordinal, name, description, amount_cents, target_date, state, state_updated_at, created_at)
  VALUES
    (v_m1_id, v_pact1_id, 'PS-HIT-260401-001', 1, 'Demolición y saneamiento',        'Eliminación de tabiques, solados y falsos techos existentes.',              1200000, '2026-05-01', 'paid',          now()-'35 days'::interval, now()-'55 days'::interval),
    (v_m2_id, v_pact1_id, 'PS-HIT-260401-002', 2, 'Instalación eléctrica y fontanería','Cableado eléctrico BT, cuadro de distribución, tubería de cobre.',          1800000, '2026-06-01', 'paid',          now()-'18 days'::interval, now()-'55 days'::interval),
    (v_m3_id, v_pact1_id, 'PS-HIT-260401-003', 3, 'Tabiquería y albañilería',         'Levantamiento de nuevas divisiones y enlucido de paredes.',                  1700000, '2026-07-01', 'in_validation', now()-'3 days'::interval,  now()-'55 days'::interval),
    (v_m4_id, v_pact1_id, 'PS-HIT-260401-004', 4, 'Alicatado y solado',               'Colocación de pavimento porcelánico y alicatado de cocina y baños.',         2100000, '2026-08-01', 'pending',       now()-'55 days'::interval, now()-'55 days'::interval),
    (v_m5_id, v_pact1_id, 'PS-HIT-260401-005', 5, 'Pintura y carpintería final',      'Pintura plástica en paredes y techos, puertas y armarios.',                  1700000, '2026-09-15', 'pending',       now()-'55 days'::interval, now()-'55 days'::interval);

  INSERT INTO public.milestone_state_transitions (id, milestone_id, from_state, to_state, transitioned_by_user_id, occurred_at)
  VALUES
    ('00000000-0001-0001-0000-000000000001', v_m1_id, 'pending',          'in_execution',     v_uid_perez, now()-'50 days'::interval),
    ('00000000-0001-0001-0000-000000000002', v_m1_id, 'in_execution',     'ready_for_review', v_uid_perez, now()-'42 days'::interval),
    ('00000000-0001-0001-0000-000000000003', v_m1_id, 'ready_for_review', 'in_validation',    v_uid_jorge, now()-'38 days'::interval),
    ('00000000-0001-0001-0000-000000000004', v_m1_id, 'in_validation',    'approved_by_tech', v_uid_jorge, now()-'36 days'::interval),
    ('00000000-0001-0001-0000-000000000005', v_m1_id, 'approved_by_tech', 'awaiting_promotor',v_uid_jorge, now()-'36 days'::interval),
    ('00000000-0001-0001-0000-000000000006', v_m1_id, 'awaiting_promotor','paid',             v_uid_marta, now()-'35 days'::interval),
    ('00000000-0001-0002-0000-000000000001', v_m2_id, 'pending',          'in_execution',     v_uid_perez, now()-'32 days'::interval),
    ('00000000-0001-0002-0000-000000000002', v_m2_id, 'in_execution',     'ready_for_review', v_uid_perez, now()-'25 days'::interval),
    ('00000000-0001-0002-0000-000000000003', v_m2_id, 'ready_for_review', 'in_validation',    v_uid_jorge, now()-'22 days'::interval),
    ('00000000-0001-0002-0000-000000000004', v_m2_id, 'in_validation',    'approved_by_tech', v_uid_jorge, now()-'20 days'::interval),
    ('00000000-0001-0002-0000-000000000005', v_m2_id, 'approved_by_tech', 'awaiting_promotor',v_uid_jorge, now()-'20 days'::interval),
    ('00000000-0001-0002-0000-000000000006', v_m2_id, 'awaiting_promotor','paid',             v_uid_marta, now()-'18 days'::interval),
    ('00000000-0001-0003-0000-000000000001', v_m3_id, 'pending',          'in_execution',     v_uid_perez, now()-'10 days'::interval),
    ('00000000-0001-0003-0000-000000000002', v_m3_id, 'in_execution',     'ready_for_review', v_uid_perez, now()-'5 days'::interval),
    ('00000000-0001-0003-0000-000000000003', v_m3_id, 'ready_for_review', 'in_validation',    v_uid_jorge, now()-'3 days'::interval);

  -- ============================================================
  -- 4 · PACTO 2 — Reforma Baño + Cocina Av. Castellana 100
  --   28.000 € | in_execution | 1 hito pagado de 3
  -- ============================================================

  INSERT INTO public.pacts (
    id, display_id, title, description,
    obra_address_line, obra_city, obra_province, obra_type,
    total_amount_cents, iva_rate_pct, iva_included, platform_fee_pct,
    estimated_start_date, estimated_end_date,
    state, state_updated_at, funding_mode,
    deposit_required_pct, deposit_current_cents, budget_consumed_cents,
    model_version, created_by_user_id, created_at, updated_at
  ) VALUES (
    v_pact2_id, 'PS-PCT-260510-0002',
    'Reforma Baño + Cocina Av. Castellana 100',
    'Reforma completa de baño principal y cocina en vivienda de 85m².',
    'Av. Castellana 100, 8ºA', 'Madrid', 'Madrid', 'reforma_parcial',
    2800000, 21.00, false, 1.00,
    '2026-05-10', '2026-07-30',
    'in_execution', now() - interval '15 days', 'fund_first',
    30.00, 420000, 700000,
    'v2', v_uid_marta, now() - interval '20 days', now()
  );

  INSERT INTO public.pact_parties (id, pact_id, user_id, role, invited_at, accepted_at, signed_at, snapshot_full_name, snapshot_email, signature_state)
  VALUES
    (gen_random_uuid(), v_pact2_id, v_uid_marta, 'promotor',    now()-'22 days'::interval, now()-'20 days'::interval, now()-'16 days'::interval, 'Marta García Fernández', 'demo.promotor@pactstream.app',    'signed'),
    (gen_random_uuid(), v_pact2_id, v_uid_perez, 'constructor', now()-'20 days'::interval, now()-'19 days'::interval, now()-'16 days'::interval, 'Carlos Pérez Rodríguez', 'demo.constructor@pactstream.app', 'signed'),
    (gen_random_uuid(), v_pact2_id, v_uid_jorge, 'tecnico',     now()-'20 days'::interval, now()-'20 days'::interval, now()-'16 days'::interval, 'Jorge Martínez Sánchez', 'demo.tecnico@pactstream.app',     'signed');

  INSERT INTO public.milestones (id, pact_id, display_id, ordinal, name, description, amount_cents, target_date, state, state_updated_at, created_at)
  VALUES
    (v_m6_id, v_pact2_id, 'PS-HIT-260510-001', 1, 'Demolición y vaciado',  'Retirada de azulejos, sanitarios y mueble de cocina existentes.',   700000,  '2026-05-25', 'paid',             now()-'8 days'::interval,  now()-'18 days'::interval),
    (v_m7_id, v_pact2_id, 'PS-HIT-260510-002', 2, 'Alicatado y fontanería','Nuevo alicatado baño, nuevas tuberías y conexión sanitarios.',       1200000, '2026-06-20', 'ready_for_review', now()-'1 day'::interval,   now()-'18 days'::interval),
    (v_m8_id, v_pact2_id, 'PS-HIT-260510-003', 3, 'Acabados y equipamiento','Instalación de sanitarios, mueble de cocina y electrodomésticos.', 900000,  '2026-07-20', 'pending',          now()-'18 days'::interval, now()-'18 days'::interval);

  INSERT INTO public.milestone_state_transitions (id, milestone_id, from_state, to_state, transitioned_by_user_id, occurred_at)
  VALUES
    ('00000000-0002-0006-0000-000000000001', v_m6_id, 'pending',          'in_execution',     v_uid_perez, now()-'15 days'::interval),
    ('00000000-0002-0006-0000-000000000002', v_m6_id, 'in_execution',     'ready_for_review', v_uid_perez, now()-'12 days'::interval),
    ('00000000-0002-0006-0000-000000000003', v_m6_id, 'ready_for_review', 'in_validation',    v_uid_jorge, now()-'11 days'::interval),
    ('00000000-0002-0006-0000-000000000004', v_m6_id, 'in_validation',    'approved_by_tech', v_uid_jorge, now()-'10 days'::interval),
    ('00000000-0002-0006-0000-000000000005', v_m6_id, 'approved_by_tech', 'awaiting_promotor',v_uid_jorge, now()-'10 days'::interval),
    ('00000000-0002-0006-0000-000000000006', v_m6_id, 'awaiting_promotor','paid',             v_uid_marta, now()-'8 days'::interval),
    ('00000000-0002-0007-0000-000000000001', v_m7_id, 'pending',          'in_execution',     v_uid_perez, now()-'7 days'::interval),
    ('00000000-0002-0007-0000-000000000002', v_m7_id, 'in_execution',     'ready_for_review', v_uid_perez, now()-'1 day'::interval);

  -- ============================================================
  -- 5 · PACT HEALTH SCORES
  -- ============================================================

  INSERT INTO public.pact_health_scores (
    pact_id, score,
    milestone_compliance_pct, evidence_validity_pct,
    validation_speed_pct, no_disputes_pct, ia_evidence_score,
    calculated_at
  ) VALUES
    (v_pact1_id, 87, 40.00, 100.00, 100.00, 100.00, 89.00, now() - interval '3 hours'),
    (v_pact2_id, 63, 33.33, 100.00, 100.00, 100.00, 72.00, now() - interval '1 hour');

  -- ============================================================
  -- 6 · USER REPUTATIONS
  -- ============================================================

  INSERT INTO public.user_reputations (
    user_id, role, score, tier,
    components, pacts_total, pacts_completed, pacts_disputed,
    calculated_at
  ) VALUES
    (
      v_uid_marta, 'promotor', 82, 'platino',
      '{"payment_speed_pct": 90, "no_disputes_pct": 100, "completion_pct": 67}'::jsonb,
      3, 2, 0, now() - interval '2 hours'
    ),
    (
      v_uid_perez, 'constructor', 78, 'oro',
      '{"completion_pct": 83, "evidence_quality_pct": 80, "no_disputes_pct": 75}'::jsonb,
      12, 10, 1, now() - interval '2 hours'
    ),
    (
      v_uid_jorge, 'tecnico', 91, 'elite',
      '{"validation_speed_pct": 96, "sign_rate_pct": 100, "no_disputes_pct": 100}'::jsonb,
      8, 7, 0, now() - interval '2 hours'
    );

  RAISE NOTICE '✓ Demo seed completado';
  RAISE NOTICE '  Usuarios: demo.promotor | demo.constructor | demo.tecnico';
  RAISE NOTICE '  Password: Demo1234!';

END $seed$;

NOTIFY pgrst, 'reload schema';
