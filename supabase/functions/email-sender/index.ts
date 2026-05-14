// Edge Function: email-sender
// Consume la cola public.notifications (channel='email', sent_at IS NULL,
// failed_at IS NULL) y envía emails vía Resend API.
//
// Triggers:
//   - Llamada manual (POST sin body) → procesa hasta 50 emails pendientes
//   - Cron via pg_cron (futuro) → mismo flujo periódicamente
//
// Variables de entorno requeridas (Supabase Dashboard > Settings > Edge Functions):
//   - RESEND_API_KEY      Tu API key de Resend
//   - RESEND_FROM_EMAIL   ej. "PactStream <hola@tudominio.es>"
//   - APP_BASE_URL        ej. "https://app.pactstream.es" (para CTAs en email)
//
// Notas:
//   - Bucket privado de Storage (milestone-evidences) requiere signed URLs separadas
//   - Las plantillas HTML están inline para minimizar dependencias
//   - Limita a 50 envíos por invocación para no saturar Resend rate limits

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const RESEND_FROM_EMAIL = Deno.env.get('RESEND_FROM_EMAIL') ?? 'PactStream <onboarding@resend.dev>';
const APP_BASE_URL = Deno.env.get('APP_BASE_URL') ?? 'http://localhost:51055/#';
const BATCH_SIZE = 50;

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface NotificationRow {
  id: string;
  user_id: string;
  pact_id: string | null;
  milestone_id: string | null;
  notification_type: string;
  title: string;
  body: string;
  cta_url: string | null;
}

interface Target {
  email: string;
  full_name: string | null;
  has_account: boolean;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!RESEND_API_KEY) {
    return json({ error: 'RESEND_API_KEY no configurada' }, 500);
  }

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // 1. Pickup batch de notificaciones email pendientes
  const { data: pending, error: queryErr } = await adminClient
    .from('notifications')
    .select('id, user_id, pact_id, milestone_id, notification_type, title, body, cta_url')
    .eq('channel', 'email')
    .is('sent_at', null)
    .is('failed_at', null)
    .order('created_at', { ascending: true })
    .limit(BATCH_SIZE);

  if (queryErr) {
    console.error('Query error:', queryErr);
    return json({ error: queryErr.message }, 500);
  }

  if (!pending || pending.length === 0) {
    return json({ sent: 0, failed: 0, message: 'Cola vacía' });
  }

  let sent = 0;
  let failed = 0;
  const errors: { id: string; error: string }[] = [];

  for (const notif of pending as NotificationRow[]) {
    try {
      // Resolver email del destinatario via RPC
      const { data: targets, error: targetErr } = await adminClient.rpc(
        'get_notification_target',
        { p_notification_id: notif.id },
      );

      if (targetErr || !targets || (Array.isArray(targets) && targets.length === 0)) {
        await adminClient.rpc('mark_notification_failed', {
          p_notification_id: notif.id,
          p_reason: 'target_not_found',
        });
        failed++;
        continue;
      }

      const target = (Array.isArray(targets) ? targets[0] : targets) as Target;
      const recipientEmail = target.email;
      const recipientName = target.full_name ?? '';

      if (!recipientEmail || !recipientEmail.includes('@')) {
        await adminClient.rpc('mark_notification_failed', {
          p_notification_id: notif.id,
          p_reason: 'invalid_email',
        });
        failed++;
        continue;
      }

      // Construir CTA absoluto
      const ctaUrl = notif.cta_url
        ? (notif.cta_url.startsWith('http') ? notif.cta_url : APP_BASE_URL + notif.cta_url)
        : APP_BASE_URL;

      const html = renderEmailTemplate({
        title: notif.title,
        body: notif.body,
        ctaUrl,
        recipientName,
        notificationType: notif.notification_type,
      });

      // POST a Resend
      const resendRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: RESEND_FROM_EMAIL,
          to: recipientEmail,
          subject: notif.title,
          html,
        }),
      });

      if (!resendRes.ok) {
        const txt = await resendRes.text();
        await adminClient.rpc('mark_notification_failed', {
          p_notification_id: notif.id,
          p_reason: `resend_${resendRes.status}: ${txt.substring(0, 200)}`,
        });
        failed++;
        errors.push({ id: notif.id, error: `${resendRes.status} ${txt}` });
        continue;
      }

      // Marcar como enviado
      await adminClient.rpc('mark_notification_sent', {
        p_notification_id: notif.id,
      });
      sent++;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      await adminClient.rpc('mark_notification_failed', {
        p_notification_id: notif.id,
        p_reason: msg.substring(0, 500),
      });
      failed++;
      errors.push({ id: notif.id, error: msg });
    }
  }

  return json({ sent, failed, total: pending.length, errors });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// =====================================================================
// PLANTILLA HTML
// =====================================================================
// Diseño limpio compatible con la mayoría de clientes de email.
// Paleta PactStream: navy + cyan + blue.
function renderEmailTemplate(args: {
  title: string;
  body: string;
  ctaUrl: string;
  recipientName: string;
  notificationType: string;
}): string {
  const ctaLabel = ctaLabelFor(args.notificationType);
  const greeting = args.recipientName ? `Hola ${args.recipientName.split(' ')[0]},` : 'Hola,';

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(args.title)}</title>
</head>
<body style="margin:0; padding:0; background:#F3F4F9; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; color:#14193D;">
  <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#F3F4F9; padding:40px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px; background:#FFFFFF; border-radius:12px; overflow:hidden; box-shadow:0 4px 20px rgba(8,13,66,0.06);">
          <!-- Header -->
          <tr>
            <td style="background:#080D42; padding:24px 32px;">
              <div style="color:#A9F3FF; font-size:12px; font-weight:800; letter-spacing:3px;">PACTSTREAM</div>
              <div style="color:#FFFFFF; font-size:11px; opacity:0.7; margin-top:2px;">La capa de confianza de tu obra</div>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:32px;">
              <div style="font-size:14px; color:#4D5380; margin-bottom:8px;">${escapeHtml(greeting)}</div>
              <h1 style="margin:0 0 12px; font-size:22px; font-weight:800; color:#0A0E2A; line-height:1.3;">
                ${escapeHtml(args.title)}
              </h1>
              <p style="margin:0 0 24px; font-size:15px; line-height:1.55; color:#2A2F5C;">
                ${escapeHtml(args.body)}
              </p>
              <a href="${escapeAttr(args.ctaUrl)}" style="display:inline-block; background:#0121DC; color:#FFFFFF; text-decoration:none; padding:13px 24px; border-radius:8px; font-weight:800; font-size:14px;">
                ${escapeHtml(ctaLabel)} →
              </a>
              <p style="margin:24px 0 0; font-size:12px; color:#767BA3; line-height:1.5;">
                Si el botón no funciona, copia y pega este enlace en tu navegador:<br>
                <span style="word-break:break-all; color:#0121DC;">${escapeHtml(args.ctaUrl)}</span>
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background:#FAFBFD; padding:20px 32px; border-top:1px solid #E7E9F1;">
              <p style="margin:0; font-size:11px; color:#767BA3; line-height:1.5;">
                Has recibido este email porque participas como parte en un pacto en PactStream.<br>
                Si crees que es un error, ignora este mensaje. Tus datos están protegidos según el RGPD.
              </p>
            </td>
          </tr>
        </table>
        <p style="margin:16px 0 0; font-size:10px; color:#A4A8C4;">
          © PactStream · ${new Date().getFullYear()}
        </p>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function ctaLabelFor(type: string): string {
  switch (type) {
    case 'pact_invitation':
      return 'Ver el pacto';
    case 'all_parties_accepted':
      return 'Ir a firmar';
    case 'contract_fully_signed':
      return 'Ver el pacto';
    case 'pact_funded':
      return 'Empezar el primer hito';
    case 'milestone_pending_tech_review':
      return 'Revisar las evidencias';
    case 'milestone_pending_promotor':
      return 'Revisar y decidir';
    case 'milestone_needs_rework':
      return 'Ver los comentarios';
    case 'milestone_paid':
      return 'Ver el pago';
    case 'milestone_disputed':
      return 'Gestionar la disputa';
    case 'pact_completed':
      return 'Ver la obra cerrada';
    default:
      return 'Abrir PactStream';
  }
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function escapeAttr(s: string): string {
  return s.replace(/"/g, '&quot;');
}
