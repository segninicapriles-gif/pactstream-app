// Tests deterministas del proveedor de escrow (offline, sin cuenta ni dinero real).
//   deno test --allow-env supabase/functions/_shared/escrow.test.ts
//
// Cubren: factory de selección de proveedor, formas del mock Stripe, el
// request-builder del cliente Stripe real (contra un fetch stub) y la
// verificación de firma de webhook.

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { getEscrowClient, activeEscrowProvider } from './escrow.ts'
import { MangopayClient, MockMangopayClient } from './mangopay.ts'
import {
  expectedStripeSignature,
  MockStripeClient,
  type StripeConfig,
  StripeEscrowClient,
  toForm,
  verifyStripeSignature,
} from './stripe.ts'

const ESCROW_ENV = [
  'ESCROW_PROVIDER',
  'STRIPE_SIMULATE',
  'MANGOPAY_SIMULATE',
  'STRIPE_SECRET_KEY',
  'STRIPE_SIM_BALANCE_CENTS',
  'MANGOPAY_CLIENT_ID',
  'MANGOPAY_API_KEY',
]
function clearEscrowEnv() {
  for (const k of ESCROW_ENV) Deno.env.delete(k)
}

// ── Factory ─────────────────────────────────────────────────────────────────

Deno.test('factory: inerte (null) sin proveedor ni credenciales', () => {
  clearEscrowEnv()
  assertEquals(getEscrowClient(), null)
  assertEquals(activeEscrowProvider(), 'mock')
})

Deno.test('factory: STRIPE_SIMULATE → MockStripeClient', () => {
  clearEscrowEnv()
  Deno.env.set('STRIPE_SIMULATE', 'true')
  assert(getEscrowClient() instanceof MockStripeClient)
  clearEscrowEnv()
})

Deno.test('factory: MANGOPAY_SIMULATE → MockMangopayClient', () => {
  clearEscrowEnv()
  Deno.env.set('MANGOPAY_SIMULATE', 'true')
  assert(getEscrowClient() instanceof MockMangopayClient)
  clearEscrowEnv()
})

Deno.test('factory: ESCROW_PROVIDER=mock → MockStripeClient (mock por defecto tras el pivote)', () => {
  clearEscrowEnv()
  Deno.env.set('ESCROW_PROVIDER', 'mock')
  assert(getEscrowClient() instanceof MockStripeClient)
  clearEscrowEnv()
})

Deno.test('factory: ESCROW_PROVIDER=stripe sin key → null (inerte)', () => {
  clearEscrowEnv()
  Deno.env.set('ESCROW_PROVIDER', 'stripe')
  assertEquals(getEscrowClient(), null)
  clearEscrowEnv()
})

Deno.test('factory: ESCROW_PROVIDER=stripe con key → StripeEscrowClient (no mock)', () => {
  clearEscrowEnv()
  Deno.env.set('ESCROW_PROVIDER', 'stripe')
  Deno.env.set('STRIPE_SECRET_KEY', 'sk_test_dummy')
  const c = getEscrowClient()
  assert(c instanceof StripeEscrowClient)
  assert(!(c instanceof MockStripeClient))
  assertEquals(activeEscrowProvider(), 'stripe')
  clearEscrowEnv()
})

Deno.test('factory: ESCROW_PROVIDER=mangopay con creds → MangopayClient', () => {
  clearEscrowEnv()
  Deno.env.set('ESCROW_PROVIDER', 'mangopay')
  Deno.env.set('MANGOPAY_CLIENT_ID', 'cid')
  Deno.env.set('MANGOPAY_API_KEY', 'key')
  assert(getEscrowClient() instanceof MangopayClient)
  clearEscrowEnv()
})

Deno.test('factory: autodetección prefiere Stripe si hay key', () => {
  clearEscrowEnv()
  Deno.env.set('STRIPE_SECRET_KEY', 'sk_test_dummy')
  assertEquals(activeEscrowProvider(), 'stripe')
  assert(getEscrowClient() instanceof StripeEscrowClient)
  clearEscrowEnv()
})

// ── Mock Stripe: formas ──────────────────────────────────────────────────────

Deno.test('mock Stripe: PAYER→cus_, OWNER→acct_', async () => {
  const c = new MockStripeClient()
  const payer = await c.createNaturalUser({ firstName: 'A', lastName: 'B', email: 'a@b.c', category: 'PAYER' })
  const owner = await c.createNaturalUser({ firstName: 'C', lastName: 'D', email: 'c@d.e', category: 'OWNER' })
  assertStringIncludes(payer.id, 'cus_')
  assertStringIncludes(owner.id, 'acct_')
})

Deno.test('mock Stripe: getPayIn SUCCEEDED, transfer SUCCEEDED, kyc REGULAR', async () => {
  const c = new MockStripeClient()
  assertEquals((await c.getPayIn('pi_x')).status, 'SUCCEEDED')
  assertEquals((await c.createTransfer('a', 'w', 'acct_1', 100)).status, 'SUCCEEDED')
  assertEquals(await c.getKycLevel('acct_1'), 'REGULAR')
})

Deno.test('mock Stripe: balance desde STRIPE_SIM_BALANCE_CENTS', async () => {
  const c = new MockStripeClient()
  assertEquals(await c.getWalletBalanceCents('acct_1'), 500000)
  Deno.env.set('STRIPE_SIM_BALANCE_CENTS', '12345')
  assertEquals(await c.getWalletBalanceCents('acct_1'), 12345)
  Deno.env.delete('STRIPE_SIM_BALANCE_CENTS')
})

// ── Encoder form-urlencoded ──────────────────────────────────────────────────

Deno.test('toForm: anida objetos y arrays con corchetes', () => {
  const s = toForm({
    amount: 1000,
    currency: 'eur',
    'payment_method_types': ['customer_balance'],
    metadata: { pact_wallet: 'w1' },
  })
  assertStringIncludes(s, 'amount=1000')
  assertStringIncludes(s, 'currency=eur')
  assertStringIncludes(s, 'payment_method_types%5B0%5D=customer_balance')
  assertStringIncludes(s, 'metadata%5Bpact_wallet%5D=w1')
})

// ── Cliente Stripe real: request-builder (fetch stub) ────────────────────────

const CFG: StripeConfig = {
  secretKey: 'sk_test_builder',
  baseUrl: 'https://api.stripe.test',
  connectCountry: 'ES',
  bankTransferCountry: 'IE',
  apiVersion: '2024-06-20',
  apiVersionV2: '2026-07-29.preview',
}

interface Captured { url: string; method: string; headers: Headers; body: string }

function stubFetch(responseObj: unknown): { restore: () => void; last: () => Captured } {
  const original = globalThis.fetch
  let captured: Captured | null = null
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    captured = {
      url: String(input),
      method: String(init?.method ?? 'GET'),
      headers: new Headers(init?.headers as HeadersInit),
      body: String(init?.body ?? ''),
    }
    return Promise.resolve(new Response(JSON.stringify(responseObj), { status: 200 }))
    // deno-lint-ignore no-explicit-any
  }) as any
  return { restore: () => { globalThis.fetch = original }, last: () => captured! }
}

Deno.test('Stripe createNaturalUser(OWNER): POST /v2/core/accounts recipient/stripe_transfers (JSON + preview)', async () => {
  const s = stubFetch({ id: 'acct_1' })
  try {
    const c = new StripeEscrowClient(CFG)
    const r = await c.createNaturalUser({ firstName: 'Ana', lastName: 'Ruiz', email: 'a@r.es', category: 'OWNER', countryOfResidence: 'ES' })
    assertEquals(r.id, 'acct_1')
    const req = s.last()
    assertEquals(req.method, 'POST')
    assertEquals(req.url, 'https://api.stripe.test/v2/core/accounts')
    assertEquals(req.headers.get('Authorization'), 'Bearer sk_test_builder')
    assertEquals(req.headers.get('Stripe-Version'), '2026-07-29.preview')
    assertEquals(req.headers.get('Content-Type'), 'application/json')
    const body = JSON.parse(req.body)
    assertEquals(body.dashboard, 'none')
    assertEquals(body.identity.country, 'ES')
    assertEquals(body.identity.entity_type, 'individual')
    assertEquals(body.configuration.recipient.capabilities.stripe_balance.stripe_transfers.requested, true)
    assertEquals(body.defaults.responsibilities.fees_collector, 'application')
  } finally {
    s.restore()
  }
})

Deno.test('Stripe createNaturalUser(PAYER): POST /v1/customers', async () => {
  const s = stubFetch({ id: 'cus_1' })
  try {
    const c = new StripeEscrowClient(CFG)
    const r = await c.createNaturalUser({ firstName: 'Leo', lastName: 'Paz', email: 'l@p.es', category: 'PAYER' })
    assertEquals(r.id, 'cus_1')
    assertEquals(s.last().url, 'https://api.stripe.test/v1/customers')
    assertStringIncludes(s.last().body, 'email=l%40p.es')
  } finally {
    s.restore()
  }
})

Deno.test('Stripe createBankwirePayIn: PaymentIntent customer_balance/eu_bank_transfer + extrae IBAN', async () => {
  const s = stubFetch({
    id: 'pi_1',
    status: 'requires_action',
    next_action: {
      display_bank_transfer_instructions: {
        reference: 'RF-123',
        financial_addresses: [
          { type: 'iban', iban: { iban: 'ES111', bic: 'BICX', account_holder_name: 'PactStream' } },
        ],
      },
    },
  })
  try {
    const c = new StripeEscrowClient(CFG)
    const r = await c.createBankwirePayIn('cus_1', 'wallet_pact_1', 250000)
    assertEquals(r.id, 'pi_1')
    assertEquals(r.status, 'CREATED') // requires_action → CREATED
    assertEquals(r.iban, 'ES111')
    assertEquals(r.bic, 'BICX')
    assertEquals(r.wireReference, 'RF-123')
    const req = s.last()
    assertEquals(req.url, 'https://api.stripe.test/v1/payment_intents')
    assertStringIncludes(req.body, 'amount=250000')
    assertStringIncludes(req.body, 'customer=cus_1')
    assertStringIncludes(req.body, 'transfer_group=wallet_pact_1')
    assertStringIncludes(req.body, 'payment_method_types%5B0%5D=customer_balance')
    assertStringIncludes(req.body, '%5Bbank_transfer%5D%5Btype%5D=eu_bank_transfer')
    // Regresión (bug detectado en test live): el país del IBAN de fondeo NO es ES
    // (eu_bank_transfer solo admite DE/FR/IE/NL) → debe ser el bankTransferCountry.
    assertStringIncludes(req.body, '%5Beu_bank_transfer%5D%5Bcountry%5D=IE')
  } finally {
    s.restore()
  }
})

Deno.test('Stripe createTransfer: POST /v1/transfers destination=acct', async () => {
  const s = stubFetch({ id: 'tr_1' })
  try {
    const c = new StripeEscrowClient(CFG)
    const r = await c.createTransfer('cus_1', 'wallet_pact_1', 'acct_constructor', 90000)
    assertEquals(r.id, 'tr_1')
    assertEquals(r.status, 'SUCCEEDED')
    const req = s.last()
    assertEquals(req.url, 'https://api.stripe.test/v1/transfers')
    assertStringIncludes(req.body, 'destination=acct_constructor')
    assertStringIncludes(req.body, 'amount=90000')
    assertStringIncludes(req.body, 'currency=eur')
  } finally {
    s.restore()
  }
})

Deno.test('Stripe createBankwirePayout: POST /v1/payouts con cabecera Stripe-Account', async () => {
  const s = stubFetch({ id: 'po_1', status: 'pending' })
  try {
    const c = new StripeEscrowClient(CFG)
    const r = await c.createBankwirePayout('a', 'acct_constructor', 'ba_1', 50000)
    assertEquals(r.id, 'po_1')
    assertEquals(r.status, 'pending')
    const req = s.last()
    assertEquals(req.url, 'https://api.stripe.test/v1/payouts')
    assertEquals(req.headers.get('Stripe-Account'), 'acct_constructor')
    assertStringIncludes(req.body, 'destination=ba_1')
  } finally {
    s.restore()
  }
})

Deno.test('Stripe getWalletBalanceCents: GET /v1/balance con Stripe-Account, filtra EUR', async () => {
  const s = stubFetch({ available: [{ currency: 'usd', amount: 1 }, { currency: 'eur', amount: 4321 }] })
  try {
    const c = new StripeEscrowClient(CFG)
    const bal = await c.getWalletBalanceCents('acct_constructor')
    assertEquals(bal, 4321)
    const req = s.last()
    assertEquals(req.method, 'GET')
    assertStringIncludes(req.url, '/v1/balance')
    assertEquals(req.headers.get('Stripe-Account'), 'acct_constructor')
  } finally {
    s.restore()
  }
})

Deno.test('Stripe getKycLevel: REGULAR solo si payouts_enabled + transfers active', async () => {
  let s = stubFetch({ payouts_enabled: true, capabilities: { transfers: 'active' } })
  try {
    assertEquals(await new StripeEscrowClient(CFG).getKycLevel('acct_1'), 'REGULAR')
  } finally { s.restore() }
  s = stubFetch({ payouts_enabled: false, capabilities: { transfers: 'inactive' } })
  try {
    assertEquals(await new StripeEscrowClient(CFG).getKycLevel('acct_1'), 'LIGHT')
  } finally { s.restore() }
})

Deno.test('Stripe createIbanBankAccount: POST external_accounts con IBAN', async () => {
  const s = stubFetch({ id: 'ba_1' })
  try {
    const c = new StripeEscrowClient(CFG)
    const r = await c.createIbanBankAccount('acct_1', 'Ana Ruiz', 'ES9121000418450200051332', { line1: 'x', city: 'Madrid', postalCode: '28001', country: 'ES' })
    assertEquals(r.id, 'ba_1')
    const req = s.last()
    assertEquals(req.url, 'https://api.stripe.test/v1/accounts/acct_1/external_accounts')
    assertStringIncludes(req.body, 'external_account%5Bobject%5D=bank_account')
    assertStringIncludes(req.body, 'external_account%5Baccount_number%5D=ES9121000418450200051332')
  } finally {
    s.restore()
  }
})

Deno.test('Stripe api(): propaga error con status y cuerpo', async () => {
  const original = globalThis.fetch
  globalThis.fetch = (() => Promise.resolve(new Response('{"error":{"message":"nope"}}', { status: 402 }))) as typeof fetch
  try {
    const c = new StripeEscrowClient(CFG)
    let threw = false
    try {
      await c.createTransfer('a', 'w', 'acct_1', 1)
    } catch (e) {
      threw = true
      assertStringIncludes(String(e), '402')
    }
    assert(threw)
  } finally {
    globalThis.fetch = original
  }
})

// ── Firma de webhook ─────────────────────────────────────────────────────────

Deno.test('webhook: firma válida pasa; alterada o secreto erróneo fallan', async () => {
  const secret = 'whsec_test'
  const body = '{"id":"evt_1","type":"payment_intent.succeeded"}'
  const t = '1700000000'
  const sig = await expectedStripeSignature(body, t, secret)
  const header = `t=${t},v1=${sig}`
  const now = 1700000000 * 1000 // dentro de tolerancia

  assert(await verifyStripeSignature(body, header, secret, 300, now))
  // Cuerpo alterado → falla.
  assert(!(await verifyStripeSignature(body + ' ', header, secret, 300, now)))
  // Secreto erróneo → falla.
  assert(!(await verifyStripeSignature(body, header, 'whsec_wrong', 300, now)))
  // Sin cabecera → falla.
  assert(!(await verifyStripeSignature(body, null, secret, 300, now)))
  // Fuera de tolerancia → falla.
  assert(!(await verifyStripeSignature(body, header, secret, 300, now + 10_000_000)))
})
