// _shared/stripe.ts
// Cliente REST de Stripe (Connect · separate charges & transfers) que implementa
// EscrowProvider. REST directo (no SDK) por compatibilidad con Deno, mismo criterio
// que la integración MangoPay/InvoCash.
//
// INERTE sin credenciales: getStripeConfig() devuelve null si falta STRIPE_SECRET_KEY.
//
// MAPEO del dominio de escrow por hitos → primitivas Stripe:
//   · createNaturalUser(PAYER)  → Customer (cus_...)         — el promotor deposita.
//   · createNaturalUser(OWNER)  → Connected Account custom   — el constructor cobra.
//                                 (acct_...), payouts en modo MANUAL: el pago solo
//                                 sale cuando PactStream lo libera (escrow real).
//   · createWallet(pact)        → marcador de custodia. En Stripe la custodia son los
//                                 fondos en el BALANCE DE PLATAFORMA, marcados por
//                                 transfer_group = pacto. No hay wallet por-pacto:
//                                 se devuelve un id sintético único (se guarda en el
//                                 pacto por compatibilidad de esquema, no se usa para mover dinero).
//   · createBankwirePayIn       → PaymentIntent (customer_balance · eu_bank_transfer):
//                                 Stripe entrega un IBAN virtual + referencia; el
//                                 promotor transfiere y el ingreso llega al balance de
//                                 plataforma. Confirmación por webhook payment_intent.succeeded.
//   · createTransfer            → Transfer plataforma → cuenta conectada del constructor
//                                 (síncrono). Es la LIBERACIÓN del hito.
//   · createBankwirePayout      → Payout de la cuenta conectada → banco del constructor
//                                 (asíncrono; estado final por webhook payout.paid/failed).
//   · getKycLevel               → 'REGULAR' si la cuenta tiene payouts_enabled + transfers
//                                 activo; 'LIGHT' en otro caso.
//
// Estado (SUCCEEDED/CREATED/PENDING/FAILED) se devuelve con el MISMO vocabulario que
// MangoPay para que las Edge Functions y el webhook no distingan de proveedor.

import type {
  EscrowProvider,
  NaturalUserInput,
  PayInDetail,
  PayInResult,
  TxResult,
  WalletRef,
} from './escrow.ts'

export interface StripeConfig {
  secretKey: string
  baseUrl: string
  connectCountry: string // país de la cuenta conectada del constructor (ISO-2), p.ej. ES
  bankTransferCountry: string // país del IBAN virtual de fondeo (eu_bank_transfer)
  apiVersion: string
}

export function getStripeConfig(): StripeConfig | null {
  const secretKey = Deno.env.get('STRIPE_SECRET_KEY')
  if (!secretKey) return null
  return {
    secretKey,
    baseUrl: Deno.env.get('STRIPE_BASE_URL') ?? 'https://api.stripe.com',
    connectCountry: Deno.env.get('STRIPE_CONNECT_COUNTRY') ?? 'ES',
    // ⚠️ eu_bank_transfer SOLO admite DE/FR/IE/NL como país del IBAN de fondeo
    // (NO ES). SEPA es transfronteriza: el promotor español transfiere sin
    // problema a un IBAN irlandés. Configurable; default IE.
    bankTransferCountry: Deno.env.get('STRIPE_BANK_TRANSFER_COUNTRY') ?? 'IE',
    apiVersion: Deno.env.get('STRIPE_API_VERSION') ?? '2024-06-20',
  }
}

// Codifica un objeto anidado en application/x-www-form-urlencoded con notación de
// corchetes (a[b][c]=v, a[]=v) — el formato que exige la API de Stripe.
export function toForm(obj: Record<string, unknown>, prefix = ''): string {
  const parts: string[] = []
  for (const [key, value] of Object.entries(obj)) {
    if (value === undefined || value === null) continue
    const name = prefix ? `${prefix}[${key}]` : key
    if (Array.isArray(value)) {
      value.forEach((v, i) => {
        if (v !== null && typeof v === 'object') {
          parts.push(toForm(v as Record<string, unknown>, `${name}[${i}]`))
        } else {
          parts.push(`${encodeURIComponent(`${name}[${i}]`)}=${encodeURIComponent(String(v))}`)
        }
      })
    } else if (typeof value === 'object') {
      parts.push(toForm(value as Record<string, unknown>, name))
    } else {
      parts.push(`${encodeURIComponent(name)}=${encodeURIComponent(String(value))}`)
    }
  }
  return parts.filter(Boolean).join('&')
}

// Mapea el estado de un PaymentIntent al vocabulario común del escrow.
export function mapPayInStatus(stripeStatus: string): string {
  switch (stripeStatus) {
    case 'succeeded':
      return 'SUCCEEDED'
    case 'canceled':
      return 'FAILED'
    default: // requires_action | requires_payment_method | processing | requires_confirmation
      return 'CREATED'
  }
}

// ── Verificación de firma de webhook (Stripe-Signature) ─────────────────────
// Stripe firma con HMAC-SHA256 sobre `${t}.${rawBody}`. Factorizado aquí (sin
// top-level serve) para poder testearlo sin arrancar la función.

export async function expectedStripeSignature(rawBody: string, timestamp: string, secret: string): Promise<string> {
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(`${timestamp}.${rawBody}`))
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

// Comparación en tiempo constante de dos hex del mismo largo.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

// Verifica la cabecera `Stripe-Signature` (`t=...,v1=...`). toleranceSec=0 desactiva
// el chequeo de antigüedad (útil en test). nowMs inyectable para test determinista.
export async function verifyStripeSignature(
  rawBody: string,
  sigHeader: string | null,
  secret: string,
  toleranceSec = 300,
  nowMs = Date.now(),
): Promise<boolean> {
  if (!sigHeader) return false
  const fields: Record<string, string> = {}
  for (const part of sigHeader.split(',')) {
    const idx = part.indexOf('=')
    if (idx > 0) fields[part.slice(0, idx).trim()] = part.slice(idx + 1).trim()
  }
  const t = fields['t']
  const v1 = fields['v1']
  if (!t || !v1) return false
  if (toleranceSec > 0) {
    const age = Math.abs(nowMs / 1000 - Number(t))
    if (!Number.isFinite(age) || age > toleranceSec) return false
  }
  const expected = await expectedStripeSignature(rawBody, t, secret)
  return timingSafeEqual(expected, v1)
}

export class StripeEscrowClient implements EscrowProvider {
  protected cfg: StripeConfig

  constructor(cfg: StripeConfig) {
    this.cfg = cfg
  }

  // Petición REST. `stripeAccount` añade la cabecera Stripe-Account (opera EN una
  // cuenta conectada, p.ej. balance/payout del constructor).
  protected async api(
    path: string,
    method: 'GET' | 'POST',
    params?: Record<string, unknown>,
    stripeAccount?: string,
  ): Promise<Record<string, unknown>> {
    const headers: Record<string, string> = {
      'Authorization': `Bearer ${this.cfg.secretKey}`,
      'Stripe-Version': this.cfg.apiVersion,
    }
    if (stripeAccount) headers['Stripe-Account'] = stripeAccount
    let url = `${this.cfg.baseUrl}${path}`
    let body: string | undefined
    if (method === 'POST') {
      headers['Content-Type'] = 'application/x-www-form-urlencoded'
      body = params ? toForm(params) : ''
    } else if (params) {
      const qs = toForm(params)
      if (qs) url += `?${qs}`
    }
    const res = await fetch(url, { method, headers, body })
    const text = await res.text()
    if (!res.ok) {
      throw new Error(`Stripe ${method} ${path} ${res.status}: ${text}`)
    }
    return text ? JSON.parse(text) : {}
  }

  async createNaturalUser(input: NaturalUserInput): Promise<{ id: string }> {
    if (input.category === 'PAYER') {
      // Promotor: solo deposita → Customer.
      const data = await this.api('/v1/customers', 'POST', {
        email: input.email,
        name: `${input.firstName} ${input.lastName}`.trim(),
        metadata: { category: 'PAYER', source: 'pactstream' },
      })
      return { id: String(data.id) }
    }
    // Constructor: puede cobrar → cuenta conectada custom con payouts MANUALES.
    const data = await this.api('/v1/accounts', 'POST', {
      type: 'custom',
      country: input.countryOfResidence ?? this.cfg.connectCountry,
      email: input.email,
      business_type: 'individual',
      capabilities: { transfers: { requested: true } },
      // Payouts manuales: el dinero NO sale de la cuenta conectada hasta que
      // PactStream dispara el payout (control de escrow).
      settings: { payouts: { schedule: { interval: 'manual' } } },
      individual: {
        first_name: input.firstName,
        last_name: input.lastName,
        email: input.email,
      },
      metadata: { category: 'OWNER', source: 'pactstream' },
    })
    return { id: String(data.id) }
  }

  // Marcador de custodia por pacto (ver cabecera). No es una cuenta ni una wallet;
  // sirve solo para poblar pacts.mangopay_wallet_id (columna UNIQUE, opaca) y ligar
  // el pay-in con el pacto por transfer_group.
  createWallet(_ownerId: string, _description: string): Promise<{ id: string }> {
    return Promise.resolve({ id: `stripe_custody_${crypto.randomUUID().slice(0, 12)}` })
  }

  async createBankwirePayIn(
    authorId: string,
    creditedWalletId: string,
    amountCents: number,
  ): Promise<PayInResult> {
    const data = await this.api('/v1/payment_intents', 'POST', {
      amount: amountCents,
      currency: 'eur',
      customer: authorId, // cus_... del promotor (requerido por customer_balance)
      confirm: true,
      transfer_group: creditedWalletId,
      'payment_method_types': ['customer_balance'],
      payment_method_data: { type: 'customer_balance' },
      payment_method_options: {
        customer_balance: {
          funding_type: 'bank_transfer',
          bank_transfer: {
            type: 'eu_bank_transfer',
            eu_bank_transfer: { country: this.cfg.bankTransferCountry },
          },
        },
      },
      metadata: { pact_wallet: creditedWalletId, source: 'pactstream' },
    })
    const instr = this.bankInstructions(data)
    return {
      id: String(data.id),
      status: mapPayInStatus(String(data.status)),
      iban: instr.iban,
      bic: instr.bic,
      ownerName: instr.ownerName,
      wireReference: instr.reference,
    }
  }

  async getPayIn(payinId: string): Promise<PayInDetail> {
    const data = await this.api(`/v1/payment_intents/${payinId}`, 'GET')
    const instr = this.bankInstructions(data)
    return {
      id: String(data.id),
      status: mapPayInStatus(String(data.status)),
      creditedWalletId: String(data.transfer_group ?? ''),
      creditedAmountCents: Number(data.amount_received ?? 0),
      authorId: String(data.customer ?? ''),
      iban: instr.iban,
      bic: instr.bic,
      ownerName: instr.ownerName,
      wireReference: instr.reference,
    }
  }

  // Extrae IBAN/BIC/referencia de las instrucciones de transferencia bancaria del
  // next_action de un PaymentIntent customer_balance.
  protected bankInstructions(pi: Record<string, unknown>): { iban: string; bic: string; ownerName: string; reference: string } {
    const na = (pi.next_action as Record<string, unknown>) ?? {}
    const dbt = (na.display_bank_transfer_instructions as Record<string, unknown>) ?? {}
    const addresses = (dbt.financial_addresses as Array<Record<string, unknown>>) ?? []
    const iban = (addresses.find((a) => a.type === 'iban') ?? {}) as Record<string, unknown>
    const ibanObj = (iban.iban as Record<string, unknown>) ?? {}
    return {
      iban: String(ibanObj.iban ?? ''),
      bic: String(ibanObj.bic ?? ''),
      ownerName: String(ibanObj.account_holder_name ?? 'PactStream Escrow'),
      reference: String(dbt.reference ?? ''),
    }
  }

  listUserWallets(userId: string): Promise<WalletRef[]> {
    // La cuenta conectada del constructor ES su "wallet" EUR.
    return Promise.resolve([{ id: userId, currency: 'EUR' }])
  }

  getOrCreateEurWallet(userId: string, _description: string): Promise<string> {
    // Destino del Transfer = la cuenta conectada del constructor.
    return Promise.resolve(userId)
  }

  async createTransfer(
    _authorId: string,
    _debitedWalletId: string,
    creditedWalletId: string,
    amountCents: number,
  ): Promise<TxResult> {
    // Transfer plataforma → cuenta conectada. Síncrono: si hay saldo, el objeto
    // Transfer devuelto ya está liquidado; si no, la API lanza y propagamos.
    const data = await this.api('/v1/transfers', 'POST', {
      amount: amountCents,
      currency: 'eur',
      destination: creditedWalletId,
      metadata: { source: 'pactstream', kind: 'milestone_release' },
    })
    return { id: String(data.id), status: 'SUCCEEDED' }
  }

  async getKycLevel(userId: string): Promise<string> {
    const data = await this.api(`/v1/accounts/${userId}`, 'GET')
    const caps = (data.capabilities as Record<string, unknown>) ?? {}
    const payoutsEnabled = data.payouts_enabled === true
    const transfersActive = caps.transfers === 'active'
    return payoutsEnabled && transfersActive ? 'REGULAR' : 'LIGHT'
  }

  async getWalletBalanceCents(walletId: string): Promise<number> {
    // Saldo disponible EUR de la cuenta conectada del constructor.
    const data = await this.api('/v1/balance', 'GET', undefined, walletId)
    const available = (data.available as Array<Record<string, unknown>>) ?? []
    const eur = available.find((b) => String(b.currency).toLowerCase() === 'eur')
    return Number(eur?.amount ?? 0)
  }

  async createIbanBankAccount(
    userId: string,
    ownerName: string,
    iban: string,
    address: { line1: string; city: string; postalCode: string; country: string },
  ): Promise<{ id: string }> {
    const data = await this.api(`/v1/accounts/${userId}/external_accounts`, 'POST', {
      external_account: {
        object: 'bank_account',
        country: address.country,
        currency: 'eur',
        account_holder_name: ownerName,
        account_holder_type: 'individual',
        account_number: iban,
      },
    })
    return { id: String(data.id) }
  }

  async createBankwirePayout(
    _authorId: string,
    debitedWalletId: string,
    bankAccountId: string,
    amountCents: number,
  ): Promise<TxResult> {
    // Payout DESDE la cuenta conectada del constructor (Stripe-Account header) hacia
    // su banco. Asíncrono: estado final por webhook.
    const data = await this.api('/v1/payouts', 'POST', {
      amount: amountCents,
      currency: 'eur',
      destination: bankAccountId,
      metadata: { source: 'pactstream' },
    }, debitedWalletId)
    return { id: String(data.id), status: String(data.status ?? 'pending') }
  }
}

// ── Cliente SIMULADO (STRIPE_SIMULATE=true) ─────────────────────────────────
// Prueba el flujo COMPLETO sin cuenta Stripe ni dinero real. Respuestas
// deterministas; nunca llama a la API. Saldo desde STRIPE_SIM_BALANCE_CENTS
// (default 500000 = 5.000 €). NO usar en producción.
export class MockStripeClient extends StripeEscrowClient {
  constructor() {
    super({ secretKey: 'sim', baseUrl: 'sim', connectCountry: 'ES', bankTransferCountry: 'IE', apiVersion: 'sim' })
  }
  private id(prefix: string): string {
    return `${prefix}_${crypto.randomUUID().slice(0, 8)}`
  }
  override createNaturalUser(i: NaturalUserInput): Promise<{ id: string }> {
    return Promise.resolve({ id: this.id(i.category === 'OWNER' ? 'acct' : 'cus') })
  }
  override createWallet(_o: string, _d: string): Promise<{ id: string }> {
    return Promise.resolve({ id: this.id('stripe_custody') })
  }
  override createBankwirePayIn(_a: string, _w: string, _c: number): Promise<PayInResult> {
    return Promise.resolve({
      id: this.id('pi'),
      status: 'CREATED',
      iban: 'ES9121000418450200051332',
      bic: 'CAIXESBBXXX',
      ownerName: 'PactStream Escrow (SIMULADO)',
      wireReference: this.id('SIM'),
    })
  }
  override getPayIn(payinId: string): Promise<PayInDetail> {
    return Promise.resolve({
      id: payinId,
      status: 'SUCCEEDED',
      creditedWalletId: 'stripe_custody_sim',
      creditedAmountCents: 0,
      authorId: 'cus_sim',
      iban: 'ES9121000418450200051332',
      bic: 'CAIXESBBXXX',
      ownerName: 'PactStream Escrow (SIMULADO)',
      wireReference: 'SIM',
    })
  }
  override listUserWallets(userId: string): Promise<WalletRef[]> {
    return Promise.resolve([{ id: userId || 'acct_sim', currency: 'EUR' }])
  }
  override getOrCreateEurWallet(userId: string, _d: string): Promise<string> {
    return Promise.resolve(userId || 'acct_sim')
  }
  override createTransfer(_a: string, _d: string, _c: string, _amt: number): Promise<TxResult> {
    return Promise.resolve({ id: this.id('tr'), status: 'SUCCEEDED' })
  }
  override getKycLevel(_u: string): Promise<string> {
    return Promise.resolve('REGULAR')
  }
  override getWalletBalanceCents(_w: string): Promise<number> {
    return Promise.resolve(Number(Deno.env.get('STRIPE_SIM_BALANCE_CENTS') ?? '500000'))
  }
  override createIbanBankAccount(
    _u: string,
    _o: string,
    _i: string,
    _a: { line1: string; city: string; postalCode: string; country: string },
  ): Promise<{ id: string }> {
    return Promise.resolve({ id: this.id('ba') })
  }
  override createBankwirePayout(_a: string, _w: string, _b: string, _amt: number): Promise<TxResult> {
    return Promise.resolve({ id: this.id('po'), status: 'pending' })
  }
}
