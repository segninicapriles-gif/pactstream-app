/// Providers Riverpod para el motor de scoring de PactStream.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scoring_models.dart';
import 'scoring_service.dart';

// Singleton del servicio
final scoringServiceProvider = Provider<ScoringService>(
  (_) => ScoringService(),
);

/// Último snapshot de salud de un pacto.
/// Se invalida llamando ref.invalidate(pactHealthProvider(pactId)).
final pactHealthProvider =
    FutureProvider.family<PactHealthScore, String>((ref, pactId) {
  return ref.watch(scoringServiceProvider).getPactHealth(pactId);
});

/// Último snapshot de reputación de un usuario por su public.users.id.
final userReputationProvider =
    FutureProvider.family<UserReputation, String>((ref, userId) {
  return ref.watch(scoringServiceProvider).getUserReputation(userId);
});

/// Reputación del usuario autenticado actual.
/// Usa get_my_reputation() en el servidor — no necesita pasar el UUID interno.
final myReputationProvider = FutureProvider<UserReputation>((ref) {
  return ref.watch(scoringServiceProvider).getMyReputation();
});
