import 'package:flutter/foundation.dart';

import '../../../data/datasources/supabase/supabase_client.dart';

/// Service que encapsula las llamadas a las RPCs de organizaciones.
/// La UI solo trata con métodos tipados; los errores vienen envueltos en
/// `OrgActionException` con el mensaje legible de Postgres ya extraído.
class OrganizationActions {
  OrganizationActions._();

  /// Crear una organización. El caller queda como owner activo.
  static Future<({String orgId, String legalName})> createOrganization({
    required String legalName,
    String? cif,
    String? description,
    String orgType = 'constructor',
  }) async {
    try {
      final rows = await SupabaseConfig.client.rpc(
        'sf_create_organization',
        params: {
          'p_legal_name': legalName.trim(),
          'p_cif': (cif?.trim().isEmpty ?? true) ? null : cif!.trim(),
          'p_description':
              (description?.trim().isEmpty ?? true) ? null : description!.trim(),
          'p_org_type': orgType,
        },
      );
      final row = (rows is List && rows.isNotEmpty)
          ? rows.first as Map<String, dynamic>
          : (rows as Map<String, dynamic>?);
      if (row == null) {
        throw const OrgActionException(
            'La RPC no devolvió ninguna organización', null);
      }
      return (
        orgId: row['out_org_id'] as String,
        legalName: row['out_legal_name'] as String,
      );
    } catch (e) {
      if (e is OrgActionException) rethrow;
      throw OrgActionException('No se pudo crear la organización', e);
    }
  }

  /// Owner invita por email. Devuelve el token de invitación.
  /// Tras crear la fila, dispara la Edge Function `send-org-invite` que
  /// envía el email vía Resend. Si el email falla, la invitación queda
  /// creada igualmente y se puede reenviar manualmente más adelante.
  static Future<({String memberId, String invitationToken, bool emailSent})>
      inviteMember({
    required String orgId,
    required String invitedEmail,
    required String fullName,
    bool canViewEconomics = false,
  }) async {
    String? memberId;
    String? token;
    try {
      final rows = await SupabaseConfig.client.rpc(
        'sf_invite_org_member',
        params: {
          'p_org_id': orgId,
          'p_invited_email': invitedEmail.trim(),
          'p_full_name': fullName.trim(),
          'p_can_view_economics': canViewEconomics,
        },
      );
      final row = (rows is List && rows.isNotEmpty)
          ? rows.first as Map<String, dynamic>
          : (rows as Map<String, dynamic>?);
      if (row == null) {
        throw const OrgActionException('La RPC no devolvió token', null);
      }
      memberId = row['out_member_id'] as String;
      token = row['out_invitation_token'] as String;
    } catch (e) {
      if (e is OrgActionException) rethrow;
      throw OrgActionException('No se pudo invitar al miembro', e);
    }

    // Disparar email vía Edge Function (best-effort: no rompe si falla)
    bool emailSent = false;
    try {
      final r = await SupabaseConfig.client.functions.invoke(
        'send-org-invite',
        body: {'member_id': memberId},
      );
      final data = r.data as Map<String, dynamic>?;
      emailSent = (data?['success'] as bool?) ?? false;
    } catch (e) {
      // No interrumpimos el flujo: la invitación quedó en BD. Solo log.
      if (kDebugMode) {
        debugPrint('Aviso: no se pudo enviar el email de invitación. $e');
      }
    }

    return (memberId: memberId, invitationToken: token, emailSent: emailSent);
  }

  /// Miembro acepta una invitación con el token recibido por email.
  static Future<Map<String, dynamic>> acceptInvite(String token) async {
    try {
      final r = await SupabaseConfig.client.rpc(
        'sf_accept_org_invite',
        params: {'p_invitation_token': token},
      );
      if (r is Map<String, dynamic>) return r;
      throw const OrgActionException('La RPC no devolvió datos', null);
    } catch (e) {
      if (e is OrgActionException) rethrow;
      throw OrgActionException('No se pudo aceptar la invitación', e);
    }
  }

  /// Owner revoca un miembro o cancela una invitación pendiente.
  static Future<void> revokeMember({
    required String memberId,
    String? reason,
  }) async {
    try {
      await SupabaseConfig.client.rpc(
        'sf_revoke_org_member',
        params: {
          'p_member_id': memberId,
          'p_reason': (reason?.trim().isEmpty ?? true) ? null : reason!.trim(),
        },
      );
    } catch (e) {
      throw OrgActionException('No se pudo revocar al miembro', e);
    }
  }

  /// Owner cambia permisos de un miembro activo. Cualquier parámetro
  /// que se pase como `null` conserva su valor actual en BD.
  static Future<void> updateMemberPermissions({
    required String memberId,
    bool? canViewEconomics,
    bool? receiveNotifications,
    bool? receiveEconomicNotifications,
  }) async {
    try {
      await SupabaseConfig.client.rpc(
        'sf_update_member_permissions',
        params: {
          'p_member_id': memberId,
          'p_can_view_economics': canViewEconomics,
          'p_receive_notifications': receiveNotifications,
          'p_receive_economic_notifications': receiveEconomicNotifications,
        },
      );
    } catch (e) {
      throw OrgActionException('No se pudieron actualizar los permisos', e);
    }
  }
}

/// Excepción uniforme para errores de acciones de organización.
class OrgActionException implements Exception {
  const OrgActionException(this.message, this.cause);
  final String message;
  final Object? cause;

  @override
  String toString() {
    final raw = cause?.toString();
    if (raw == null || raw.isEmpty) return message;
    final idx = raw.indexOf('P0001:');
    if (idx >= 0) return '$message: ${raw.substring(idx + 6).trim()}';
    return '$message: $raw';
  }
}
