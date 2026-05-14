// Edge Function: veriff-webhook
// Recibe el callback de Veriff cuando una verificación se completa.
//
// Flow:
//   1. Veriff hace POST a esta function con el resultado.
//   2. Validamos HMAC-SHA256 signature usando VERIFF_PRIVATE_KEY.
//   3. Idempotencia: comprobamos webhook_events por (provider, external_id).
//   4. Actualizamos users.kyc_status según el resultado.
//   5. Insertamos audit_log y webhook_events.
//   6. Devolvemos 200 OK a Veriff.
//
// Variables de entorno requeridas:
//   - VERIFF_PRIVATE_KEY  (shared secret de la integración Veriff)
//
// Configuración en Veriff Dashboard:
//   - Webhook URL: https://erqglsrnknhwqhfupckf.supabase.co/functions/v1/veriff-webhook
//   - Headers: Veriff envía X-HMAC-SIGNATURE con HMAC-SHA256(body, private_key)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';

const VERIFF_PRIVATE_KEY = Deno.env.get('VERIFF_PRIVATE_KEY')!;

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const body = await req.text();
    const signature =
      req.headers.get('x-hmac-signature') ??
      req.headers.get('X-HMAC-SIGNATURE') ??
      '';

    // Validar HMAC-SHA256
    const valid = await verifyHmac(body, signature, VERIFF_PRIVATE_KEY);
    if (!valid) {
      console.warn('Invalid HMAC signature received');
      return new Response('Invalid signature', { status: 401 });
    }

    const payload = JSON.parse(body);

    // Estructura típica del payload Veriff:
    // {
    //   "status": "success",
    //   "verification": {
    //     "id": "session-uuid",
    //     "code": 9001,
    //     "status": "approved" | "declined" | "resubmission_requested" | "expired",
    //     "vendorData": "our-user-id",
    //     "reason": "...",
    //     "person": { ... }
    //   }
    // }

    const verification = payload.verification ?? payload;
    const sessionId = verification.id;
    const veriffStatus = verification.status;
    const userId = verification.vendorData;

    if (!sessionId || !userId) {
      console.error('Missing required fields:', { sessionId, userId });
      return new Response('Bad payload', { status: 400 });
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Idempotencia: si ya procesamos este event, salir
    const { data: existing } = await adminClient
      .from('webhook_events')
      .select('id, processed_at')
      .eq('provider', 'veriff')
      .eq('external_id', sessionId)
      .maybeSingle();

    if (existing?.processed_at) {
      return new Response('Already processed', { status: 200 });
    }

    // Mapear estado Veriff a nuestro kyc_status
    let kycStatus: string;
    switch (veriffStatus) {
      case 'approved':
        kycStatus = 'verified';
        break;
      case 'declined':
        kycStatus = 'rejected';
        break;
      case 'resubmission_requested':
        kycStatus = 'pending_review';
        break;
      case 'expired':
        kycStatus = 'expired';
        break;
      default:
        kycStatus = 'in_progress';
    }

    // Actualizar usuario
    const updateData: Record<string, unknown> = {
      kyc_status: kycStatus,
      kyc_external_id: sessionId,
      kyc_session_url: null, // limpiar URL temporal
    };
    if (kycStatus === 'verified') {
      updateData.kyc_verified_at = new Date().toISOString();
    }

    const { error: updateError } = await adminClient
      .from('users')
      .update(updateData)
      .eq('id', userId);

    if (updateError) {
      console.error('Update error:', updateError);
      return new Response('Database error', { status: 500 });
    }

    // Audit log
    await adminClient.from('audit_log').insert({
      actor_user_id: userId,
      action: 'kyc_completed',
      entity_type: 'user',
      entity_id: userId,
      metadata: {
        provider: 'veriff',
        decision: veriffStatus,
        session_id: sessionId,
        reason: verification.reason ?? null,
      },
    });

    // Idempotencia + auditoría del webhook
    await adminClient.from('webhook_events').upsert(
      {
        provider: 'veriff',
        external_id: sessionId,
        event_type: veriffStatus,
        payload,
        signature_valid: true,
        processed_at: new Date().toISOString(),
        processed_result: 'success',
      },
      { onConflict: 'provider,external_id' },
    );

    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('Webhook error:', error);
    return new Response(
      `Error: ${error instanceof Error ? error.message : 'Unknown'}`,
      { status: 500 },
    );
  }
});

// Validación HMAC-SHA256 con WebCrypto (Deno-native)
async function verifyHmac(
  body: string,
  signature: string,
  secret: string,
): Promise<boolean> {
  if (!signature) return false;
  try {
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
      'raw',
      enc.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const sig = await crypto.subtle.sign('HMAC', key, enc.encode(body));
    const computed = Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
    return computed === signature.toLowerCase();
  } catch (e) {
    console.error('HMAC error:', e);
    return false;
  }
}
