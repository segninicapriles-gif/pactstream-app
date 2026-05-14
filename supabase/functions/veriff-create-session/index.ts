// Edge Function: veriff-create-session
// Lanza una sesión de verificación Veriff para el usuario autenticado.
//
// Flow:
//   1. Cliente Flutter llama esta function pasando JWT.
//   2. Validamos JWT y leemos perfil de public.users.
//   3. POST a Veriff /v1/sessions con datos del usuario.
//   4. Guardamos session_id + URL en users.kyc_external_id + kyc_session_url.
//   5. Marcamos kyc_status = 'in_progress'.
//   6. Devolvemos URL para que el cliente redirija al usuario.
//
// Variables de entorno requeridas (configurar en Supabase Dashboard):
//   - VERIFF_API_KEY      (public key, empieza por sb_publishable_... o JWT)
//   - VERIFF_BASE_URL     (https://stationapi.veriff.com)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';

const VERIFF_API_KEY = Deno.env.get('VERIFF_API_KEY')!;
const VERIFF_BASE_URL =
  Deno.env.get('VERIFF_BASE_URL') ?? 'https://stationapi.veriff.com';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return jsonResponse({ error: 'Missing Authorization header' }, 401);
    }

    // Cliente con el JWT del usuario para respetar RLS
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    // Validar JWT
    const { data: userData, error: userError } =
      await userClient.auth.getUser();
    if (userError || !userData.user) {
      console.error('Auth error:', userError);
      return jsonResponse({ error: 'Not authenticated' }, 401);
    }

    console.log('Auth user:', userData.user.id, userData.user.email);

    // Leer perfil — usar service role para evitar RLS y diagnosticar mejor
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: profile, error: profileError } = await adminClient
      .from('users')
      .select('id, full_name, email, deleted_at, auth_provider_id')
      .eq('auth_provider_id', userData.user.id)
      .maybeSingle();

    console.log('Profile query result:', { profile, error: profileError });

    if (profileError) {
      console.error('Profile query error:', profileError);
      return jsonResponse(
        { error: `Profile query error: ${profileError.message}` },
        500,
      );
    }

    if (!profile) {
      console.error('Profile not found for auth_provider_id:', userData.user.id);
      return jsonResponse(
        {
          error: 'Profile not found',
          hint: `No se encontró perfil con auth_provider_id=${userData.user.id}`,
        },
        404,
      );
    }

    if (profile.deleted_at) {
      console.error('Profile is soft-deleted:', profile.id);
      return jsonResponse(
        {
          error: 'Profile is deleted',
          hint: 'Este usuario fue borrado. Restaura deleted_at=NULL en BD.',
        },
        404,
      );
    }

    // Separar nombre y apellidos
    const nameParts = (profile.full_name as string).trim().split(/\s+/);
    const firstName = nameParts[0] || profile.full_name;
    const lastName = nameParts.slice(1).join(' ') || '—';

    // Crear sesión Veriff
    // NOTA: NO incluimos `callback` en el payload. Veriff mostrará su
    // propia pantalla de "Done" tras completar la verificación, y el
    // usuario vuelve manualmente a la app PactStream. La pestaña de
    // PactStream detecta el cambio de kyc_status vía polling.
    // Si en V2 quieres redirigir a una URL custom, créala como Edge
    // Function (ej. veriff-callback-redirect) que devuelva HTML de
    // "Vuelve a la app".
    const veriffPayload = {
      verification: {
        person: {
          firstName,
          lastName,
        },
        vendorData: profile.id, // referenciamos nuestro user_id
        timestamp: new Date().toISOString(),
      },
    };

    const veriffResponse = await fetch(`${VERIFF_BASE_URL}/v1/sessions`, {
      method: 'POST',
      headers: {
        'X-AUTH-CLIENT': VERIFF_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(veriffPayload),
    });

    if (!veriffResponse.ok) {
      const errorText = await veriffResponse.text();
      console.error('Veriff API error:', veriffResponse.status, errorText);
      return jsonResponse(
        {
          error: `Veriff API error (${veriffResponse.status}): ${errorText}`,
        },
        500,
      );
    }

    const veriffData = await veriffResponse.json();
    const sessionId = veriffData.verification.id;
    const sessionUrl = veriffData.verification.url;

    // Reusamos adminClient declarado arriba para actualizar kyc_status
    await adminClient
      .from('users')
      .update({
        kyc_status: 'in_progress',
        kyc_provider: 'veriff',
        kyc_external_id: sessionId,
        kyc_session_url: sessionUrl,
      })
      .eq('id', profile.id);

    return jsonResponse(
      {
        session_id: sessionId,
        url: sessionUrl,
      },
      200,
    );
  } catch (error) {
    console.error('Error:', error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      500,
    );
  }
});

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
