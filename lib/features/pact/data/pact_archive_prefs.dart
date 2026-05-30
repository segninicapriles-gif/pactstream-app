import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kArchivedPactsKey = 'pactstream_archived_pacts';

/// Per-user archive state for pacts.
///
/// Archiving is local to each user — it doesn't affect other parties
/// in the pact. Archived pacts are hidden from the main list but
/// accessible via the "Archivadas" filter tab.
final archivedPactIdsProvider =
    StateNotifierProvider<ArchivedPactIdsNotifier, Set<String>>(
  (ref) => ArchivedPactIdsNotifier(),
);

class ArchivedPactIdsNotifier extends StateNotifier<Set<String>> {
  ArchivedPactIdsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kArchivedPactsKey) ?? [];
    state = list.toSet();
  }

  Future<void> archive(String pactId) async {
    state = {...state, pactId};
    await _save();
  }

  Future<void> unarchive(String pactId) async {
    state = {...state}..remove(pactId);
    await _save();
  }

  bool isArchived(String pactId) => state.contains(pactId);

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kArchivedPactsKey, state.toList());
  }
}
