# Activación del escrow Stripe en PRODUCCIÓN — runbook

> Estado a 2026-08-22: código completo y verificado en test. Este documento es la
> checklist de **activación** (ops + negocio). El código nuevo de esta tanda es el
> **onboarding del constructor** (Stripe Account Links) — ver §4.
>
> ⚠️ **Copy público**: hasta que Stripe esté en vivo y probado, la UI y el marketing
> NO nombran al proveedor ni afirman custodia operativa. Fórmula acordada: "cuenta
> regulada, se abre por oleadas". La pantalla de Ganancias ya usa lenguaje neutro
> ("proveedor de pagos", "verificación de identidad"), sin mencionar "Stripe".

## Qué hace cada pieza (mapa rápido)

| Pieza | Función/archivo | Responsable |
|---|---|---|
| Alta cuenta constructor (acct v2) | `escrow-onboard-link` (crea si falta) | Código ✅ |
| **KYC alojado (Account Link v2)** | `escrow-onboard-link` → `createOnboardingLink` | Código ✅ (nuevo) |
| Pantalla "Verificar identidad" | `earnings_page.dart` + `PactActionsV2.startEscrowOnboarding` | Código ✅ (nuevo) |
| Re-chequeo al volver del navegador | `EarningsPage` observer `AppLifecycleState.resumed` | Código ✅ (nuevo) |
| Estado de cobros (fuente de verdad, en vivo) | `escrow-wallet-status` → `getKycLevel` | Código ✅ |
| Webhook pay-in / payout | `stripe-webhook` (v1) | Código ✅ |
| Webhook capability v2 (auditoría) | `stripe-webhook` rama `v2.core.account*` | Código ✅ (nuevo) |
| Aprobación negocio restringido | Dashboard Stripe | **Andrés** |
| Connect habilitado en cuenta live | Dashboard Stripe | **Andrés** |
| Secretos en Supabase prod | Dashboard Supabase | **Andrés** |
| Aplicar migración payouts | `supabase db push` | **Andrés** (§5) |
| Registrar webhook endpoint | Dashboard Stripe / CLI | **Andrés** (§6) |

---

## 1 · Aprobación de negocio restringido (Stripe) — Andrés

Solicitar aprobación de **escrow + facilitación de pagos** sobre la **cuenta correcta**:
**Tomato Design SL / PactStream SL**, NO la de Totalcocina (esa fue solo para probar
en test). Carta base: `SOLICITUD_STRIPE_para_pegar.txt`.

## 2 · Habilitar Connect en la cuenta live — Andrés

`dashboard.stripe.com/connect` sobre la cuenta live correcta. Con Accounts v2 por
defecto (es lo que crea el código: `POST /v2/core/accounts`, config `recipient`).

## 3 · Secretos en el Supabase de PRODUCCIÓN — Andrés

Claude no maneja valores. Poner en el proyecto Supabase destino:

```bash
# Secretos de las Edge Functions (dashboard Supabase → Edge Functions → Secrets, o CLI):
supabase secrets set STRIPE_SECRET_KEY=sk_live_xxx
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx
supabase secrets set ESCROW_PROVIDER=stripe
# Opcionales (tienen default; cámbialos si la landing de retorno vive en otra URL):
supabase secrets set ESCROW_ONBOARD_RETURN_URL=https://pactstream.io/escrow/onboarding-complete
supabase secrets set ESCROW_ONBOARD_REFRESH_URL=https://pactstream.io/escrow/onboarding-refresh
```

- `ESCROW_ONBOARD_RETURN_URL` / `_REFRESH_URL` solo necesitan **existir** como páginas
  https: la app re-consulta el estado al reanudar (no hay deep link). Basta un landing
  estático "Verificación completada, vuelve a la app".
- **Build Flutter** con: `--dart-define=ESCROW_PROVIDER=stripe`.

Deploy de las funciones (incluye la nueva `escrow-onboard-link`, `--no-verify-jwt`
solo para el webhook):

```bash
supabase functions deploy escrow-onboard-link
supabase functions deploy escrow-wallet-status
supabase functions deploy escrow-release
supabase functions deploy escrow-payin
supabase functions deploy escrow-payout
supabase functions deploy escrow-bank-account
supabase functions deploy stripe-webhook --no-verify-jwt
```

## 4 · Onboarding del constructor (Account Links) — CÓDIGO (hecho)

Flujo nuevo:

1. El constructor abre **Ganancias**. Si su cuenta de cobros no está activa, ve
   **"Verificar mi identidad"** → `PactActionsV2.startEscrowOnboarding()`.
2. `escrow-onboard-link` asegura su cuenta conectada OWNER (`acct_…`, la crea si falta;
   el KYC alojado recoge fecha de nacimiento/nacionalidad, no se piden por adelantado)
   y pide un **Account Link v2** (`POST /v2/core/account_links`, `use_case.type=
   account_onboarding`, `configurations:['recipient']`). URL de un solo uso, caduca ~10 min.
3. La app abre esa URL en el navegador (`url_launcher`, `externalApplication`).
4. Al volver a la app, `EarningsPage` re-consulta `escrow-wallet-status`. `getKycLevel`
   lee la cuenta **en vivo**: cuando `stripe_transfers` queda `active`, la pantalla
   muestra "Identidad verificada" y se habilitan liberación/retirada.

> **Orden importante**: con Stripe el constructor debe completar este KYC **antes** de
> que el promotor pueda liberar un hito (`escrow-release` exige la cuenta OWNER con la
> capability activa; si no, Stripe rechaza el transfer). La antigua copy "se activa
> automáticamente al recibir tu primera liberación" ya NO aplica y fue reemplazada.

## 5 · Aplicar la migración de payouts — Andrés

`supabase/migrations/20260806000002_payouts.sql` (tabla `payouts` + columnas
`users.mangopay_bank_account_id`). NO estaba aplicada a dev. Aplicar al proyecto destino:

```bash
supabase link --project-ref <ref-del-proyecto-destino>
supabase db push
```

**Además, desde el 31-ago hay una segunda migración pendiente de aplicar a producción:**
`supabase/migrations/20260831090000_escrow_identidad_separada_por_rol.sql`. Separa
`users.mangopay_user_id` en `escrow_owner_id` (cobra) y `escrow_payer_id` (paga),
porque el rol se asigna POR PACTO y una misma persona puede necesitar las dos
identidades. Incluye CHECK de prefijo, índices únicos y la extensión del trigger
anti-escalada. **Ya aplicada a `pactstream-dev`**; el backfill es un no-op mientras
nadie tenga cuenta creada, así que conviene aplicarla ANTES del primer onboarding real.

(Para el onboarding en sí no hace falta migración: la decisión de arquitectura es que
`getKycLevel` en vivo es la fuente de verdad; el webhook de capability solo audita.)

## 6 · Registrar el endpoint de webhook en Stripe — Andrés

URL: `https://<PROYECTO>.supabase.co/functions/v1/stripe-webhook` (desplegado con
`--no-verify-jwt`; la firma Stripe ES la auth).

**Eventos v1 (imprescindibles — snapshot, dashboard clásico de webhooks):**
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `payout.paid`
- `payout.failed`

Copia el **Signing secret** de ese endpoint a `STRIPE_WEBHOOK_SECRET` (§3).

**Eventos v2 de cuenta/capability (opcional — solo auditoría):**
Con la decisión "estado en vivo", NO son necesarios para el funcionamiento (la app lee
`getKycLevel` en vivo). Si se quieren registrar igualmente para trazabilidad, son
**thin events** y requieren un *event destination* v2 aparte (Stripe-Version preview),
con su propio signing secret — que NO coincide con el `STRIPE_WEBHOOK_SECRET` del
endpoint v1. Eventos:
- `v2.core.account[configuration.recipient].capability_status_updated`
- `v2.core.account[requirements].updated`

> El handler ya reconoce y registra cualquier `v2.core.account*` en `webhook_events`.
> Si se registra el destino v2 con distinto secret, habrá que soportar dos secrets en
> el handler (hoy verifica con uno). Pendiente solo si se activa esta ruta de auditoría.

## 7 · Verificación del ciclo COMPLETO — Andrés

**Primero en test** (con onboarding del constructor completado):
1. Constructor: Ganancias → "Verificar mi identidad" → completar KYC alojado (test).
2. Verificar en `escrow-wallet-status` que `kyc_level` pasa a `REGULAR`
   (`payouts_enabled` + `transfers` active).
3. Promotor: pay-in (IBAN virtual) → fondear → webhook `payment_intent.succeeded`.
4. Promotor: liberar hito → `transfer` en verde (destino `acct_` del constructor).
5. Constructor: registrar IBAN → retirar → `payout` → webhook `payout.paid`.

**Luego en live**: un importe **mínimo** recorriendo el mismo ciclo end-to-end.
