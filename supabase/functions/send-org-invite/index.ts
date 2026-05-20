// Edge Function: send-org-invite
//
// Dispara un email vía Resend al miembro recién invitado a una organización.
// La RPC sf_invite_org_member ya creó la fila en organization_members con el
// invitation_token; esta función solo lo lee y envía el correo con el link.
//
// Triggers:
//   - Llamada desde el cliente Flutter tras invocar sf_invite_org_member
//
// Body esperado: { member_id: string }
//
// Variables de entorno requeridas:
//   - RESEND_API_KEY      Tu API key de Resend
//   - RESEND_FROM_EMAIL   ej. "PactStream <equipo@pactstream.io>"
//   - APP_BASE_URL        ej. "https://app.pactstream.io"

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const RESEND_FROM_EMAIL =
  Deno.env.get('RESEND_FROM_EMAIL') ?? 'PactStream <onboarding@resend.dev>';
const APP_BASE_URL =
  Deno.env.get('APP_BASE_URL') ?? 'https://app.pactstream.io';

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

  if (!RESEND_API_KEY) {
    return json({ error: 'RESEND_API_KEY no configurada' }, 500);
  }

  let body: { member_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'JSON inválido' }, 400);
  }

  const memberId = body.member_id;
  if (!memberId) {
    return json({ error: 'member_id requerido' }, 400);
  }

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // 1. Recuperar datos del miembro + organización + owner
  const { data: rows, error: queryErr } = await adminClient
    .from('organization_members')
    .select(`
      id,
      invited_email,
      full_name,
      role,
      state,
      can_view_economics,
      invitation_token,
      invited_by_user_id,
      organization_id,
      organizations:organization_id (
        legal_name,
        trade_name,
        org_type
      ),
      inviter:invited_by_user_id (
        full_name,
        email
      )
    `)
    .eq('id', memberId)
    .single();

  if (queryErr || !rows) {
    console.error('Query error:', queryErr);
    return json({ error: 'Miembro no encontrado' }, 404);
  }

  const m = rows as any;

  if (m.state !== 'invited') {
    return json(
      { error: `Estado inválido: ${m.state}. Solo se envían emails de invitaciones pendientes.` },
      400,
    );
  }

  const org = Array.isArray(m.organizations) ? m.organizations[0] : m.organizations;
  const inviter = Array.isArray(m.inviter) ? m.inviter[0] : m.inviter;

  if (!org || !inviter) {
    return json({ error: 'Datos de organización o invitador incompletos' }, 500);
  }

  // Flutter web usa hash routing (#/org-invite). Si en el futuro habilitamos
  // path-based routing en main.dart con usePathUrlStrategy(), simplemente
  // cambia esta línea a `${APP_BASE_URL}/org-invite?token=...`.
  const inviteUrl = `${APP_BASE_URL}/#/org-invite?token=${m.invitation_token}`;
  const orgName = org.trade_name || org.legal_name;
  const inviterName = inviter.full_name || inviter.email;

  // 2. Construir HTML del email
  const subject = `${inviterName} te invita a unirte a ${orgName} en PactStream`;
  const html = buildHtml({
    memberName: m.full_name || m.invited_email,
    inviterName,
    orgName,
    canViewEconomics: m.can_view_economics,
    inviteUrl,
  });

  // 3. Enviar vía Resend
  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to: [m.invited_email],
      subject,
      html,
    }),
  });

  if (!resendRes.ok) {
    const errText = await resendRes.text();
    console.error('Resend error:', resendRes.status, errText);
    return json({ error: `Resend rechazó el envío: ${errText}` }, 502);
  }

  const resendData = await resendRes.json();
  console.log('Email enviado a', m.invited_email, '· resend_id:', resendData.id);

  return json({
    success: true,
    resend_id: resendData.id,
    sent_to: m.invited_email,
  });
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// =====================================================================
// HTML del email
// =====================================================================

function buildHtml(args: {
  memberName: string;
  inviterName: string;
  orgName: string;
  canViewEconomics: boolean;
  inviteUrl: string;
}): string {
  const econLine = args.canViewEconomics
    ? '<li>Acceso a presupuestos, importes y movimientos económicos.</li>'
    : '<li>Acceso a información operativa de las obras (evidencias, certificaciones, plazos).</li>';

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invitación a ${args.orgName}</title>
</head>
<body style="margin:0;padding:0;background-color:#FAFBFD;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1A1F4E;">
  <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="max-width:600px;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #E7E9F1;">
          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#080D42 0%,#14193D 100%);padding:32px 32px 24px;text-align:center;">
              <div style="display:inline-block;width:48px;height:48px;background:#00D4FF;border-radius:50%;line-height:48px;color:#080D42;font-weight:800;font-size:20px;margin-bottom:12px;">PS</div>
              <h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700;line-height:1.3;">Te han invitado al equipo de ${args.orgName}</h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:32px;">
              <p style="margin:0 0 16px;font-size:16px;line-height:1.6;color:#1A1F4E;">
                Hola <strong>${args.memberName}</strong>,
              </p>
              <p style="margin:0 0 16px;font-size:16px;line-height:1.6;color:#1A1F4E;">
                <strong>${args.inviterName}</strong> te ha invitado a formar parte del equipo de <strong>${args.orgName}</strong> en PactStream, la plataforma de confianza para gestión de pagos en obras de construcción.
              </p>

              <div style="background:#F3F4F9;border-radius:12px;padding:20px;margin:24px 0;">
                <p style="margin:0 0 8px;font-size:14px;color:#767BA3;text-transform:uppercase;letter-spacing:0.5px;font-weight:700;">Lo que podrás hacer</p>
                <ul style="margin:0;padding-left:20px;font-size:15px;line-height:1.7;color:#1A1F4E;">
                  <li>Subir evidencias de obra desde tu dispositivo móvil con verificación de autenticidad.</li>
                  <li>Acceder a las obras donde colaboras con ${args.orgName}.</li>
                  ${econLine}
                </ul>
              </div>

              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                <tr>
                  <td align="center" style="padding:8px 0 24px;">
                    <a href="${args.inviteUrl}"
                       style="display:inline-block;background:#3845FF;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:12px;font-size:16px;font-weight:700;">
                      Aceptar invitación
                    </a>
                  </td>
                </tr>
              </table>

              <p style="margin:0;font-size:13px;line-height:1.5;color:#767BA3;text-align:center;">
                Si el botón no funciona, copia y pega este enlace en tu navegador:<br>
                <span style="word-break:break-all;color:#3845FF;">${args.inviteUrl}</span>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#F3F4F9;padding:20px 32px;text-align:center;border-top:1px solid #E7E9F1;">
              <p style="margin:0;font-size:12px;color:#767BA3;line-height:1.5;">
                Este email se ha enviado a <strong>${args.memberName}</strong> porque ${args.inviterName} te incluyó en el equipo de ${args.orgName}.<br>
                Si no esperabas esta invitación, puedes ignorar este mensaje.
              </p>
              <p style="margin:16px 0 0;font-size:12px;color:#767BA3;">
                <a href="${APP_BASE_URL}" style="color:#3845FF;text-decoration:none;">PactStream</a> · La capa de confianza de la construcción
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}
