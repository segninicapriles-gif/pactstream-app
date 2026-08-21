// _shared/mangopay.ts
// Cliente REST de Mangopay + abstracción de proveedor de escrow.
//
// INERTE sin credenciales: `getMangopayClient()` devuelve null si faltan
// MANGOPAY_CLIENT_ID / MANGOPAY_API_KEY, y las funciones que lo usan responden
// 503. REST directo (no SDK) por compatibilidad con Deno — mismo criterio que
// la integración InvoCash/Verifactu de CostPact.
//
// Entorno: sandbox por defecto (`api.sandbox.mangopay.com`). NUNCA apuntar a
// producción sin haber verificado el flujo completo contra sandbox.

import type { EscrowProvider, NaturalUserInput } from './escrow.ts'
// Se conserva el nombre por compatibilidad con imports previos.
export type { NaturalUserInput } from './escrow.ts'

export interface MangopayConfig {
  clientId: string
  apiKey: string
  baseUrl: string
}

export function getMangopayConfig(): MangopayConfig | null {
  const clientId = Deno.env.get('MANGOPAY_CLIENT_ID')
  const apiKey = Deno.env.get('MANGOPAY_API_KEY')
  if (!clientId || !apiKey) return null
  const baseUrl = Deno.env.get('MANGOPAY_BASE_URL') ?? 'https://api.sandbox.mangopay.com'
  return { clientId, apiKey, baseUrl }
}

export class MangopayClient implements EscrowProvider {
  private cfg: MangopayConfig
  private cachedToken: { value: string; expiresAt: number } | null = null

  constructor(cfg: MangopayConfig) {
    this.cfg = cfg
  }

  // OAuth2 client_credentials. Cachea el token hasta ~30s antes de expirar.
  private async token(): Promise<string> {
    const now = Date.now()
    if (this.cachedToken && this.cachedToken.expiresAt > now + 30_000) {
      return this.cachedToken.value
    }
    const basic = btoa(`${this.cfg.clientId}:${this.cfg.apiKey}`)
    const res = await fetch(`${this.cfg.baseUrl}/v2.01/oauth/token`, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${basic}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    })
    if (!res.ok) {
      throw new Error(`Mangopay OAuth ${res.status}: ${await res.text()}`)
    }
    const data = await res.json()
    this.cachedToken = {
      value: data.access_token,
      expiresAt: now + (Number(data.expires_in ?? 3600) * 1000),
    }
    return this.cachedToken.value
  }

  private async api(path: string, method: string, body?: unknown): Promise<Record<string, unknown>> {
    const token = await this.token()
    const res = await fetch(`${this.cfg.baseUrl}/v2.01/${this.cfg.clientId}${path}`, {
      method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: body ? JSON.stringify(body) : undefined,
    })
    const text = await res.text()
    if (!res.ok) {
      throw new Error(`Mangopay ${method} ${path} ${res.status}: ${text}`)
    }
    return text ? JSON.parse(text) : {}
  }

  async createNaturalUser(input: NaturalUserInput): Promise<{ id: string }> {
    const payload: Record<string, unknown> = {
      FirstName: input.firstName,
      LastName: input.lastName,
      Email: input.email,
      UserCategory: input.category,
      TermsAndConditionsAccepted: true,
    }
    if (input.category === 'OWNER') {
      payload.Birthday = input.birthday
      payload.Nationality = input.nationality
      payload.CountryOfResidence = input.countryOfResidence
    }
    const data = await this.api('/users/natural', 'POST', payload)
    return { id: String(data.Id) }
  }

  // Wallet EUR propiedad del usuario. Se usará en la Fase 2.1 (pay-in / custodia
  // por pacto). No se llama en el onboarding para no dejar wallets huérfanas.
  async createWallet(ownerId: string, description: string): Promise<{ id: string }> {
    const data = await this.api('/wallets', 'POST', {
      Owners: [ownerId],
      Description: description,
      Currency: 'EUR',
    })
    return { id: String(data.Id) }
  }

  // Bankwire PayIn (transferencia): Mangopay devuelve un IBAN dedicado + una
  // referencia (WireReference). El promotor transfiere ahí; el ingreso se
  // confirma por webhook. Método idóneo para importes grandes de obra.
  async createBankwirePayIn(
    authorId: string,
    creditedWalletId: string,
    amountCents: number,
  ): Promise<{ id: string; status: string; iban: string; bic: string; ownerName: string; wireReference: string }> {
    const data = await this.api('/payins/bankwire/direct', 'POST', {
      AuthorId: authorId,
      CreditedWalletId: creditedWalletId,
      DeclaredDebitedFunds: { Amount: amountCents, Currency: 'EUR' },
      DeclaredFees: { Amount: 0, Currency: 'EUR' },
    })
    const ba = (data.BankAccount as Record<string, unknown>) ?? {}
    return {
      id: String(data.Id),
      status: String(data.Status),
      iban: String(ba.IBAN ?? ''),
      bic: String(ba.BIC ?? ''),
      ownerName: String(ba.OwnerName ?? ''),
      wireReference: String(data.WireReference ?? ''),
    }
  }

  // Re-consulta un pay-in (para verificar en el webhook, ya que Mangopay no
  // firma con HMAC: la fuente de verdad es el propio recurso en su API).
  async getPayIn(payinId: string): Promise<{ id: string; status: string; creditedWalletId: string; creditedAmountCents: number; authorId: string; iban: string; bic: string; ownerName: string; wireReference: string }> {
    const data = await this.api(`/payins/${payinId}`, 'GET')
    const credited = (data.CreditedFunds as Record<string, unknown>) ?? {}
    const ba = (data.BankAccount as Record<string, unknown>) ?? {}
    return {
      id: String(data.Id),
      status: String(data.Status),
      creditedWalletId: String(data.CreditedWalletId ?? ''),
      creditedAmountCents: Number(credited.Amount ?? 0),
      authorId: String(data.AuthorId ?? ''),
      iban: String(ba.IBAN ?? ''),
      bic: String(ba.BIC ?? ''),
      ownerName: String(ba.OwnerName ?? ''),
      wireReference: String(data.WireReference ?? ''),
    }
  }

  async listUserWallets(userId: string): Promise<Array<{ id: string; currency: string }>> {
    const data: unknown = await this.api(`/users/${userId}/wallets`, 'GET')
    const arr = Array.isArray(data) ? data : []
    return arr.map((w: Record<string, unknown>) => ({
      id: String(w.Id),
      currency: String(w.Currency),
    }))
  }

  // Wallet EUR del usuario (la primera que exista) o una nueva. Se usa para la
  // wallet destino del constructor en el release, sin necesidad de columna.
  async getOrCreateEurWallet(userId: string, description: string): Promise<string> {
    const wallets = await this.listUserWallets(userId)
    const eur = wallets.find((w) => w.currency === 'EUR')
    if (eur) return eur.id
    const created = await this.createWallet(userId, description)
    return created.id
  }

  // Transfer wallet→wallet (SÍNCRONO: la respuesta trae ya el Status final).
  // AuthorId debe ser el propietario de la wallet debitada (el promotor).
  async createTransfer(
    authorId: string,
    debitedWalletId: string,
    creditedWalletId: string,
    amountCents: number,
  ): Promise<{ id: string; status: string }> {
    const data = await this.api('/transfers', 'POST', {
      AuthorId: authorId,
      DebitedWalletId: debitedWalletId,
      CreditedWalletId: creditedWalletId,
      DebitedFunds: { Amount: amountCents, Currency: 'EUR' },
      Fees: { Amount: 0, Currency: 'EUR' },
    })
    return { id: String(data.Id), status: String(data.Status) }
  }

  // === Fase 2.3 · cash-out a banco (PayOut) ===

  // Nivel KYC del usuario: 'LIGHT' | 'REGULAR'. El PayOut exige 'REGULAR'.
  async getKycLevel(userId: string): Promise<string> {
    const data = await this.api(`/users/${userId}`, 'GET')
    return String(data.KYCLevel ?? 'LIGHT')
  }

  async getWalletBalanceCents(walletId: string): Promise<number> {
    const data = await this.api(`/wallets/${walletId}`, 'GET')
    const bal = (data.Balance as Record<string, unknown>) ?? {}
    return Number(bal.Amount ?? 0)
  }

  // Registra una cuenta bancaria IBAN del usuario (destino del payout).
  async createIbanBankAccount(
    userId: string,
    ownerName: string,
    iban: string,
    address: { line1: string; city: string; postalCode: string; country: string },
  ): Promise<{ id: string }> {
    const data = await this.api(`/users/${userId}/bankaccounts/iban`, 'POST', {
      OwnerName: ownerName,
      IBAN: iban,
      OwnerAddress: {
        AddressLine1: address.line1,
        City: address.city,
        PostalCode: address.postalCode,
        Country: address.country,
      },
    })
    return { id: String(data.Id) }
  }

  // PayOut Bankwire wallet→banco (ASÍNCRONO: liquida en 1-2 días; el estado
  // final llega por webhook PAYOUT_NORMAL_*).
  async createBankwirePayout(
    authorId: string,
    debitedWalletId: string,
    bankAccountId: string,
    amountCents: number,
  ): Promise<{ id: string; status: string }> {
    const data = await this.api('/payouts/bankwire', 'POST', {
      AuthorId: authorId,
      DebitedWalletId: debitedWalletId,
      DebitedFunds: { Amount: amountCents, Currency: 'EUR' },
      Fees: { Amount: 0, Currency: 'EUR' },
      BankAccountId: bankAccountId,
      BankWireRef: 'PactStream payout',
    })
    return { id: String(data.Id), status: String(data.Status) }
  }
}

// ── Cliente SIMULADO (MANGOPAY_SIMULATE=true) ──────────────────────────────
// Para probar el flujo COMPLETO sin cuenta Mangopay ni dinero real. Sobrescribe
// todos los métodos públicos con respuestas deterministas; nunca llama a la API
// real (no usa token()/api()). El saldo de wallet lo fija MANGOPAY_SIM_BALANCE_CENTS
// (por defecto 500000 = 5.000 €). NO usar en producción.
export class MockMangopayClient extends MangopayClient {
  constructor() {
    super({ clientId: 'sim', apiKey: 'sim', baseUrl: 'sim' })
  }
  private id(prefix: string): string {
    return `${prefix}_${crypto.randomUUID().slice(0, 8)}`
  }
  override createNaturalUser(_i: NaturalUserInput): Promise<{ id: string }> {
    return Promise.resolve({ id: this.id('sim_user') })
  }
  override createWallet(_o: string, _d: string): Promise<{ id: string }> {
    return Promise.resolve({ id: this.id('sim_wallet') })
  }
  override createBankwirePayIn(_a: string, _w: string, _c: number) {
    return Promise.resolve({
      id: this.id('sim_payin'), status: 'CREATED',
      iban: 'ES9121000418450200051332', bic: 'CAIXESBBXXX',
      ownerName: 'PactStream Escrow (SIMULADO)', wireReference: this.id('SIM'),
    })
  }
  override getPayIn(payinId: string) {
    return Promise.resolve({
      id: payinId, status: 'SUCCEEDED', creditedWalletId: 'sim_wallet_eur',
      creditedAmountCents: 0, authorId: 'sim_user',
      iban: 'ES9121000418450200051332', bic: 'CAIXESBBXXX',
      ownerName: 'PactStream Escrow (SIMULADO)', wireReference: 'SIM',
    })
  }
  override listUserWallets(_u: string) {
    return Promise.resolve([{ id: 'sim_wallet_eur', currency: 'EUR' }])
  }
  override getOrCreateEurWallet(_u: string, _d: string): Promise<string> {
    return Promise.resolve('sim_wallet_eur')
  }
  override createTransfer(_a: string, _d: string, _c: string, _amt: number) {
    return Promise.resolve({ id: this.id('sim_transfer'), status: 'SUCCEEDED' })
  }
  override getKycLevel(_u: string): Promise<string> {
    return Promise.resolve('REGULAR') // verificado → permite payout
  }
  override getWalletBalanceCents(_w: string): Promise<number> {
    return Promise.resolve(Number(Deno.env.get('MANGOPAY_SIM_BALANCE_CENTS') ?? '500000'))
  }
  override createIbanBankAccount(
    _u: string, _o: string, _i: string,
    _a: { line1: string; city: string; postalCode: string; country: string },
  ): Promise<{ id: string }> {
    return Promise.resolve({ id: this.id('sim_bank') })
  }
  override createBankwirePayout(_a: string, _w: string, _b: string, _amt: number) {
    return Promise.resolve({ id: this.id('sim_payout'), status: 'SUCCEEDED' })
  }
}

export function getMangopayClient(): MangopayClient | null {
  if (Deno.env.get('MANGOPAY_SIMULATE') === 'true') return new MockMangopayClient()
  const cfg = getMangopayConfig()
  return cfg ? new MangopayClient(cfg) : null
}
