import '../../../data/datasources/supabase/supabase_client.dart';
import 'pact_actions_v2.dart' show PactActionException;

/// Resultado de una disputa. Mapea a `p_resolution` de la RPC
/// `sf_resolve_dispute_escrow` (ver migración 20260720000002).
enum DisputeResolution {
  /// Disputa RECHAZADA: gana el constructor, se procede al pago. Hito → `paid`.
  favorConstructor,

  /// Disputa APROBADA: gana el promotor, ajustes antes de liberar.
  /// Hito → `in_execution`.
  favorPromotor,

  /// Resolución parcial: se reparte el escrow según `promotorPct`.
  /// Hito → `in_execution`.
  split,
}

extension DisputeResolutionApi on DisputeResolution {
  String get apiValue => switch (this) {
        DisputeResolution.favorConstructor => 'favor_constructor',
        DisputeResolution.favorPromotor => 'favor_promotor',
        DisputeResolution.split => 'split',
      };

  /// Etiqueta corta para la UI.
  String get label => switch (this) {
        DisputeResolution.favorConstructor => 'Rechazar disputa · pagar',
        DisputeResolution.favorPromotor => 'Aprobar disputa · ajustes',
        DisputeResolution.split => 'Resolución parcial',
      };
}

/// Acciones de resolución de disputas.
///
/// Cierra el callejón sin salida de `disputed`: la RPC reparte el escrow de la
/// disputa Y transiciona el estado del hito (antes solo hacía lo primero, y el
/// hito quedaba en `disputed` para siempre). Solo el técnico o el promotor
/// pueden resolver — lo valida la propia RPC (`SECURITY DEFINER`).
class DisputeActions {
  DisputeActions._();

  /// Resuelve la disputa del hito [milestoneId].
  ///
  /// [promotorPct] (0-100) solo aplica a `split` — es el % del escrow que va al
  /// promotor; en favor_* se ignora (la RPC fuerza 100/0).
  ///
  /// Devuelve el nuevo estado del hito (`'paid'` o `'in_execution'`).
  static Future<String> resolve({
    required String milestoneId,
    required DisputeResolution resolution,
    double promotorPct = 100,
    String? note,
  }) async {
    try {
      final r = await SupabaseConfig.client.rpc(
        'sf_resolve_dispute_escrow',
        params: {
          'p_milestone_id': milestoneId,
          'p_resolution': resolution.apiValue,
          'p_promotor_pct': promotorPct,
          'p_note': note,
        },
      );
      if (r is Map<String, dynamic>) {
        return (r['milestone_new_state'] as String?) ?? '';
      }
      return '';
    } catch (e) {
      throw PactActionException('No se pudo resolver la disputa', e);
    }
  }
}
