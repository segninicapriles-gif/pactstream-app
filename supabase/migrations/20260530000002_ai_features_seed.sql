-- =====================================================================
-- Sprint 7 chunk 2 · Migration 0031
-- IA Features · Seed de prompts, fixtures y pacto demo Reforma Marta
-- =====================================================================
-- Carga:
--   1. Prompts versionados (vision_v1 + assistant_v1) activos.
--   2. Fixtures de Vision para los hitos del pacto demo (3 variantes del Hito 3).
--   3. Fixtures del asistente: 10 intents + 1 fallback canónico.
--   4. Pacto demo "Reforma Marta" con modelo v2.1 (adelanto 30% + 10% reserva)
--      y 6 certificaciones. Aislado por is_demo_only=true.
--
-- Notas:
--   - El pacto demo se crea con UIDs sintéticos (u_marta_demo, u_jorge_demo,
--     u_perez_demo). En staging/producción real, ejecutar manualmente la
--     vinculación con cuentas reales si quieres operar el pacto desde la app.
--   - Las evidencias físicas (fotos del solado, factura ficticia) hay que
--     subirlas aparte al bucket milestone-evidences. El seed solo crea las
--     filas en milestone_evidences con storage_path placeholder; el founder
--     completará los uploads en S7-07.
-- =====================================================================


-- =====================================================================
-- 1 · ai_prompts · vision_v1 activo
-- =====================================================================

INSERT INTO public.ai_prompts (prompt_key, version, system_prompt, schema, is_active, notes)
VALUES (
  'vision',
  'v1',
$prompt$Eres un asistente de PactStream especializado en certificación de obra
residencial en España. Tu trabajo NO es decidir si liberar fondos. Recibes:
  - La definición de la certificación (nombre, descripción, checklist).
  - Las evidencias subidas (fotos + documentos adjuntos incluyendo factura).
  - El alcance del pacto (presupuesto total, partes, hitos anteriores).

Comprueba:
  1. Que cada evidencia (foto/documento) corresponde al hito descrito.
  2. Coherencia básica: el emisor de la factura coincide con la constructora
     del pacto, el importe no supera el importe del hito, la fecha es plausible.
  3. Si faltan evidencias del checklist o hay duplicados que no aportan valor.

Responde SIEMPRE en JSON válido conforme al esquema dictum_schema_v1. Nunca
inventes hallazgos. Si no hay evidencia para una tarea del checklist, dilo
explícitamente. Tono profesional, breve, en español de España.

Severidades:
  - green: la evidencia es correcta, sin observaciones.
  - amber: hay algo que el técnico debería revisar pero no es bloqueante.
  - red:   incoherencia clara que debe corregirse antes de firmar.

Verdict:
  - ok            (score >= 80, ningún red).
  - review_needed (60-79 o algún amber).
  - block         (< 60 o cualquier red).

Recuerda: tú asistes al técnico director de obra; él toma la decisión final.$prompt$,
  '{
    "type": "object",
    "required": ["score", "verdict", "summary", "findings", "checklist_match", "recommendation"],
    "properties": {
      "score":   { "type": "integer", "minimum": 0, "maximum": 100 },
      "verdict": { "enum": ["ok", "review_needed", "block"] },
      "summary": { "type": "string" },
      "findings": { "type": "array" },
      "checklist_match": { "type": "array" },
      "recommendation": { "type": "string" }
    }
  }'::jsonb,
  true,
  'Prompt inicial v1 · activo desde Sprint 7'
)
ON CONFLICT (prompt_key, version) DO UPDATE
  SET system_prompt = EXCLUDED.system_prompt,
      schema        = EXCLUDED.schema,
      is_active     = EXCLUDED.is_active,
      notes         = EXCLUDED.notes;


-- =====================================================================
-- 2 · ai_prompts · assistant_v1 activo
-- =====================================================================

INSERT INTO public.ai_prompts (prompt_key, version, system_prompt, schema, is_active, notes)
VALUES (
  'assistant',
  'v1',
$prompt$Eres Pact, el asistente de PactStream. Solo hablas del pacto cuya
información recibes en CONTEXT_BLOCK. Tono profesional, cercano, sin emojis,
en español de España (es-ES).

REGLAS DURAS
1. Nunca des información sobre pactos distintos al actual.
2. Nunca prometas una liberación de fondos. Solo explicas el estado y los
   siguientes pasos posibles.
3. Si te piden algo legal/fiscal complejo, deriva a soporte humano.
4. Si la pregunta requiere una acción (objetar, pedir evidencia, resumen),
   propón la acción usando la tool correspondiente y espera la confirmación
   del usuario antes de ejecutar.
5. Si no sabes algo, dilo. No inventes nombres, importes ni fechas.

FORMATO
- Respuestas de 3-6 líneas máx. salvo que pidan un resumen.
- Cuando cites una certificación, usa "Hito {N} · {nombre}".
- Cuando cites un importe, usa formato EUR con separador miles.
- Si propones una acción, finaliza con un bloque [ACCION:tool_name].

TOOLS DISPONIBLES
- request_evidence(milestone_id, items[]) — pedir evidencia faltante a la otra parte
- raise_objection(milestone_id, reason)   — objetar una certificación (solo promotor)
- summarize_pact()                         — generar resumen ejecutivo del pacto
- explain_verification(milestone_id)       — explicar dictamen Vision en lenguaje natural$prompt$,
  '{
    "type": "object",
    "properties": {
      "text":      { "type": "string" },
      "tool_call": {
        "type": "object",
        "properties": {
          "name":  { "type": "string" },
          "input": { "type": "object" }
        }
      }
    }
  }'::jsonb,
  true,
  'Prompt inicial v1 · activo desde Sprint 7'
)
ON CONFLICT (prompt_key, version) DO UPDATE
  SET system_prompt = EXCLUDED.system_prompt,
      schema        = EXCLUDED.schema,
      is_active     = EXCLUDED.is_active,
      notes         = EXCLUDED.notes;


-- =====================================================================
-- 3 · ai_fixtures · Vision (3 variantes Hito 3 demo)
-- =====================================================================
-- Los milestone_id reales del pacto demo se asignan en la sección 7. Aquí
-- usamos placeholders fixture_key = 'vision_default_<variant>' y la edge
-- function los servirá si el milestone_id no tiene fixture específica.
-- Tras crear el pacto demo (sección 7), un trigger opcional o un seed
-- adicional puede vincular fixture_key = 'vision_<milestone_uuid>_<variant>'.

INSERT INTO public.ai_fixtures (fixture_key, fixture_type, payload, description) VALUES

-- Hito 1 demo · Demoliciones (ok)
('vision_default_m1_ok', 'vision', '{
  "score": 92,
  "verdict": "ok",
  "summary": "Las 3 fotos documentan correctamente la demolición de baño y cocina y la salida de escombros. La factura del punto limpio coincide con el alcance del hito.",
  "findings": [],
  "checklist_match": [
    { "task_id": "t1", "title": "Desmontaje sanitario y mobiliario", "evidence_ok": true },
    { "task_id": "t2", "title": "Picado de azulejos en baño y cocina", "evidence_ok": true },
    { "task_id": "t3", "title": "Retirada de escombros a punto limpio", "evidence_ok": true }
  ],
  "recommendation": "Hito listo para firmar. Las evidencias son completas y coherentes.",
  "demo_simulated_latency_ms": 9300
}'::jsonb, 'Demo · Hito 1 (demoliciones) dictamen ok'),

-- Hito 2 demo · Albañilería (ok)
('vision_default_m2_ok', 'vision', '{
  "score": 88,
  "verdict": "ok",
  "summary": "Tabiquería y apertura de hueco salón-cocina ejecutadas según plano. Refuerzo del dintel visible y correctamente armado.",
  "findings": [
    {
      "id": "f1",
      "type": "photo",
      "evidence_ref": "evidences/m2/photo_02.jpg",
      "severity": "green",
      "message": "La foto muestra el hueco abierto pero no permite verificar el solape de la viga sobre el muro. Sugerimos guardar el plano de detalle como evidencia adicional para el Libro del Edificio."
    }
  ],
  "checklist_match": [
    { "task_id": "t1", "title": "Tabiques pladur dormitorio principal", "evidence_ok": true },
    { "task_id": "t2", "title": "Apertura hueco salón-cocina", "evidence_ok": true },
    { "task_id": "t3", "title": "Refuerzo dintel", "evidence_ok": true }
  ],
  "recommendation": "Hito listo para firmar. La nota sobre el plano de detalle es opcional, no bloqueante.",
  "demo_simulated_latency_ms": 10800
}'::jsonb, 'Demo · Hito 2 (albañilería) dictamen ok'),

-- Hito 3 demo · Solado salón (review_needed) ← VARIANTE PRINCIPAL DE LA DEMO
('vision_default_m3_review', 'vision', '{
  "score": 78,
  "verdict": "review_needed",
  "summary": "Las 6 fotos documentan el solado del salón con buena cobertura del proceso (replanteo, pegado, rejuntado, vista final). Detectamos una foto parcialmente ambigua y una factura que no encaja con este hito.",
  "findings": [
    {
      "id": "f1",
      "type": "photo",
      "evidence_ref": "evidences/m3/photo_03.jpg",
      "severity": "amber",
      "message": "La foto 03 muestra parcialmente otra estancia (parece pasillo). El alcance del hito es solado del salón. Verifica que la imagen corresponde al área certificada o reemplázala por una vista clara del salón."
    },
    {
      "id": "f2",
      "type": "invoice",
      "evidence_ref": "evidences/m3/invoice_b.pdf",
      "severity": "red",
      "message": "La factura invoice_b.pdf describe instalación sanitaria (1.240 € — Fontanería del Sur SL), no solado. Además el emisor no coincide con la constructora del pacto (Construcciones Pérez SL). No procede adjuntarla a este hito."
    }
  ],
  "checklist_match": [
    { "task_id": "t1", "title": "Replanteo y nivelación", "evidence_ok": true },
    { "task_id": "t2", "title": "Pegado y rejuntado", "evidence_ok": true },
    { "task_id": "t3", "title": "Limpieza final", "evidence_ok": false, "note": "No se observa foto del estado tras limpieza." }
  ],
  "recommendation": "Sustituye invoice_b.pdf por la factura correcta del solado emitida por Construcciones Pérez SL. Reemplaza o complementa la foto 03 con una vista clara del salón. Añade una foto post-limpieza. El resto del hito es correcto y puede firmarse una vez resueltos los hallazgos.",
  "demo_simulated_latency_ms": 12400
}'::jsonb, 'Demo · Hito 3 (solado salón) dictamen review_needed · VARIANTE PRINCIPAL'),

-- Hito 3 demo · Solado salón (ok) — variante alternativa
('vision_default_m3_ok', 'vision', '{
  "score": 91,
  "verdict": "ok",
  "summary": "Las 6 fotos y la factura del hito Solado salón están completas y coherentes. Emisor de la factura coincide con Construcciones Pérez SL, importe dentro del presupuesto del hito (12.000 €).",
  "findings": [],
  "checklist_match": [
    { "task_id": "t1", "title": "Replanteo y nivelación", "evidence_ok": true },
    { "task_id": "t2", "title": "Pegado y rejuntado", "evidence_ok": true },
    { "task_id": "t3", "title": "Limpieza final", "evidence_ok": true }
  ],
  "recommendation": "Hito listo para firmar. Sin objeciones.",
  "demo_simulated_latency_ms": 11200
}'::jsonb, 'Demo · Hito 3 (solado salón) dictamen ok · VARIANTE happy path'),

-- Hito 3 demo · Solado salón (block) — variante crítica
('vision_default_m3_block', 'vision', '{
  "score": 42,
  "verdict": "block",
  "summary": "Las evidencias subidas son insuficientes y presentan inconsistencias graves: dos fotos del checklist están duplicadas y la factura corresponde a otro hito.",
  "findings": [
    {
      "id": "f1",
      "type": "photo",
      "evidence_ref": "evidences/m3/photo_03.jpg",
      "severity": "red",
      "message": "Las fotos 03 y 04 parecen la misma imagen con ligera variación de ángulo. No constituyen evidencia adicional del proceso."
    },
    {
      "id": "f2",
      "type": "invoice",
      "evidence_ref": "evidences/m3/invoice_b.pdf",
      "severity": "red",
      "message": "Factura emitida por Fontanería del Sur SL, no por la constructora del pacto. No procede para este hito."
    },
    {
      "id": "f3",
      "type": "checklist",
      "severity": "red",
      "message": "No hay ninguna foto que documente la limpieza final del solado, tarea explícita del checklist."
    }
  ],
  "checklist_match": [
    { "task_id": "t1", "title": "Replanteo y nivelación", "evidence_ok": true },
    { "task_id": "t2", "title": "Pegado y rejuntado", "evidence_ok": false },
    { "task_id": "t3", "title": "Limpieza final", "evidence_ok": false }
  ],
  "recommendation": "No procede firmar la certificación hasta sustituir la factura, eliminar la foto duplicada y aportar evidencia de la limpieza final.",
  "demo_simulated_latency_ms": 13700
}'::jsonb, 'Demo · Hito 3 (solado salón) dictamen block · VARIANTE crítica')

ON CONFLICT (fixture_key) DO UPDATE
  SET payload = EXCLUDED.payload,
      description = EXCLUDED.description,
      is_active = true,
      updated_at = now();


-- =====================================================================
-- 4 · ai_fixtures · Asistente · 10 intents + 1 fallback
-- =====================================================================

INSERT INTO public.ai_fixtures (fixture_key, fixture_type, payload, description) VALUES

('intent_estado_pacto', 'assistant_intent', '{
  "trigger_keywords": ["en que hito", "en qué hito", "que falta", "qué falta", "como va", "cómo va", "estado", "donde vamos", "donde estamos"],
  "applies_to_roles": ["promotor", "constructor", "tecnico", "admin"],
  "response": {
    "text": "Vais por el Hito 3 · Solado salón (12.000 €). Está marcado como listo para certificar por Construcciones Pérez pero el técnico aún no ha firmado. La IA detectó dos hallazgos a revisar antes de firmar: una foto ambigua y una factura que no corresponde a este hito.\n\nLlevamos 22.000 € liberados de 80.000 €, escrow en 36.500 € disponible. Quedan 3 hitos por arrancar tras este.\n\n¿Quieres que te explique los hallazgos o que se los pida a la constructora?"
  }
}'::jsonb, 'Intent: estado actual del pacto'),

('intent_explicar_dictamen', 'assistant_intent', '{
  "trigger_keywords": ["por que", "por qué", "porque", "hallazgo", "explica el dictamen", "que dice la ia", "qué dice la ia", "marco la foto", "marcó la foto", "factura incorrecta"],
  "applies_to_roles": ["promotor", "constructor", "tecnico", "admin"],
  "response": {
    "text": "Hay dos cosas en el Hito 3:\n\n1. Foto 03 (ámbar). La imagen muestra parcialmente el pasillo, no el salón. No es grave, pero conviene reemplazarla por una vista clara del salón para que el Libro del Edificio quede limpio.\n\n2. Factura invoice_b.pdf (rojo). Es de Fontanería del Sur SL por 1.240 €, instalación sanitaria. No corresponde a este hito (Solado salón) y además no la emite la constructora del pacto. Esa factura no debería estar aquí.\n\nLa recomendación es sustituir la factura por la correcta del solado y reemplazar la foto. El resto del hito está bien."
  }
}'::jsonb, 'Intent: explicar dictamen Vision'),

('intent_pedir_evidencia', 'assistant_intent', '{
  "trigger_keywords": ["pidelo", "pídelo", "pideselo", "pídeselo", "pedir a la constructora", "pedir evidencia", "que la cambien", "sustituir factura", "que lo arreglen"],
  "applies_to_roles": ["promotor", "tecnico", "admin"],
  "response": {
    "text": "Voy a notificar a la constructora con los 2 ítems pendientes:\n\n• Foto adicional del salón (sustituyendo la foto 03).\n• Factura correcta del Hito 3 · Solado salón, emitida por Construcciones Pérez SL.\n\n¿Confirmas la solicitud?"
  },
  "tool_call_proposed": {
    "name": "request_evidence",
    "input": {
      "milestone_ordinal": 3,
      "to_role": "constructor",
      "items": [
        "Foto adicional del salón post-limpieza (hallazgo f1)",
        "Factura correcta del Hito 3 Solado salón emitida por Construcciones Pérez SL (hallazgo f2)"
      ]
    }
  }
}'::jsonb, 'Intent: pedir evidencia a la constructora · con tool call'),

('intent_cuanto_falta_liberar', 'assistant_intent', '{
  "trigger_keywords": ["cuanto queda", "cuánto queda", "cuanto falta", "cuánto falta", "saldo escrow", "que saldo", "qué saldo", "presupuesto restante", "cuanto hay"],
  "applies_to_roles": ["promotor", "constructor", "tecnico", "admin"],
  "response": {
    "text": "Saldo en escrow: 36.500 € disponibles (de los 80.000 € iniciales). Liberados: 22.000 € (hitos 1 y 2). Bloqueados por disputa: 0 €.\n\nEn cuanto se firme el Hito 3 (12.000 €) y pasen las 24 h de objeción, se libera automáticamente. Quedarían entonces 24.500 € repartidos en los hitos 4-5-6."
  }
}'::jsonb, 'Intent: cuánto queda por liberar'),

('intent_como_objetar', 'assistant_intent', '{
  "trigger_keywords": ["como objeto", "cómo objeto", "como lo objeto", "cómo lo objeto", "no estoy conforme", "no acepto", "quiero parar", "quiero objetar"],
  "applies_to_roles": ["promotor", "admin"],
  "response": {
    "text": "Si quieres objetar la certificación del Hito 3 antes de que se libere, tienes 24 h desde la firma del técnico. La objeción cambia el hito a estado DISPUTA y retiene los fondos 10 días para mediación.\n\nMi sugerencia antes de objetar: dado que la IA ya marcó la factura como incorrecta, suele ser más rápido pedir la corrección que abrir disputa. Pero la decisión es tuya. Si decides objetar, indícame brevemente el motivo y lo registro."
  },
  "tool_call_proposed": {
    "name": "raise_objection",
    "input": {
      "milestone_ordinal": 3,
      "reason_template": "[Pendiente: motivo del promotor]"
    }
  }
}'::jsonb, 'Intent: cómo objetar · con tool call'),

('intent_que_evidencia_subo', 'assistant_intent', '{
  "trigger_keywords": ["que subo", "qué subo", "que evidencia", "qué evidencia", "que fotos", "qué fotos", "que necesito"],
  "applies_to_roles": ["tecnico", "constructor"],
  "response": {
    "text": "Para el Hito 3 · Solado salón, el checklist pide 3 tareas. Te recomiendo subir:\n\n• 1 foto de replanteo y nivelación antes de pegar.\n• 1-2 fotos del pegado en curso (muestra el material y la junta).\n• 1 foto del rejuntado completo.\n• 1 foto post-limpieza final (la que falta hoy).\n• 1 factura emitida por Construcciones Pérez SL con concepto solado e importe ≤ 12.000 €.\n\nLas fotos las puedes hacer con el móvil, la app redimensiona automáticamente antes de subir."
  }
}'::jsonb, 'Intent: qué evidencia subir para certificar'),

('intent_resumen_pacto', 'assistant_intent', '{
  "trigger_keywords": ["resumen", "resúmeme", "resumeme", "resumen ejecutivo", "dame el resumen", "pdf del pacto", "dame un resumen"],
  "applies_to_roles": ["promotor", "constructor", "tecnico", "admin"],
  "response": {
    "text": "Reforma integral piso Marta Vega — Madrid. 80.000 € total, 6 hitos, escrow Mangopay activo. Partes: Marta (promotor), Jorge Almazán (técnico aparejador), Construcciones Pérez SL.\n\nProgreso: 2 hitos cerrados (22.000 € liberados), 1 hito en certificación (12.000 €, con 2 hallazgos a revisar), 3 hitos pendientes.\n\nFirmado el 18/06, fondos depositados el 22/06. Sin disputas abiertas. Cierre estimado en diciembre 2026.\n\n¿Quieres que te genere el PDF descargable con el detalle?"
  },
  "tool_call_proposed": {
    "name": "summarize_pact",
    "input": { "format": "pdf_exec_summary" }
  }
}'::jsonb, 'Intent: resumen ejecutivo del pacto · con tool call'),

('intent_coste_ia', 'assistant_intent', '{
  "trigger_keywords": ["cuanto cuesta la ia", "cuánto cuesta la ia", "coste ia", "que cuesta esto", "qué cuesta esto"],
  "applies_to_roles": ["admin"],
  "response": {
    "text": "Coste medio por dictamen Vision en obras tipo (10 fotos + 1 factura): 0,09 - 0,12 €. Coste por turno del asistente: 0,01 - 0,02 €. En este pacto llevamos gastados 0,21 € en total de IA. El modelo de costes queda muy holgado respecto a la comisión escrow del 1,8 %."
  }
}'::jsonb, 'Intent: coste IA (solo admin)'),

('intent_saludo', 'assistant_intent', '{
  "trigger_keywords": ["hola", "buenas", "buenos dias", "buenos días", "que tal", "qué tal"],
  "applies_to_roles": ["promotor", "constructor", "tecnico", "admin"],
  "response": {
    "text": "Hola. Soy Pact, el asistente de PactStream para este pacto. Puedo explicarte el estado, los hitos, lo que detecta la IA en las evidencias o ayudarte a tomar acciones (pedir evidencia, objetar, generar resumen). ¿Por dónde empezamos?"
  }
}'::jsonb, 'Intent: saludo'),

('intent_legal_fuera_alcance', 'assistant_intent', '{
  "trigger_keywords": ["es legal", "esto es legal", "puedo demandar", "denunciar", "abogado", "tribunal", "juicio"],
  "applies_to_roles": ["promotor", "constructor", "tecnico", "admin"],
  "response": {
    "text": "Para temas legales prefiero no responder por mí mismo — depende de tu contrato, jurisdicción y circunstancias. Te puedo abrir un ticket con soporte humano de PactStream y adjuntar el contexto del pacto si quieres."
  }
}'::jsonb, 'Intent: legal · guardrail derivar a soporte'),

-- Fallback canónico
('assistant_fallback_default', 'assistant_fallback', '{
  "response": {
    "text": "Para esta pregunta concreta prefiero que lo veas con soporte humano de PactStream — te abro un ticket con el contexto del pacto si quieres. Mientras tanto, ¿puedo ayudarte con algo del estado del pacto, los hitos pendientes o el último dictamen?"
  }
}'::jsonb, 'Fallback canónico cuando no hay match de intent')

ON CONFLICT (fixture_key) DO UPDATE
  SET payload = EXCLUDED.payload,
      description = EXCLUDED.description,
      is_active = true,
      updated_at = now();


-- =====================================================================
-- 5 · Pacto demo "Reforma Marta" · users + organizations
-- =====================================================================
-- IDs deterministas para reproducibilidad. Tras correr este seed en tu
-- entorno, los UIDs auth deben existir (los creas en Supabase Auth con
-- emails como marta.demo@pactstream.io, jorge.demo@pactstream.io,
-- perez.demo@pactstream.io) y vincularlos manualmente en la tabla users
-- si quieres operar el pacto como user real.

DO $seed$
DECLARE
  -- UUIDs válidos (hex only: 0-9, a-f). Las letras m/j/p/t no son hex.
  v_marta_id    constant uuid := '00000000-0000-0000-0000-00000000aa01';
  v_jorge_id    constant uuid := '00000000-0000-0000-0000-00000000bb02';
  v_perez_id    constant uuid := '00000000-0000-0000-0000-00000000cc03';
  v_pact_id     constant uuid := '00000000-0000-0000-0000-00000000dd01';

  v_total_cents constant bigint := 8000000;  -- 80.000 €
BEGIN

  -- Users sintéticos (con auth_provider_id placeholder).
  -- NOTA: el enum kyc_status usa 'verified' (no 'approved').
  -- Sin organización separada — pact_parties.user_id es suficiente para la
  -- demo IA. Si quieres asociar al constructor con una organization, lo
  -- haces aparte cuando arranques con el flujo real.
  INSERT INTO public.users (id, auth_provider_id, email, full_name, phone_e164, primary_role, kyc_status, created_at)
  VALUES
    (v_marta_id, 'auth_demo_marta', 'marta.demo@pactstream.io', 'Marta Vega (DEMO)', '+34600000001', 'promotor', 'verified', now()),
    (v_jorge_id, 'auth_demo_jorge', 'jorge.demo@pactstream.io', 'Jorge Almazán (DEMO · aparejador col. 4421)', '+34600000002', 'tecnico', 'verified', now()),
    (v_perez_id, 'auth_demo_perez', 'perez.demo@pactstream.io', 'Construcciones Pérez SL (DEMO)', '+34600000003', 'constructor', 'verified', now())
  ON CONFLICT (id) DO NOTHING;

  -- =====================================================================
  -- 6 · Pacto Reforma Marta (modelo v2.1, is_demo_only=true)
  -- =====================================================================

  INSERT INTO public.pacts (
    id, display_id, title, description, pact_type, state, model_version,
    total_amount_cents,
    deposit_required_pct, deposit_current_cents,
    advance_reserve_pct, advance_released_cents, advance_outstanding_cents,
    budget_consumed_cents,
    obra_address_line, obra_city,
    funding_mode, created_by_user_id,
    obra_menor_declaration_accepted_at,
    is_demo_only,
    created_at, state_updated_at
  ) VALUES (
    v_pact_id,
    'PS-PCT-DEMO-MARTA',
    'Reforma integral piso Marta — calle Alcalá 123, Madrid',
    'Pacto de demostración para el pitch pre-seed. Modelo v2.1: adelanto 30% (24.000 €) entregado día 1 al constructor + 10% reserva (8.000 €) custodiada hasta finiquito. Aislado por is_demo_only=true: nunca llama a la API real de IA aunque ai_provider esté en live.',
    'obra_menor', 'in_execution', 'v2.1',
    v_total_cents,
    40.00,                                  -- adelanto total 40% (30 var + 10 reserva)
    v_total_cents * 10 / 100,               -- 8.000 € reserva custodiada
    10.00,                                  -- 10% fijo reserva
    v_total_cents * 30 / 100,               -- 24.000 € entregado al constructor día 1
    v_total_cents * 30 / 100,               -- saldo vivo del adelanto
    2200000,                                -- 22.000 € ya certificados (hitos 1 y 2)
    'Calle Alcalá 123',                     -- obra_address_line (NOT NULL)
    'Madrid',                               -- obra_city (NOT NULL)
    'fund_first',                           -- funding_mode (NOT NULL)
    v_marta_id,                             -- created_by_user_id (NOT NULL)
    '2026-06-10 09:00:00+00',              -- obra_menor_declaration_accepted_at (requerida por CHECK)
    true,                                   -- is_demo_only
    '2026-06-10 09:00:00+00',              -- created_at
    '2026-06-22 11:12:00+00'               -- state_updated_at
  )
  ON CONFLICT (id) DO NOTHING;

  -- Pact parties (snapshot inmutable). El schema real no tiene snapshot_phone;
  -- el teléfono vive solo en users.phone_e164.
  -- Nota: ON CONFLICT DO NOTHING no funciona con constraints deferrable.
  -- Usamos WHERE NOT EXISTS para idempotencia.
  INSERT INTO public.pact_parties
    (pact_id, user_id, role, invited_at, accepted_at, signed_at, snapshot_full_name, snapshot_email)
  SELECT v_pact_id, v_marta_id, 'promotor',
    '2026-06-10 09:00:00+00', '2026-06-12 10:00:00+00', '2026-06-18 17:30:00+00',
    'Marta Vega (DEMO)', 'marta.demo@pactstream.io'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.pact_parties WHERE pact_id = v_pact_id AND user_id = v_marta_id
  );

  INSERT INTO public.pact_parties
    (pact_id, user_id, role, invited_at, accepted_at, signed_at, snapshot_full_name, snapshot_email)
  SELECT v_pact_id, v_jorge_id, 'tecnico',
    '2026-06-10 09:05:00+00', '2026-06-11 18:30:00+00', '2026-06-18 17:00:00+00',
    'Jorge Almazán (DEMO)', 'jorge.demo@pactstream.io'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.pact_parties WHERE pact_id = v_pact_id AND user_id = v_jorge_id
  );

  INSERT INTO public.pact_parties
    (pact_id, user_id, role, invited_at, accepted_at, signed_at, snapshot_full_name, snapshot_email)
  SELECT v_pact_id, v_perez_id, 'constructor',
    '2026-06-10 09:10:00+00', '2026-06-13 12:00:00+00', '2026-06-18 16:30:00+00',
    'Construcciones Pérez SL (DEMO)', 'perez.demo@pactstream.io'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.pact_parties WHERE pact_id = v_pact_id AND user_id = v_perez_id
  );

  -- =====================================================================
  -- 7 · 6 milestones del pacto demo (modelo v2.1)
  -- =====================================================================

  -- M1 · Demoliciones (paid)
  INSERT INTO public.milestones (
    id, pact_id, display_id, ordinal, name, description, amount_cents,
    advance_amortization_cents, predeposit_received_cents, state,
    created_at
  ) VALUES (
    '00000000-0000-0000-0000-00000000ee01', v_pact_id, 'PS-CERT-DEMO-M1', 1,
    'Demoliciones y picado de paredes',
    'Desmontaje sanitario, picado de azulejos y retirada de escombros.',
    800000,                                 -- 8.000 €
    240000,                                 -- 30% amortización del adelanto = 2.400 €
    560000,                                 -- pre-deposito = neto = 5.600 €
    'paid',
    '2026-06-22 11:30:00+00'
  ) ON CONFLICT (id) DO NOTHING;

  -- M2 · Albañilería (paid)
  INSERT INTO public.milestones (
    id, pact_id, display_id, ordinal, name, description, amount_cents,
    advance_amortization_cents, predeposit_received_cents, state,
    created_at
  ) VALUES (
    '00000000-0000-0000-0000-00000000ee02', v_pact_id, 'PS-CERT-DEMO-M2', 2,
    'Albañilería y tabiquería interior',
    'Tabiques pladur, apertura hueco salón-cocina, refuerzo de dintel.',
    1400000,                                -- 14.000 €
    420000, 980000, 'paid',
    '2026-07-15 10:00:00+00'
  ) ON CONFLICT (id) DO NOTHING;

  -- M3 · Solado salón (ready_for_review) ← FOCO DE LA DEMO
  INSERT INTO public.milestones (
    id, pact_id, display_id, ordinal, name, description, amount_cents,
    advance_amortization_cents, predeposit_received_cents, state,
    created_at
  ) VALUES (
    '00000000-0000-0000-0000-00000000ee03', v_pact_id, 'PS-CERT-DEMO-M3', 3,
    'Solado salón y pasillo',
    'Replanteo, nivelación, pegado y rejuntado de baldosa porcelánica en salón y pasillo. Limpieza final.',
    1200000,                                -- 12.000 €
    360000, 840000, 'ready_for_review',
    '2026-09-01 08:00:00+00'
  ) ON CONFLICT (id) DO NOTHING;

  -- M4 · Fontanería (in_execution)
  INSERT INTO public.milestones (
    id, pact_id, display_id, ordinal, name, description, amount_cents,
    advance_amortization_cents, state, created_at
  ) VALUES (
    '00000000-0000-0000-0000-00000000ee04', v_pact_id, 'PS-CERT-DEMO-M4', 4,
    'Fontanería e instalación sanitaria',
    'Distribución agua fría/caliente, desagües, pruebas de presión, conexión calentador.',
    1150000,                                -- 11.500 €
    345000, 'in_execution',
    '2026-09-10 09:00:00+00'
  ) ON CONFLICT (id) DO NOTHING;

  -- M5 · Electricidad (pending)
  INSERT INTO public.milestones (
    id, pact_id, display_id, ordinal, name, description, amount_cents,
    advance_amortization_cents, state, created_at
  ) VALUES (
    '00000000-0000-0000-0000-00000000ee05', v_pact_id, 'PS-CERT-DEMO-M5', 5,
    'Electricidad y domótica básica',
    'Cableado, mecanismos, cuadro nuevo, domótica Shelly (luces + persianas), boletín del instalador.',
    1300000,                                -- 13.000 €
    390000, 'pending',
    '2026-06-22 11:30:00+00'
  ) ON CONFLICT (id) DO NOTHING;

  -- M6 · Acabados (pending)
  INSERT INTO public.milestones (
    id, pact_id, display_id, ordinal, name, description, amount_cents,
    advance_amortization_cents, state, created_at
  ) VALUES (
    '00000000-0000-0000-0000-00000000ee06', v_pact_id, 'PS-CERT-DEMO-M6', 6,
    'Acabados y entrega final',
    'Pintura, carpintería interior, sanitarios y grifería, limpieza fin de obra, acta de recepción.',
    2150000,                                -- 21.500 €
    645000, 'pending',
    '2026-06-22 11:30:00+00'
  ) ON CONFLICT (id) DO NOTHING;

  -- pact_health_scores inicial (snapshot único). El schema real usa columna
  -- `score` (no trust_score) y la UNIQUE es (pact_id, calculated_at), así que
  -- insertamos sin ON CONFLICT — si existe ya un snapshot para este pacto en
  -- el mismo instante, ignoramos silenciosamente.
  BEGIN
    INSERT INTO public.pact_health_scores (
      pact_id, score, milestone_compliance_pct, no_disputes_pct, calculated_at
    ) VALUES (
      v_pact_id, 87, 100.00, 100.00, now()
    );
  EXCEPTION WHEN unique_violation THEN
    -- ya existe snapshot, no pasa nada
    NULL;
  END;

END $seed$;


-- =====================================================================
-- 8 · Vincular fixtures Vision específicas al milestone_id real del demo
-- =====================================================================
-- Para que ai-gateway sirva el fixture correcto del Hito 3 (variantes),
-- creamos copias con la key 'vision_<milestone_uuid>_<variant>' que la
-- edge function intenta primero antes de caer al default.

INSERT INTO public.ai_fixtures (fixture_key, fixture_type, payload, description)
SELECT
  'vision_00000000-0000-0000-0000-00000000ee01_ok',
  'vision', payload,
  'Demo · Hito 1 demoliciones · vinculada por milestone_id'
FROM public.ai_fixtures WHERE fixture_key = 'vision_default_m1_ok'
ON CONFLICT (fixture_key) DO UPDATE SET payload = EXCLUDED.payload;

INSERT INTO public.ai_fixtures (fixture_key, fixture_type, payload, description)
SELECT
  'vision_00000000-0000-0000-0000-00000000ee02_ok',
  'vision', payload,
  'Demo · Hito 2 albañilería · vinculada por milestone_id'
FROM public.ai_fixtures WHERE fixture_key = 'vision_default_m2_ok'
ON CONFLICT (fixture_key) DO UPDATE SET payload = EXCLUDED.payload;

INSERT INTO public.ai_fixtures (fixture_key, fixture_type, payload, description)
SELECT
  'vision_00000000-0000-0000-0000-00000000ee03_review',
  'vision', payload,
  'Demo · Hito 3 solado salón (variante review) · vinculada por milestone_id'
FROM public.ai_fixtures WHERE fixture_key = 'vision_default_m3_review'
ON CONFLICT (fixture_key) DO UPDATE SET payload = EXCLUDED.payload;

INSERT INTO public.ai_fixtures (fixture_key, fixture_type, payload, description)
SELECT
  'vision_00000000-0000-0000-0000-00000000ee03_ok',
  'vision', payload,
  'Demo · Hito 3 solado salón (variante ok) · vinculada por milestone_id'
FROM public.ai_fixtures WHERE fixture_key = 'vision_default_m3_ok'
ON CONFLICT (fixture_key) DO UPDATE SET payload = EXCLUDED.payload;

INSERT INTO public.ai_fixtures (fixture_key, fixture_type, payload, description)
SELECT
  'vision_00000000-0000-0000-0000-00000000ee03_block',
  'vision', payload,
  'Demo · Hito 3 solado salón (variante block) · vinculada por milestone_id'
FROM public.ai_fixtures WHERE fixture_key = 'vision_default_m3_block'
ON CONFLICT (fixture_key) DO UPDATE SET payload = EXCLUDED.payload;


-- =====================================================================
-- 9 · Recarga del schema cache
-- =====================================================================
NOTIFY pgrst, 'reload schema';
