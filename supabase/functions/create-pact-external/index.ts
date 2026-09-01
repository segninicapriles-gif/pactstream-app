// Edge Function: create-pact-external
//
// API REST para que ConstructPro (u otros servicios autorizados) creen pactos
// en PactStream sin pasar por el wizard Flutter.
//
// Autenticación: API key en header X-API-Key, validada contra la tabla
// api_keys (partner_id, key_hash, scopes, active).
//
// Flow:
//   ConstructPro → POST /create-pact-external { ... }
//   Edge Function → valida API key + scopes
//                 → sf_create_pact_v21 (service_role, impersonando al usuario)
//                 → sf_invite_party × N
//                 → sf_finalize_pact_v21 (opcional, si auto_finalize=true)
//                 → respuesta JSON { pactId, displayId, state }
//
// Variables de entorno requeridas:
//   - SUPABASE_URL              (auto)
//   - SUPABASE_SERVICE_ROLE_KEY (auto)
//
// Seguridad:
//   - La API key se hashea con SHA-256 y se compara contra api_keys.key_hash.
//   - El partner debe tener scope 'pact:create'.
//   - created_by_user_id viene del campo creator_email → lookup en auth.users.
//   - Rate limit: 60 req/min por partner (tabla api_keys.rate_limit_rpm).
//   - Todos los campos se validan antes de llamar al RPC.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-api-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PartyInvite {
  role: 'promotor' | 'constructor' | 'tecnico';
  email: string;
  full_name: string;
  phone?: string;
}

interface CreatePactRequest {
  creator_email: string;
  title: string;
  description?: string;
  pact_type: 'obra_mayor' | 'obra_menor';
  obra_address_line: string;
  obra_province: string;
  obra_postal_code?: string;
  obra_city?: string;
  obra_type?: string;
  total_amount_cents: number;
  iva_rate_pct: number;
  iva_included: boolean;
  advance_pct?: number;
  advance_reserve_pct?: number;
  certification_frequency?: string;
  estimated_start_date?: string;
  estimated_end_date?: string;
  obra_menor_declaration_accepted?: boolean;
  invites: PartyInvite[];
  auto_finalize?: boolean;
  source_ref?: string; // ConstructPro budget ID or external reference
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function jsonOk(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function hashKey(key: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(key);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function validateRequest(body: CreatePactRequest): string | null {
  if (!body.creator_email) return 'creator_email is required';
  if (!body.title?.trim()) return 'title is required';
  if (!body.pact_type || !['obra_mayor', 'obra_menor'].includes(body.pact_type))
    return 'pact_type must be obra_mayor or obra_menor';
  if (!body.obra_address_line?.trim()) return 'obra_address_line is required';
  if (!body.obra_province?.trim()) return 'obra_province is required';
  if (typeof body.total_amount_cents !== 'number' || body.total_amount_cents < 50000)
    return 'total_amount_cents must be >= 50000 (€500)';
  if (body.iva_rate_pct === undefined || body.iva_rate_pct === null)
    return 'iva_rate_pct is required';
  if (typeof body.iva_included !== 'boolean')
    return 'iva_included must be a boolean';
  if (body.advance_pct !== undefined && (body.advance_pct < 10 || body.advance_pct > 40))
    return 'advance_pct must be between 10 and 40';
  if (!Array.isArray(body.invites) || body.invites.length === 0)
    return 'invites array is required with at least one party';

  for (const inv of body.invites) {
    if (!['promotor', 'constructor', 'tecnico'].includes(inv.role))
      return `invalid role "${inv.role}" in invites`;
    if (!inv.email?.trim()) return 'each invite must have an email';
    if (!inv.full_name?.trim()) return 'each invite must have a full_name';
  }

  if (body.pact_type === 'obra_menor') {
    if (body.invites.some((i) => i.role === 'tecnico'))
      return 'obra_menor cannot have tecnico role';
  }

  return null;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonError('Method not allowed', 405);
  }

  // --- Auth: API key ---
  const apiKey = req.headers.get('x-api-key');
  if (!apiKey) {
    return jsonError('Missing X-API-Key header', 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const keyHash = await hashKey(apiKey);
  const { data: keyRow, error: keyErr } = await admin
    .from('api_keys')
    .select('id, partner_id, scopes, active, rate_limit_rpm')
    .eq('key_hash', keyHash)
    .single();

  if (keyErr || !keyRow) {
    return jsonError('Invalid API key', 401);
  }
  if (!keyRow.active) {
    return jsonError('API key is deactivated', 403);
  }
  if (!keyRow.scopes?.includes('pact:create')) {
    return jsonError('API key lacks pact:create scope', 403);
  }

  // --- Rate limit check ---
  const { count: recentCalls } = await admin
    .from('api_key_usage')
    .select('*', { count: 'exact', head: true })
    .eq('api_key_id', keyRow.id)
    .gte('created_at', new Date(Date.now() - 60_000).toISOString());

  const rpm = keyRow.rate_limit_rpm ?? 60;
  if ((recentCalls ?? 0) >= rpm) {
    return jsonError('Rate limit exceeded', 429);
  }

  // Log usage
  await admin.from('api_key_usage').insert({
    api_key_id: keyRow.id,
    partner_id: keyRow.partner_id,
    endpoint: 'create-pact-external',
  });

  // --- Parse & validate body ---
  let body: CreatePactRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError('Invalid JSON body', 400);
  }

  const validationError = validateRequest(body);
  if (validationError) {
    return jsonError(validationError, 400);
  }

  // --- Resolve creator user ---
  const { data: usersPage, error: userErr } = await admin.auth.admin.listUsers({
    page: 1,
    perPage: 1,
    filter: body.creator_email.toLowerCase(),
  });
  const creator = usersPage?.users?.[0];
  if (userErr || !creator || creator.email?.toLowerCase() !== body.creator_email.toLowerCase()) {
    return jsonError(
      `User with email ${body.creator_email} not found in PactStream`,
      404
    );
  }

  // --- Step 1: Create pact ---
  const { data: pactResult, error: createErr } = await admin.rpc(
    'sf_create_pact_v21',
    {
      p_title: body.title.trim(),
      p_obra_address_line: body.obra_address_line.trim(),
      p_total_amount_cents: body.total_amount_cents,
      p_description: body.description?.trim() ?? '',
      p_pact_type: body.pact_type,
      p_obra_postal_code: body.obra_postal_code ?? '',
      p_obra_city: body.obra_city ?? '',
      p_obra_province: body.obra_province.trim(),
      p_obra_type:
        body.obra_type ??
        (body.pact_type === 'obra_menor'
          ? 'obra_menor_otra'
          : 'reforma_integral'),
      p_iva_rate_pct: body.iva_rate_pct,
      p_iva_included: body.iva_included,
      p_estimated_start_date: body.estimated_start_date ?? null,
      p_estimated_end_date: body.estimated_end_date ?? null,
      p_advance_pct: body.advance_pct ?? 30,
      p_advance_reserve_pct: body.advance_reserve_pct ?? 10,
      p_certification_frequency: body.certification_frequency ?? 'Mensual',
      p_obra_menor_declaration_accepted:
        body.obra_menor_declaration_accepted ?? false,
    },
    { headers: { 'x-supabase-auth-user-id': creator.id } }
  );

  if (createErr) {
    return jsonError(`Failed to create pact: ${createErr.message}`, 500);
  }

  const pactId = pactResult?.out_pact_id ?? pactResult?.[0]?.out_pact_id;
  const displayId =
    pactResult?.out_display_id ?? pactResult?.[0]?.out_display_id;

  if (!pactId) {
    return jsonError('Pact creation returned no ID', 500);
  }

  // --- Store external reference ---
  if (body.source_ref) {
    await admin.from('pact_metadata').insert({
      pact_id: pactId,
      key: 'constructpro_ref',
      value: body.source_ref,
    });
  }

  // --- Step 2: Invite parties ---
  const inviteResults: { role: string; success: boolean; error?: string }[] =
    [];

  for (const inv of body.invites) {
    const { error: invErr } = await admin.rpc(
      'sf_invite_party',
      {
        p_pact_id: pactId,
        p_role: inv.role,
        p_email: inv.email.trim().toLowerCase(),
        p_full_name: inv.full_name.trim(),
        p_phone: inv.phone ?? '',
      },
      { headers: { 'x-supabase-auth-user-id': creator.id } }
    );

    inviteResults.push({
      role: inv.role,
      success: !invErr,
      error: invErr?.message,
    });
  }

  const failedInvites = inviteResults.filter((r) => !r.success);
  if (failedInvites.length > 0) {
    return jsonOk(
      {
        pact_id: pactId,
        display_id: displayId,
        state: 'draft',
        warning: 'Some invites failed',
        invite_results: inviteResults,
      },
      207
    );
  }

  // --- Step 3: Finalize (optional) ---
  let finalState = 'draft';

  if (body.auto_finalize !== false) {
    const { error: finErr } = await admin.rpc(
      'sf_finalize_pact_v21',
      { p_pact_id: pactId },
      { headers: { 'x-supabase-auth-user-id': creator.id } }
    );

    if (finErr) {
      return jsonOk(
        {
          pact_id: pactId,
          display_id: displayId,
          state: 'draft',
          warning: `Invites OK but finalize failed: ${finErr.message}`,
          invite_results: inviteResults,
        },
        207
      );
    }

    finalState = 'inviting';

    // Kick email sender to process invitation notifications
    try {
      await admin.functions.invoke('email-sender', {
        body: { trigger: 'create-pact-external' },
      });
    } catch {
      // Non-fatal: emails will be picked up by cron
    }
  }

  // --- Audit log ---
  await admin.from('audit_log').insert({
    action: 'pact_created_external',
    actor_id: creator.id,
    metadata: {
      pact_id: pactId,
      display_id: displayId,
      partner_id: keyRow.partner_id,
      source_ref: body.source_ref ?? null,
      total_amount_cents: body.total_amount_cents,
      party_count: body.invites.length + 1,
    },
  });

  return jsonOk({
    pact_id: pactId,
    display_id: displayId,
    state: finalState,
    invite_results: inviteResults,
    source_ref: body.source_ref ?? null,
  });
});
