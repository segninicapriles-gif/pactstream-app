import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/error_humanizer.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../data/pact_actions_v2.dart';

// =====================================================================
// Modelo + providers
// =====================================================================

class WalletStatus {
  const WalletStatus({
    required this.configured,
    required this.onboarded,
    required this.kycLevel,
    required this.hasBankAccount,
    required this.balanceCents,
  });

  final bool configured;
  final bool onboarded;
  final String? kycLevel;
  final bool hasBankAccount;
  final int balanceCents;

  bool get kycVerified => kycLevel == 'REGULAR';

  factory WalletStatus.fromMap(Map<String, dynamic> m) => WalletStatus(
        configured: m['configured'] == true,
        onboarded: m['onboarded'] == true,
        kycLevel: m['kyc_level'] as String?,
        hasBankAccount: m['has_bank_account'] == true,
        balanceCents: ((m['balance_cents'] as num?) ?? 0).toInt(),
      );
}

final walletStatusProvider =
    FutureProvider.autoDispose<WalletStatus>((ref) async {
  final res = await SupabaseConfig.client.functions
      .invoke('mangopay-wallet-status', body: {});
  final data = res.data;
  if (data is Map) {
    return WalletStatus.fromMap(Map<String, dynamic>.from(data));
  }
  return const WalletStatus(
    configured: false,
    onboarded: false,
    kycLevel: null,
    hasBankAccount: false,
    balanceCents: 0,
  );
});

final payoutHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseConfig.client
      .from('payouts')
      .select('amount_cents, state, created_at, failure_reason')
      .order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

// =====================================================================
// Pantalla
// =====================================================================

/// Ganancias del constructor: saldo disponible en custodia liberada, estado de
/// cobros (KYC + cuenta bancaria) y retiradas a banco.
class EarningsPage extends ConsumerWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(walletStatusProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text('Ganancias',
            style: AppTypography.h3.copyWith(color: AppColors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletStatusProvider);
          ref.invalidate(payoutHistoryProvider);
          await ref.read(walletStatusProvider.future);
        },
        child: statusAsync.when(
          loading: () => const _EarningsSkeleton(),
          error: (e, _) => _ErrorState(
            message: humanizeError(e),
            onRetry: () => ref.invalidate(walletStatusProvider),
          ),
          data: (status) => _Content(status: status),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.status});

  final WalletStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(payoutHistoryProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _BalanceCard(cents: status.balanceCents, active: status.onboarded),
        const SizedBox(height: AppSpacing.lg),

        if (!status.onboarded)
          const _InfoCard(
            icon: Icons.info_outline,
            title: 'Tu cuenta de cobros aún no está activa',
            body:
                'Se activa automáticamente al recibir tu primera liberación de un hito. '
                'Cuando tengas saldo, aquí podrás retirarlo a tu banco.',
          )
        else ...[
          _StatusRow(
            ok: status.kycVerified,
            okLabel: 'Identidad verificada',
            pendingLabel: 'Verificación de identidad pendiente',
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusRow(
            ok: status.hasBankAccount,
            okLabel: 'Cuenta bancaria registrada',
            pendingLabel: 'Sin cuenta bancaria',
          ),
          const SizedBox(height: AppSpacing.lg),
          _PrimaryAction(status: status),
        ],

        const SizedBox(height: AppSpacing.xl),
        Text('Retiradas',
            style: AppTypography.h3.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        payoutsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(humanizeError(e),
              style: AppTypography.bodyS
                  .copyWith(color: context.colors.textSecondary)),
          data: (rows) => rows.isEmpty
              ? _EmptyPayouts()
              : Column(
                  children: [
                    for (final p in rows) _PayoutTile(row: p),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

// =====================================================================
// CTA principal (depende del estado)
// =====================================================================

class _PrimaryAction extends ConsumerWidget {
  const _PrimaryAction({required this.status});

  final WalletStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sin cuenta bancaria → registrarla primero.
    if (!status.hasBankAccount) {
      return _ActionButton(
        icon: Icons.account_balance_outlined,
        label: 'Registrar cuenta bancaria',
        onPressed: () => _openRegisterBank(context, ref),
      );
    }
    // KYC pendiente → no puede retirar todavía.
    if (!status.kycVerified) {
      return const _InfoCard(
        icon: Icons.hourglass_empty,
        title: 'Verificación pendiente',
        body:
            'Tu identidad se está verificando con nuestro proveedor de pagos. '
            'Podrás retirar en cuanto esté aprobada.',
      );
    }
    // Sin saldo.
    if (status.balanceCents <= 0) {
      return const _InfoCard(
        icon: Icons.savings_outlined,
        title: 'Sin saldo disponible',
        body: 'Cuando se libere un hito, el importe aparecerá aquí para retirar.',
      );
    }
    // Todo listo → retirar.
    return _ActionButton(
      icon: Icons.south_west,
      label: 'Retirar ${AppFormatters.moneyShort(status.balanceCents)} a mi banco',
      onPressed: () => _confirmWithdraw(context, ref, status.balanceCents),
    );
  }

  Future<void> _confirmWithdraw(
      BuildContext context, WidgetRef ref, int cents) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar a tu banco'),
        content: Text(
          'Se transferirán ${AppFormatters.moneyLong(cents)} a tu cuenta bancaria. '
          'La transferencia suele tardar 1-2 días laborables.',
          style: AppTypography.bodyS,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Retirar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PactActionsV2.requestPayout();
      ref.invalidate(walletStatusProvider);
      ref.invalidate(payoutHistoryProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retirada solicitada')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e))),
      );
    }
  }

  Future<void> _openRegisterBank(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _RegisterBankSheet(),
      ),
    );
    if (done == true) {
      ref.invalidate(walletStatusProvider);
    }
  }
}

// =====================================================================
// Piezas de UI
// =====================================================================

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.cents, required this.active});

  final int cents;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.psGradientDeep,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DISPONIBLE PARA RETIRAR',
              style: AppTypography.caption.copyWith(
                color: AppColors.psCyan,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: AppSpacing.xs),
          Text(active ? AppFormatters.moneyLong(cents) : '—',
              style: AppTypography.h1.copyWith(color: AppColors.white)),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.ok,
    required this.okLabel,
    required this.pendingLabel,
  });

  final bool ok;
  final String okLabel;
  final String pendingLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18, color: ok ? AppColors.success : context.colors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Text(ok ? okLabel : pendingLabel,
            style: AppTypography.bodyS.copyWith(
                color: ok
                    ? context.colors.textPrimary
                    : context.colors.textSecondary)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.brandAccentBg,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.colors.brandAccent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.bodyS.copyWith(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body,
                    style: AppTypography.bodyS
                        .copyWith(color: context.colors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final cents = ((row['amount_cents'] as num?) ?? 0).toInt();
    final state = (row['state'] ?? 'pending').toString();
    final created = DateTime.tryParse((row['created_at'] ?? '').toString());

    final (Color color, String label) = switch (state) {
      'succeeded' => (AppColors.success, 'Completada'),
      'failed' => (AppColors.error, 'Fallida'),
      _ => (AppColors.warning, 'En curso'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppFormatters.moneyLong(cents),
                    style: AppTypography.bodyS.copyWith(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600)),
                if (created != null)
                  Text(AppFormatters.dateMedium(created),
                      style: AppTypography.caption
                          .copyWith(color: context.colors.textTertiary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.microAll,
            ),
            child: Text(label,
                style: AppTypography.caption
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmptyPayouts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text('Aún no has hecho ninguna retirada.',
          style: AppTypography.bodyS
              .copyWith(color: context.colors.textSecondary)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Icon(Icons.error_outline,
            size: 40, color: context.colors.textTertiary),
        const SizedBox(height: AppSpacing.md),
        Text(message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyS
                .copyWith(color: context.colors.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: OutlinedButton(
              onPressed: onRetry, child: const Text('Reintentar')),
        ),
      ],
    );
  }
}

class _EarningsSkeleton extends StatelessWidget {
  const _EarningsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.borderSubtle.withValues(alpha: 0.4),
            borderRadius: AppRadius.lgAll,
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [box(120), box(20), box(20), box(48)],
    );
  }
}

// =====================================================================
// Registrar cuenta bancaria
// =====================================================================

class _RegisterBankSheet extends StatefulWidget {
  const _RegisterBankSheet();

  @override
  State<_RegisterBankSheet> createState() => _RegisterBankSheetState();
}

class _RegisterBankSheetState extends State<_RegisterBankSheet> {
  final _owner = TextEditingController();
  final _iban = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _owner.dispose();
    _iban.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final owner = _owner.text.trim();
    final iban = _iban.text.replaceAll(' ', '').trim();
    if (owner.isEmpty || iban.length < 15) {
      setState(() => _error = 'Introduce el titular y un IBAN válido.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PactActionsV2.registerBankAccount(ownerName: owner, iban: iban);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = humanizeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.borderSubtle,
                  borderRadius: AppRadius.xxsAll,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Cuenta bancaria',
                style: AppTypography.h3
                    .copyWith(color: context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.xs),
            Text('Donde recibirás tus retiradas.',
                style: AppTypography.bodyS
                    .copyWith(color: context.colors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _owner,
              decoration: const InputDecoration(
                labelText: 'Titular de la cuenta',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
              enabled: !_loading,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _iban,
              decoration: const InputDecoration(
                labelText: 'IBAN',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 ]')),
              ],
              textCapitalization: TextCapitalization.characters,
              enabled: !_loading,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  style:
                      AppTypography.bodyS.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white))
                  : const Text('Guardar cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
