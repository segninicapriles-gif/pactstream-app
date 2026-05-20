import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/supabase/supabase_client.dart';
import 'organization.dart';

/// Devuelve mis organizaciones (las que soy owner o miembro activo).
/// Wraps `sf_list_my_orgs()`.
final myOrgsProvider =
    FutureProvider.autoDispose<List<Organization>>((ref) async {
  final r = await SupabaseConfig.client.rpc('sf_list_my_orgs')
      as Map<String, dynamic>?;
  if (r == null) return const [];
  final list = (r['organizations'] as List<dynamic>? ?? const [])
      .map((e) => Organization.fromJson(e as Map<String, dynamic>))
      .toList();
  return list;
});

/// Devuelve los miembros de una organización concreta.
/// Wraps `sf_get_org_members(p_org_id)`.
final orgMembersProvider = FutureProvider.autoDispose
    .family<OrgMembersResult, String>((ref, orgId) async {
  final r = await SupabaseConfig.client
          .rpc('sf_get_org_members', params: {'p_org_id': orgId})
      as Map<String, dynamic>?;
  if (r == null) {
    throw Exception('sf_get_org_members no devolvió datos');
  }
  return OrgMembersResult.fromJson(r);
});

/// Helper · devuelve la primera organización donde soy owner (si existe).
/// `null` si no soy owner de ninguna.
final myOwnedOrgProvider = FutureProvider.autoDispose<Organization?>((ref) async {
  final orgs = await ref.watch(myOrgsProvider.future);
  for (final o in orgs) {
    if (o.isOwner) return o;
  }
  return null;
});
