import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/organization.dart';
import '../../data/organization_actions.dart';

/// Bottom-sheets de gestión de miembros de una organización.
///
/// Cada función devuelve `true` si la acción tuvo éxito; la UI invalida
/// los providers correspondientes para refrescar la lista.

// =====================================================================
// 1 · Crear organización (cuando el user aún no tiene una)
// =====================================================================

Future<bool> showCreateOrgSheet(BuildContext context) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: const _CreateOrgSheet(),
        ),
      ) ??
      false;
}

class _CreateOrgSheet extends StatefulWidget {
  const _CreateOrgSheet();

  @override
  State<_CreateOrgSheet> createState() => _CreateOrgSheetState();
}

class _CreateOrgSheetState extends State<_CreateOrgSheet> {
  final _nameCtrl = TextEditingController();
  final _cifCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _orgType = 'constructor';
  bool _loading = false;
  String? _error;

  // CIF/NIF español: 9 caracteres, letra inicial (CIF) o 8 dígitos + letra (NIF).
  static final _cifRegex = RegExp(r'^[A-Z]\d{7}[A-Z0-9]$|^\d{8}[A-Z]$');

  bool get _cifValid => _cifRegex.hasMatch(_cifCtrl.text.trim().toUpperCase());
  bool get _isValid =>
      _nameCtrl.text.trim().length >= 2 && _cifValid;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cifCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await OrganizationActions.createOrganization(
        legalName: _nameCtrl.text,
        cif: _cifCtrl.text,
        description: _descCtrl.text,
        orgType: _orgType,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Crear organización',
      icon: Icons.business_center_outlined,
      iconColor: context.colors.brandAccent,
      children: [
        Text(
          'Crea tu organización para poder invitar a jefes de obra (constructor) o técnicos del estudio que te ayuden en el día a día.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre legal *',
            hintText: 'Ej: Construcciones Tomato S.L.',
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _cifCtrl,
          decoration: InputDecoration(
            labelText: 'CIF / NIF *',
            hintText: 'Ej: B86800372',
            errorText: _cifCtrl.text.isNotEmpty && !_cifValid
                ? 'Formato no válido (9 caracteres: ej. B86800372 o 12345678Z)'
                : null,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(9),
            _UpperCaseFormatter(),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _orgType,
          decoration: const InputDecoration(labelText: 'Tipo de actividad'),
          items: const [
            DropdownMenuItem(value: 'constructor', child: Text('Constructora')),
            DropdownMenuItem(value: 'tecnico', child: Text('Estudio técnico')),
            DropdownMenuItem(value: 'mixed', child: Text('Mixta')),
          ],
          onChanged: (v) => setState(() => _orgType = v ?? 'constructor'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
            hintText: 'Reformas integrales en Madrid centro…',
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _isValid && !_loading,
          loading: _loading,
          label: 'Crear organización',
          onPressed: _submit,
        ),
      ],
    );
  }
}

// =====================================================================
// 2 · Invitar miembro
// =====================================================================

Future<bool> showInviteMemberSheet(
  BuildContext context, {
  required String orgId,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _InviteMemberSheet(orgId: orgId),
        ),
      ) ??
      false;
}

class _InviteMemberSheet extends StatefulWidget {
  const _InviteMemberSheet({required this.orgId});
  final String orgId;

  @override
  State<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<_InviteMemberSheet> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _canViewEconomics = false;
  bool _loading = false;
  String? _error;
  String? _generatedToken;

  bool get _isValid =>
      _emailCtrl.text.trim().contains('@') &&
      _nameCtrl.text.trim().length >= 2;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await OrganizationActions.inviteMember(
        orgId: widget.orgId,
        invitedEmail: _emailCtrl.text,
        fullName: _nameCtrl.text,
        canViewEconomics: _canViewEconomics,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _generatedToken = r.invitationToken;
      });
      // Espera 1.5 s y cierra (mostrando el "Invitación enviada" estado).
      // En el chunk 4 dispararemos también un email vía Edge Function.
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_generatedToken != null) {
      return _SheetScaffold(
        title: 'Invitación enviada',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_outline,
                  color: AppColors.success, size: 48),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${_nameCtrl.text.trim()} recibirá un email para aceptar la invitación.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: context.colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cuando acepte, podrá empezar a subir evidencias en las obras donde colaboréis.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
        ],
      );
    }

    return _SheetScaffold(
      title: 'Invitar miembro',
      icon: Icons.person_add_outlined,
      iconColor: context.colors.brandAccent,
      children: [
        Text(
          'Invita a un jefe de obra para que pueda subir evidencias de las obras en su dispositivo. No necesita pasar verificación de identidad.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre completo *',
            hintText: 'Ej: Juan García López',
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email *',
            hintText: 'jefe.obra@ejemplo.com',
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: context.colors.chipBg,
            borderRadius: AppRadius.microAll,
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _canViewEconomics,
            onChanged: _loading
                ? null
                : (v) => setState(() => _canViewEconomics = v),
            title: Text('Ver datos económicos',
                style: AppTypography.bodyS
                    .copyWith(fontWeight: FontWeight.w700)),
            subtitle: Text(
              'Si lo activas, este miembro verá importes, presupuestos y movimientos del pacto. Si no, solo verá la información operativa.',
              style: AppTypography.caption.copyWith(color: context.colors.textSecondary),
            ),
          ),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _isValid && !_loading,
          loading: _loading,
          label: 'Enviar invitación',
          onPressed: _submit,
        ),
      ],
    );
  }
}

// =====================================================================
// 3 · Revocar miembro
// =====================================================================

Future<bool> showRevokeMemberSheet(
  BuildContext context, {
  required OrganizationMember member,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _RevokeMemberSheet(member: member),
        ),
      ) ??
      false;
}

class _RevokeMemberSheet extends StatefulWidget {
  const _RevokeMemberSheet({required this.member});
  final OrganizationMember member;

  @override
  State<_RevokeMemberSheet> createState() => _RevokeMemberSheetState();
}

class _RevokeMemberSheetState extends State<_RevokeMemberSheet> {
  final _reasonCtrl = TextEditingController();
  bool _accepted = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await OrganizationActions.revokeMember(
        memberId: widget.member.id,
        reason: _reasonCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final isInvited = m.isPending;
    final title =
        isInvited ? 'Cancelar invitación' : 'Revocar acceso';

    return _SheetScaffold(
      title: title,
      icon: Icons.person_remove_outlined,
      iconColor: AppColors.error,
      children: [
        Text(
          isInvited
              ? '¿Cancelar la invitación pendiente de ${m.displayName} (${m.email})?'
              : 'Vas a revocar el acceso de ${m.displayName} (${m.email}) a tu organización. No podrá seguir subiendo evidencias ni acceder a tus pacts.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!isInvited) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.warningBg,
              borderRadius: AppRadius.microAll,
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Las evidencias que ya subió a obras pasadas siguen siendo válidas y vinculadas a su nombre.',
                    style: AppTypography.caption
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: _reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Ej: Fin del contrato laboral',
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged:
              _loading ? null : (v) => setState(() => _accepted = v ?? false),
          title: Text(
            isInvited
                ? 'Confirmo que quiero cancelar esta invitación.'
                : 'Confirmo que quiero revocar el acceso de este miembro.',
            style: AppTypography.bodyS,
          ),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        ElevatedButton.icon(
          icon: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.white),
                )
              : Icon(isInvited ? Icons.cancel_outlined : Icons.person_remove,
                  size: 18),
          onPressed: (_accepted && !_loading) ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.white,
          ),
          label: Text(_loading
              ? 'Procesando…'
              : (isInvited ? 'Cancelar invitación' : 'Revocar acceso')),
        ),
      ],
    );
  }
}

// =====================================================================
// 4 · Cambiar permisos (can_view_economics)
// =====================================================================

Future<bool> showUpdatePermissionsSheet(
  BuildContext context, {
  required OrganizationMember member,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => _UpdatePermissionsSheet(member: member),
      ) ??
      false;
}

class _UpdatePermissionsSheet extends StatefulWidget {
  const _UpdatePermissionsSheet({required this.member});
  final OrganizationMember member;

  @override
  State<_UpdatePermissionsSheet> createState() =>
      _UpdatePermissionsSheetState();
}

class _UpdatePermissionsSheetState extends State<_UpdatePermissionsSheet> {
  late bool _canViewEconomics = widget.member.canViewEconomics;
  late bool _receiveNotifications = widget.member.receiveNotifications;
  late bool _receiveEconomicNotifications =
      widget.member.receiveEconomicNotifications;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await OrganizationActions.updateMemberPermissions(
        memberId: widget.member.id,
        canViewEconomics: _canViewEconomics,
        receiveNotifications: _receiveNotifications,
        receiveEconomicNotifications: _receiveEconomicNotifications,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Permisos · ${widget.member.displayName}',
      icon: Icons.shield_outlined,
      iconColor: context.colors.brandAccent,
      children: [
        // ── Visibilidad económica ───────────────────────────────────
        _PermissionTile(
          icon: Icons.payments_outlined,
          title: 'Ver datos económicos',
          subtitle: _canViewEconomics
              ? 'Verá importes, presupuestos, certificaciones y movimientos.'
              : 'Solo verá información operativa: evidencias, certificaciones (sin importes), plazos.',
          value: _canViewEconomics,
          onChanged: _loading
              ? null
              : (v) => setState(() {
                    _canViewEconomics = v;
                    // Si desactivamos economics, las notificaciones
                    // económicas también dejan de tener sentido.
                    if (!v) _receiveEconomicNotifications = false;
                  }),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Notificaciones operativas ───────────────────────────────
        _PermissionTile(
          icon: Icons.notifications_active_outlined,
          title: 'Recibir notificaciones',
          subtitle: _receiveNotifications
              ? 'Recibirá avisos cuando se suban evidencias, se envíen hitos a revisión y novedades operativas.'
              : 'No recibirá ningún tipo de aviso de los pactos donde participa la organización.',
          value: _receiveNotifications,
          onChanged: _loading
              ? null
              : (v) => setState(() {
                    _receiveNotifications = v;
                    if (!v) _receiveEconomicNotifications = false;
                  }),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Notificaciones económicas ───────────────────────────────
        // Sólo es relevante si tiene visibilidad económica Y recibe
        // notificaciones operativas. Si no, queda deshabilitado.
        Opacity(
          opacity: (_canViewEconomics && _receiveNotifications) ? 1.0 : 0.5,
          child: _PermissionTile(
            icon: Icons.account_balance_outlined,
            title: 'Avisos económicos',
            subtitle: !_canViewEconomics
                ? 'Requiere haber activado "Ver datos económicos".'
                : !_receiveNotifications
                    ? 'Requiere recibir notificaciones para activarse.'
                    : _receiveEconomicNotifications
                        ? 'Recibirá avisos de pre-depósitos, pagos liberados y movimientos económicos.'
                        : 'No recibirá avisos económicos pero sí los operativos.',
            value: _receiveEconomicNotifications &&
                _canViewEconomics &&
                _receiveNotifications,
            onChanged: (_loading ||
                    !_canViewEconomics ||
                    !_receiveNotifications)
                ? null
                : (v) => setState(() => _receiveEconomicNotifications = v),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AppSpacing.md),
        _PrimaryButton(
          enabled: !_loading,
          loading: _loading,
          label: 'Guardar cambios',
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Tarjeta visual reutilizable para un permiso con switch.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.chipBg,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(icon, size: 18, color: context.colors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTypography.bodyS
                        .copyWith(color: context.colors.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// =====================================================================
// Helpers compartidos
// =====================================================================

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: AppRadius.xxsAll,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(title, style: AppTypography.h3)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.enabled,
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: loading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.white),
            )
          : const Icon(Icons.check, size: 18),
      onPressed: enabled ? onPressed : null,
      label: Text(loading ? 'Procesando…' : label),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.errorBg,
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppColors.error),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyS.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convierte la entrada a mayúsculas en tiempo real.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
