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

  /// v2.1 · Promotor configura el Adelanto.
  /// Devuelve el desglose ejecutado (lo entregado al constructor + la reserva).
  static Future<({int releasedCents, int reserveCents})> setupAdvance(
      String pactId) async {
    try {
      final r = await SupabaseConfig.client
          .rpc('sf_pact_setup_advance', params: {'p_pact_id': pactId});
      if (r is Map<String, dynamic>) {
        return (
          releasedCents:
              ((r['released_to_constructor_cents'] as num?) ?? 0).toInt(),
          reserveCents: ((r['reserve_custody_cents'] as num?) ?? 0).toInt(),
        );
      }
      return (releasedCents: 0, reserveCents: 0);
    } catch (e) {
      throw PactActionException('No se pudo configurar el Adelanto', e);
    }
  }

  /// v2.1 · Promotor pre-deposita el neto de una certificación.
  /// Devuelve si el pre-depósito quedó completo (cert pasa a `in_execution`).
  static Future<bool> predepositMilestone({
    required String milestoneId,
    required int amountCents,
  }) async {
    try {
      final r = await SupabaseConfig.client.rpc(
        'sf_pact_predeposit_milestone',
        params: {
          'p_milestone_id': milestoneId,
          'p_amount_cents': amountCents,
        },
      );
      if (r is Map<String, dynamic>) {
        return (r['completed'] as bool?) ?? false;
      }
      return false;
    } catch (e) {
      throw PactActionException('No se pudo pre-depositar', e);
    }
  }

  /// v2.1 · Constructor activa "avanzar bajo responsabilidad".
  /// Requiere disclaimerAccepted=true por seguridad.
  static Future<void> forceAdvanceMilestone({
    required String milestoneId,
    required bool disclaimerAccepted,
  }) async {
    try {
      await SupabaseConfig.client.rpc(
        'sf_milestone_force_advance',
        params: {
          'p_milestone_id': milestoneId,
          'p_disclaimer_accepted': disclaimerAccepted,
        },
      );
    } catch (e) {
      throw PactActionException(
          'No se pudo activar el avance bajo responsabilidad', e);
    }
  }

  /// Inicia el depósito inicial vía Mangopay (Bankwire PayIn, sandbox).
  /// Devuelve los datos bancarios para que el promotor transfiera. El fondeo
  /// se confirma DESPUÉS por webhook (no aquí): esto solo genera el IBAN.
  static Future<MangopayPayinDetails> startMangopayPayin(String pactId) async {
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        'escrow-payin',
        body: {'pact_id': pactId},
      );
      final data = res.data;
      if (data is Map) {
        return MangopayPayinDetails(
          payinId: (data['payin_id'] ?? '').toString(),
          iban: (data['iban'] ?? '').toString(),
          bic: (data['bic'] ?? '').toString(),
          ownerName: (data['owner_name'] ?? '').toString(),
          wireReference: (data['wire_reference'] ?? '').toString(),
          amountCents: ((data['amount_cents'] as num?) ?? 0).toInt(),
        );
      }
      throw const PactActionException('Respuesta inesperada del servidor', null);
    } catch (e) {
      if (e is PactActionException) rethrow;
      throw PactActionException('No se pudo iniciar el depósito de custodia', e);
    }
  }

  /// Libera un hito vía Mangopay (Transfer escrow→constructor, sandbox).
  /// Solo se usa en modo ESCROW_PROVIDER=mangopay; el mock usa
  /// `promotorDecideMilestone`. El decremento de custodia + 'paid' los hace la
  /// Edge Function tras un Transfer real.
  static Future<void> releaseMilestone(String milestoneId) async {
    try {
      await SupabaseConfig.client.functions.invoke(
        'escrow-release',
        body: {'milestone_id': milestoneId},
      );
    } catch (e) {
      throw PactActionException('No se pudo liberar el hito', e);
    }
  }

  /// Puente cert→factura: pide a CostPact que emita la factura Verifactu de un
  /// hito aprobado. NO bloqueante — traga cualquier error para no afectar a la
  /// aprobación (el servidor loguea; la emisión es idempotente y reintentar es
  /// seguro).
  static Future<void> emitInvoiceForMilestone(String milestoneId) async {
    try {
      await SupabaseConfig.client.functions.invoke(
        'bridge-emit-invoice',
        body: {'milestone_id': milestoneId},
      );
    } catch (_) {
      // Silencioso a propósito: la factura no debe romper la aprobación.
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

  /// Fase 2.3 · El constructor registra su cuenta bancaria (destino del payout).
  static Future<void> registerBankAccount({
    required String ownerName,
    required String iban,
    String line1 = '—',
    String city = '—',
    String postalCode = '00000',
    String country = 'ES',
  }) async {
    try {
      await SupabaseConfig.client.functions.invoke(
        'escrow-bank-account',
        body: {
          'owner_name': ownerName,
          'iban': iban,
          'address': {
            'line1': line1,
            'city': city,
            'postal_code': postalCode,
            'country': country,
          },
        },
      );
    } catch (e) {
      throw PactActionException('No se pudo registrar la cuenta bancaria', e);
    }
  }

  /// Fase 2.3 · El constructor retira su saldo Mangopay a su banco.
  /// Sin `amountCents`, retira todo el saldo disponible. Devuelve el importe.
  static Future<int> requestPayout({int? amountCents}) async {
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        'escrow-payout',
        body: amountCents == null ? {} : {'amount_cents': amountCents},
      );
      final data = res.data;
      if (data is Map && data['amount_cents'] is num) {
        return (data['amount_cents'] as num).toInt();
      }
      return 0;
    } catch (e) {
      throw PactActionException('No se pudo solicitar la retirada', e);
    }
  }

  /// El constructor inicia (o reanuda) su verificación de identidad para cobros.
  ///
  /// El backend asegura su cuenta conectada del proveedor de escrow (la crea si aún
  /// no existe) y devuelve la URL de un onboarding ALOJADO de un solo uso. La app la
  /// abre en el navegador; al volver NO hay callback directo, así que el estado
  /// ('verificado') se refleja al reconsultar `escrow-wallet-status`.
  static Future<String> startEscrowOnboarding({String country = 'ES'}) async {
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        'escrow-onboard-link',
        body: {'country': country},
      );
      final data = res.data;
      if (data is Map &&
          data['url'] is String &&
          (data['url'] as String).isNotEmpty) {
        return data['url'] as String;
      }
      throw const PactActionException('Respuesta inesperada del servidor', null);
    } catch (e) {
      if (e is PactActionException) rethrow;
      throw PactActionException(
          'No se pudo iniciar la verificación de cobros', e);
    }
  }

  // === Constructor ===

  /// Constructor crea una nueva certificación.
  /// Devuelve el id y display_id de la cert creada.
  ///
  /// Enruta automáticamente a la RPC correcta según `modelVersion`:
  ///   - 'v2.1' → sf_constructor_create_cert_v21 (con amortización y deadline)
  ///   - 'v2'   → sf_constructor_create_cert (v2.0 original)
  static Future<({String certId, String displayId, int ordinal})>
      createCertification({
    required String pactId,
    required String name,
    required int amountCents,
    String? description,
    String modelVersion = 'v2',
  }) async {
    final rpcName = modelVersion == 'v2.1'
        ? 'sf_constructor_create_cert_v21'
        : 'sf_constructor_create_cert';
    try {
      final rows = await SupabaseConfig.client.rpc(
        rpcName,
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

/// Datos bancarios de un Bankwire PayIn de Mangopay, para mostrar al promotor.
class MangopayPayinDetails {
  const MangopayPayinDetails({
    required this.payinId,
    required this.iban,
    required this.bic,
    required this.ownerName,
    required this.wireReference,
    required this.amountCents,
  });

  final String payinId;
  final String iban;
  final String bic;
  final String ownerName;
  final String wireReference;
  final int amountCents;
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
