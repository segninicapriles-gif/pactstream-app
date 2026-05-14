import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/supabase/supabase_client.dart';
import 'dashboard_data.dart';

/// Provider asíncrono que carga los datos de la home llamando a
/// `sf_get_dashboard_data()`.
///
/// La UI llama `ref.invalidate(dashboardDataProvider)` para refrescar manualmente
/// (botón pull-to-refresh, tras ejecutar una acción que cambia los KPIs, etc.).
final dashboardDataProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final json =
      await SupabaseConfig.client.rpc('sf_get_dashboard_data') as Map<String, dynamic>?;

  if (json == null) {
    throw Exception('La RPC sf_get_dashboard_data no devolvió datos');
  }

  return DashboardData.fromJson(json);
});
