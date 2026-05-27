/// Servicio de datos para scoring — accede a Supabase via RPCs.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'scoring_models.dart';

class ScoringService {
  ScoringService() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  /// Devuelve el último snapshot de salud del pacto.
  /// Si no existe, el RPC lo calcula en tiempo real.
  Future<PactHealthScore> getPactHealth(String pactId) async {
    final data = await _client.rpc(
      'get_pact_health',
      params: {'p_pact_id': pactId},
    );
    return PactHealthScore.fromJson(data as Map<String, dynamic>);
  }

  /// Devuelve el último snapshot de reputación del usuario.
  Future<UserReputation> getUserReputation(String userId) async {
    final data = await _client.rpc(
      'get_user_reputation',
      params: {'p_user_id': userId},
    );
    return UserReputation.fromJson(data as Map<String, dynamic>);
  }

  /// Devuelve la reputación del usuario autenticado actual.
  /// Llama a get_my_reputation() — no necesita el UUID interno.
  Future<UserReputation> getMyReputation() async {
    final data = await _client.rpc('get_my_reputation');
    return UserReputation.fromJson(data as Map<String, dynamic>);
  }

  /// Fuerza recálculo del health del pacto (service_role o admin).
  Future<void> recalcPactHealth(String pactId) async {
    await _client.rpc(
      'sf_recalc_pact_health',
      params: {'p_pact_id': pactId},
    );
  }

  /// Fuerza recálculo de la reputación del usuario.
  Future<void> recalcUserReputation(String userId) async {
    await _client.rpc(
      'sf_recalc_user_reputation',
      params: {'p_user_id': userId},
    );
  }
}
