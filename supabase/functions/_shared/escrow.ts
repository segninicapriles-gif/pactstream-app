// _shared/escrow.ts
// Abstracción de PROVEEDOR DE ESCROW y factory de selección.
//
// Contexto (21-ago-2026): MangoPay rechazó comercialmente PactStream por banda de
// volumen. Stripe pasa a proveedor principal de escrow (Connect · separate charges
// & transfers). Este módulo define la interfaz común que implementan tanto el
// cliente MangoPay (legado, se conserva compilando) como el nuevo cliente Stripe,
// y un `getEscrowClient()` que elige el proveedor por variable de entorno.
//
// INERTE por defecto: sin credenciales de ningún proveedor y sin flag de
// simulación, `getEscrowClient()` devuelve null y las Edge Functions responden 503.
//
// El VOCABULARIO es el histórico de MangoPay (user/wallet/payin/transfer/payout)
// porque describe el dominio del escrow por hitos; cada proveedor lo mapea a sus
// primitivas (ver `stripe.ts` para el mapeo Stripe).

// Alta del usuario en el proveedor.
//   PAYER  = promotor (solo deposita).  En Stripe → Customer (cus_...).
//   OWNER  = constructor (puede cobrar). En Stripe → Connected Account (acct_...).
export interface NaturalUserInput {
  firstName: string
  lastName: string
  email: string
  category: 'PAYER' | 'OWNER'
  birthday?: number // unix segundos
  nationality?: string // ISO 3166-1 alpha-2, p.ej. 'ES'
  countryOfResidence?: string
}

export interface PayInResult {
  id: string
  status: string
  iban: string
  bic: string
  ownerName: string
  wireReference: string
}

export interface PayInDetail extends PayInResult {
  creditedWalletId: string
  creditedAmountCents: number
  authorId: string
}

export interface WalletRef {
  id: string
  currency: string
}

export interface TxResult {
  id: string
  status: string
}

// Interfaz común. Las firmas son EXACTAMENTE las que consumen las Edge Functions
// de escrow, de modo que cambiar de proveedor no toca ninguna función.
export interface EscrowProvider {
  createNaturalUser(input: NaturalUserInput): Promise<{ id: string }>
  createWallet(ownerId: string, description: string): Promise<{ id: string }>
  createBankwirePayIn(authorId: string, creditedWalletId: string, amountCents: number): Promise<PayInResult>
  getPayIn(payinId: string): Promise<PayInDetail>
  listUserWallets(userId: string): Promise<WalletRef[]>
  getOrCreateEurWallet(userId: string, description: string): Promise<string>
  createTransfer(authorId: string, debitedWalletId: string, creditedWalletId: string, amountCents: number): Promise<TxResult>
  getKycLevel(userId: string): Promise<string>
  getWalletBalanceCents(walletId: string): Promise<number>
  createIbanBankAccount(
    userId: string,
    ownerName: string,
    iban: string,
    address: { line1: string; city: string; postalCode: string; country: string },
  ): Promise<{ id: string }>
  createBankwirePayout(authorId: string, debitedWalletId: string, bankAccountId: string, amountCents: number): Promise<TxResult>
}

// ── Factory ────────────────────────────────────────────────────────────────
import { getMangopayConfig, MangopayClient, MockMangopayClient } from './mangopay.ts'
import { getStripeConfig, MockStripeClient, StripeEscrowClient } from './stripe.ts'

export type EscrowProviderName = 'mock' | 'mangopay' | 'stripe'

// Nombre del proveedor efectivo, para logs/telemetría. NO decide inercia.
export function activeEscrowProvider(): EscrowProviderName {
  const p = (Deno.env.get('ESCROW_PROVIDER') ?? '').toLowerCase()
  if (Deno.env.get('STRIPE_SIMULATE') === 'true' || Deno.env.get('MANGOPAY_SIMULATE') === 'true' || p === 'mock') {
    return 'mock'
  }
  if (p === 'stripe' || p === 'mangopay') return p
  if (getStripeConfig()) return 'stripe'
  if (getMangopayConfig()) return 'mangopay'
  return 'mock'
}

// Cliente de escrow activo, o null si el proveedor real seleccionado no tiene
// credenciales (→ la función responde 503, comportamiento inerte preservado).
//
// Precedencia:
//   1. Simulación explícita (STRIPE_SIMULATE / MANGOPAY_SIMULATE) o ESCROW_PROVIDER=mock
//      → cliente MOCK (flujo E2E sin cuenta ni dinero real). Tras el pivote, el mock
//      por defecto es el de Stripe.
//   2. ESCROW_PROVIDER=stripe|mangopay → cliente real de ese proveedor, o null si faltan creds.
//   3. Sin selección → autodetección por credenciales presentes (Stripe primero).
export function getEscrowClient(): EscrowProvider | null {
  const provider = (Deno.env.get('ESCROW_PROVIDER') ?? '').toLowerCase()

  // 1 · Simulación.
  if (Deno.env.get('STRIPE_SIMULATE') === 'true') return new MockStripeClient()
  if (Deno.env.get('MANGOPAY_SIMULATE') === 'true') return new MockMangopayClient()
  if (provider === 'mock') return new MockStripeClient()

  // 2 · Proveedor real explícito (inerte → null).
  if (provider === 'stripe') {
    const cfg = getStripeConfig()
    return cfg ? new StripeEscrowClient(cfg) : null
  }
  if (provider === 'mangopay') {
    const cfg = getMangopayConfig()
    return cfg ? new MangopayClient(cfg) : null
  }

  // 3 · Autodetección (Stripe primero, tras el pivote).
  const stripeCfg = getStripeConfig()
  if (stripeCfg) return new StripeEscrowClient(stripeCfg)
  const mpCfg = getMangopayConfig()
  if (mpCfg) return new MangopayClient(mpCfg)
  return null
}
