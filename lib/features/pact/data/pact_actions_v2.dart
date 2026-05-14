import '../../../data/datasources/supabase/supabase_client.dart';

/// Conector único contra las RPCs del modelo v2.0.
///
/// Encapsula las llamadas a Supabase para que la UI solo trate con métodos
/// con tipos limpios y errores ya envueltos en `PactActionException`.
class PactActionsV2 {
  PactActionsV2._();

  // === Promotor ===

  /// Promotor confirma el depósito inicial del pacto (% pactado).
  /// Pact: signed → funded → in_execution.
  static Future<void> fundInitialDeposit(String pactId) async {
    try {
      await SupabaseConfig.client
          .rpc('sf_pact_fund_initial', params: {'p_pact_id': pactId});
    } catch (e) {
      throw PactActionException(
          'No se pudo registrar el depósito inicial', e);
    }
  }

  /// Promotor repone el depósito (importe libre, > 0).
  static Future<int> replenishDeposit({
    required String pactId,
    required int amountCents,
  }) async {
    try {
      final r = await SupabaseConfig.client.rpc(
        'sf_pact_replenish_deposit',
        params: {'p_pact_id': pactId, 'p_amount_cents': amountCents},
      );
      // RPC devuelve jsonb {success, new_balance_cents}
      if (r is Map<String, dynamic> &&
          r['new_balance_cents'] is num) {
        return (r['new_balance_cents'] as num).toInt();
      }
      return 0;
    } catch (e) {
      throw PactActionException('No se pudo reponer el depósito', e);
    }
  }

  // === Constructor ===

  /// Constructor crea una nueva certificación.
  /// Devuelve el id y display_id de la cert creada.
  static Future<({String certId, String displayId, int ordinal})>
      createCertification({
    required String pactId,
    required String name,
    required int amountCents,
    String? description,
  }) async {
    try {
      final rows = await SupabaseConfig.client.rpc(
        'sf_constructor_create_cert',
        params: {
          'p_pact_id': pactId,
          'p_name': name.trim(),
          'p_amount_cents': amountCents,
          'p_description':
              (description?.trim().isEmpty ?? true) ? null : description!.trim(),
        },
      );
      final row = (rows is List && rows.isNotEmpty)
          ? rows.first as Map<String, dynamic>
          : (rows as Map<String, dynamic>?);
      if (row == null) {
        throw const PactActionException(
            'La RPC no devolvió ninguna certificación', null);
      }
      return (
        certId: (row['out_cert_id'] ?? row['id']) as String,
        displayId: (row['out_display_id'] ?? row['display_id']) as String,
        ordinal: ((row['out_ordinal'] ?? row['ordinal']) as num).toInt(),
      );
    } catch (e) {
      if (e is PactActionException) rethrow;
      throw PactActionException('No se pudo crear la certificación', e);
    }
  }

  /// Constructor edita una certificación rechazada/info_requested.
  /// Incrementa la versión y limpia rechazo.
  static Future<void> editCertification({
    required String certId,
    String? name,
    String? description,
    int? amountCents,
  }) async {
    try {
      await SupabaseConfig.client.rpc(
        'sf_constructor_edit_cert',
        params: {
          'p_cert_id': certId,
          if (name != null) 'p_name': name.trim(),
          if (description != null) 'p_description': description.trim(),
          if (amountCents != null) 'p_amount_cents': amountCents,
        },
      );
    } catch (e) {
      throw PactActionException(
          'No se pudo editar la certificación', e);
    }
  }

  // === Anexos ===

  /// Cualquier parte propone un anexo. Doc detallado obligatorio si extra > 10K€.
  static Future<({String addendumId, String displayId, int ordinal})>
      createAddendum({
    required String pactId,
    required String title,
    required int extraAmountCents,
    String? description,
    int extraDays = 0,
    String? justification,
  }) async {
    try {
      final rows = await SupabaseConfig.client.rpc(
        'sf_addendum_create',
        params: {
          'p_pact_id': pactId,
          'p_title': title.trim(),
          'p_extra_amount_cents': extraAmountCents,
          'p_description':
              (description?.trim().isEmpty ?? true) ? null : description!.trim(),
          'p_extra_days': extraDays,
          'p_justification':
              (justification?.trim().isEmpty ?? true) ? null : justification!.trim(),
        },
      );
      final row = (rows is List && rows.isNotEmpty)
          ? rows.first as Map<String, dynamic>
          : (rows as Map<String, dynamic>?);
      if (row == null) {
        throw const PactActionException(
            'La RPC no devolvió ningún anexo', null);
      }
      return (
        addendumId: (row['out_addendum_id'] ?? row['id']) as String,
        displayId: (row['out_display_id'] ?? row['display_id']) as String,
        ordinal: ((row['out_ordinal'] ?? row['ordinal']) as num).toInt(),
      );
    } catch (e) {
      if (e is PactActionException) rethrow;
      throw PactActionException('No se pudo crear el anexo', e);
    }
  }

  /// Cada parte firma el anexo. Cuando todas firman → state='active'.
  /// Devuelve true si tras esta firma el anexo quedó activo.
  static Future<bool> signAddendum(String addendumId) async {
    try {
      final r = await SupabaseConfig.client.rpc(
        'sf_addendum_sign',
        params: {'p_addendum_id': addendumId},
      );
      if (r is Map<String, dynamic>) {
        return (r['active'] as bool?) ?? false;
      }
      return false;
    } catch (e) {
      throw PactActionException('No se pudo firmar el anexo', e);
    }
  }
}

/// Excepción uniforme para errores de acciones del pacto.
/// Envuelve el error original para que la UI pueda mostrar un mensaje claro
/// y los logs sigan teniendo el stacktrace.
class PactActionException implements Exception {
  const PactActionException(this.message, this.cause);
  final String message;
  final Object? cause;

  @override
  String toString() {
    final raw = cause?.toString();
    if (raw == null || raw.isEmpty) return message;
    // Si Postgres devolvió 'P0001: <texto>' nos quedamos solo con el texto.
    final idx = raw.indexOf('P0001:');
    if (idx >= 0) return '$message: ${raw.substring(idx + 6).trim()}';
    return '$message: $raw';
  }
}
