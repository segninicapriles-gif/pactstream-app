import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/supabase/supabase_client.dart';
import 'evidence_uploader.dart';
import 'milestone_detail.dart';
import 'pact_detail.dart';
import 'pact_summary.dart';

/// Repositorio de pactos. Encapsula las llamadas a las RPCs de Supabase.
class PactsRepository {
  PactsRepository();

  /// Dispara la Edge Function `email-sender` para drenar la cola de emails.
  /// Se llama tras acciones que generan notificaciones (invitar, firmar, validar, pagar...).
  /// Fire-and-forget: si falla, el cron lo recogerá. Nunca bloqueamos el flow del user.
  Future<void> kickEmailSender() async {
    try {
      await SupabaseConfig.client.functions.invoke('email-sender');
    } catch (_) {
      // ignoramos errores intencionalmente
    }
  }

  /// Lista los pactos del usuario autenticado.
  Future<List<PactSummary>> listMyPacts() async {
    final rows = await SupabaseConfig.client.rpc('sf_list_my_pacts');
    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(PactSummary.fromRpcRow)
        .toList(growable: false);
  }

  /// Detalle completo del pacto. Lanza si el caller no es parte.
  Future<PactDetail> getPactDetail(String pactId) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_get_pact_detail',
      params: {'p_pact_id': pactId},
    );
    if (raw == null) {
      throw Exception('No se pudo cargar el detalle del pacto.');
    }
    return PactDetail.fromJson(raw as Map<String, dynamic>);
  }

  /// El usuario actual acepta su parte del pacto. Si tras esta llamada
  /// todas las partes han aceptado, el pact pasa a 'signing'.
  Future<Map<String, dynamic>> acceptInvitation(String pactId) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_accept_invitation',
      params: {'p_pact_id': pactId},
    );
    kickEmailSender();
    return (raw as Map<String, dynamic>);
  }

  /// El usuario firma el contrato. Si todas las partes firmaron,
  /// el pact pasa a 'signed'.
  Future<Map<String, dynamic>> signContract({
    required String pactId,
    required String consentTextHash,
    required String userAgent,
  }) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_sign_contract',
      params: {
        'p_pact_id': pactId,
        'p_consent_text_hash': consentTextHash,
        'p_user_agent': userAgent,
      },
    );
    kickEmailSender();
    return (raw as Map<String, dynamic>);
  }

  // === EVIDENCIAS Y EJECUCIÓN ===

  /// DEV ONLY. Mock del depósito Mangopay. Mueve pact a 'in_execution'
  /// y arranca el primer hito. Sustituir por integración real cuando
  /// llegue chunk 5 (Mangopay).
  Future<Map<String, dynamic>> mockFundPact(String pactId) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_mock_fund_pact',
      params: {'p_pact_id': pactId},
    );
    kickEmailSender();
    return (raw as Map<String, dynamic>);
  }

  /// Detalle de un hito + evidencias.
  Future<MilestoneDetail> getMilestoneDetail(String milestoneId) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_get_milestone_detail',
      params: {'p_milestone_id': milestoneId},
    );
    if (raw == null) {
      throw Exception('No se pudo cargar el hito.');
    }
    return MilestoneDetail.fromJson(raw as Map<String, dynamic>);
  }

  /// Registra evidencia en BD tras subirla a Storage.
  /// Devuelve el id de la evidencia creada.
  Future<String> recordMilestoneEvidence({
    required String milestoneId,
    required String evidenceType,
    required String storagePath,
    required String sha256Hash,
    int? fileSizeBytes,
    String? mimeType,
    String? description,
    double? gpsLatitude,
    double? gpsLongitude,
    double? gpsAccuracyMeters,
    DateTime? clientTimestamp,
  }) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_record_milestone_evidence',
      params: {
        'p_milestone_id': milestoneId,
        'p_evidence_type': evidenceType,
        'p_storage_path': storagePath,
        'p_sha256_hash': sha256Hash,
        'p_file_size_bytes': fileSizeBytes,
        'p_mime_type': mimeType,
        'p_description': description,
        'p_gps_latitude': gpsLatitude,
        'p_gps_longitude': gpsLongitude,
        'p_gps_accuracy_meters': gpsAccuracyMeters,
        'p_client_timestamp': clientTimestamp?.toIso8601String(),
      },
    );
    return raw as String;
  }

  /// El constructor declara que el hito está listo para revisión.
  Future<Map<String, dynamic>> submitMilestoneForReview(
      String milestoneId) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_submit_milestone_for_review',
      params: {'p_milestone_id': milestoneId},
    );
    kickEmailSender();
    return (raw as Map<String, dynamic>);
  }

  /// Técnico (obra mayor) decide sobre el hito.
  /// decision ∈ {'approve', 'reject', 'request_info'}
  Future<Map<String, dynamic>> techReviewMilestone({
    required String milestoneId,
    required String decision,
    String? rationale,
  }) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_milestone_tech_review',
      params: {
        'p_milestone_id': milestoneId,
        'p_decision': decision,
        'p_rationale': rationale,
      },
    );
    kickEmailSender();
    return (raw as Map<String, dynamic>);
  }

  /// Promotor decide sobre el hito.
  /// decision ∈ {'approve', 'dispute'}
  /// En obra mayor: desde awaiting_promotor.
  /// En obra menor: desde ready_for_review (hace cascada hasta paid).
  Future<Map<String, dynamic>> promotorDecideMilestone({
    required String milestoneId,
    required String decision,
    String? rationale,
  }) async {
    final raw = await SupabaseConfig.client.rpc(
      'sf_milestone_promotor_decide',
      params: {
        'p_milestone_id': milestoneId,
        'p_decision': decision,
        'p_rationale': rationale,
      },
    );
    kickEmailSender();
    return (raw as Map<String, dynamic>);
  }
}

/// Provider del repositorio. Singleton.
final pactsRepositoryProvider =
    Provider<PactsRepository>((ref) => PactsRepository());

/// Provider de la lista de pactos del usuario actual.
/// Auto-recarga cuando se invalida.
final myPactsProvider = FutureProvider<List<PactSummary>>((ref) {
  return ref.watch(pactsRepositoryProvider).listMyPacts();
});

/// Provider del detalle de un pacto específico. Family por pactId.
final pactDetailProvider =
    FutureProvider.family<PactDetail, String>((ref, pactId) {
  return ref.watch(pactsRepositoryProvider).getPactDetail(pactId);
});

/// Provider del uploader de evidencias. Singleton.
final evidenceUploaderProvider =
    Provider<EvidenceUploader>((ref) => EvidenceUploader());

/// Provider del detalle de un hito. Family por milestoneId.
final milestoneDetailProvider =
    FutureProvider.family<MilestoneDetail, String>((ref, milestoneId) {
  return ref.watch(pactsRepositoryProvider).getMilestoneDetail(milestoneId);
});
