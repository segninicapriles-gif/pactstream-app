import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../data/datasources/supabase/supabase_client.dart';
import 'evidence_uploader.dart';
import 'pact_providers.dart';

/// Cola OFFLINE de evidencias.
///
/// Motivación: en obra —y muy especialmente en reconstrucción tras un
/// desastre— la conectividad es intermitente. La captura de la evidencia
/// (foto + GPS + hash SHA-256) es 100% local, pero el envío exigía red en
/// ese instante: si fallaba, al cerrar la app la evidencia se perdía.
///
/// Esta cola persiste la captura en disco y la envía sola en cuanto vuelve
/// la cobertura. Arquitectura:
///   - los BYTES de la foto se guardan en un fichero bajo el directorio de
///     documentos (no en SharedPreferences, que serializa todo a un blob);
///   - los METADATOS (incluida la ruta del fichero y la ruta de Storage ya
///     calculada) se guardan como JSON en SharedPreferences.
///
/// La ruta de Storage se fija AL ENCOLAR y no cambia entre reintentos, lo
/// que da idempotencia: si el fichero llegó a subir pero falló el registro
/// en BD, el reintento no re-sube (ver [EvidenceUploader.uploadToPath]).

enum QueuedEvidenceStatus {
  /// A la espera de red. No es un error: se enviará al recuperar cobertura.
  pending,

  /// Envío en curso.
  uploading,

  /// Se intentó con red y el servidor la rechazó (error real, reintentable).
  failed,
}

/// Una evidencia capturada, pendiente de subir.
@immutable
class QueuedEvidence {
  const QueuedEvidence({
    required this.id,
    required this.pactId,
    required this.milestoneId,
    required this.localPath,
    required this.filename,
    required this.mimeType,
    required this.storagePath,
    required this.sha256Hash,
    required this.sizeBytes,
    required this.clientTimestamp,
    required this.createdAt,
    this.description,
    this.gpsLatitude,
    this.gpsLongitude,
    this.gpsAccuracyMeters,
    this.status = QueuedEvidenceStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String pactId;
  final String milestoneId;

  /// Ruta local del fichero con los bytes de la foto.
  final String localPath;
  final String filename;
  final String mimeType;

  /// Ruta de destino en Supabase Storage, fijada al encolar (idempotencia).
  final String storagePath;
  final String sha256Hash;
  final int sizeBytes;
  final DateTime clientTimestamp;
  final DateTime createdAt;
  final String? description;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final double? gpsAccuracyMeters;
  final QueuedEvidenceStatus status;
  final int attempts;
  final String? lastError;

  bool get hasGps => gpsLatitude != null && gpsLongitude != null;

  QueuedEvidence copyWith({
    QueuedEvidenceStatus? status,
    int? attempts,
    String? lastError,
    bool clearError = false,
  }) {
    return QueuedEvidence(
      id: id,
      pactId: pactId,
      milestoneId: milestoneId,
      localPath: localPath,
      filename: filename,
      mimeType: mimeType,
      storagePath: storagePath,
      sha256Hash: sha256Hash,
      sizeBytes: sizeBytes,
      clientTimestamp: clientTimestamp,
      createdAt: createdAt,
      description: description,
      gpsLatitude: gpsLatitude,
      gpsLongitude: gpsLongitude,
      gpsAccuracyMeters: gpsAccuracyMeters,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pact_id': pactId,
        'milestone_id': milestoneId,
        'local_path': localPath,
        'filename': filename,
        'mime_type': mimeType,
        'storage_path': storagePath,
        'sha256': sha256Hash,
        'size_bytes': sizeBytes,
        'client_ts': clientTimestamp.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'description': description,
        'gps_lat': gpsLatitude,
        'gps_lng': gpsLongitude,
        'gps_acc': gpsAccuracyMeters,
        'status': status.name,
        'attempts': attempts,
        'last_error': lastError,
      };

  factory QueuedEvidence.fromJson(Map<String, dynamic> j) {
    return QueuedEvidence(
      id: j['id'] as String,
      pactId: j['pact_id'] as String,
      milestoneId: j['milestone_id'] as String,
      localPath: j['local_path'] as String,
      filename: j['filename'] as String,
      mimeType: j['mime_type'] as String,
      storagePath: j['storage_path'] as String,
      sha256Hash: j['sha256'] as String,
      sizeBytes: (j['size_bytes'] as num).toInt(),
      clientTimestamp: DateTime.parse(j['client_ts'] as String),
      createdAt: DateTime.parse(j['created_at'] as String),
      description: j['description'] as String?,
      gpsLatitude: (j['gps_lat'] as num?)?.toDouble(),
      gpsLongitude: (j['gps_lng'] as num?)?.toDouble(),
      gpsAccuracyMeters: (j['gps_acc'] as num?)?.toDouble(),
      status: QueuedEvidenceStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => QueuedEvidenceStatus.pending,
      ),
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      lastError: j['last_error'] as String?,
    );
  }
}

/// Persistencia de la cola: fichero de bytes en disco + metadatos en prefs.
class EvidenceQueueStore {
  EvidenceQueueStore();

  static const _prefsKey = 'evidence_queue_v1';
  static const _dirName = 'evidence_queue';

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Guarda los bytes en un fichero propio de la cola y devuelve su ruta.
  Future<String> writeBytes(String entryId, Uint8List bytes, String ext) async {
    final dir = await _dir();
    final file = File('${dir.path}/$entryId$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Uint8List?> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('EvidenceQueue: no se pudo borrar $path: $e');
    }
  }

  Future<List<QueuedEvidence>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => QueuedEvidence.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      debugPrint('EvidenceQueue: metadatos corruptos, se descartan: $e');
      return const [];
    }
  }

  Future<void> save(List<QueuedEvidence> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }
}

/// Orquestador de la cola. Expuesto vía [evidenceQueueProvider].
class EvidenceQueueNotifier extends Notifier<List<QueuedEvidence>> {
  final _store = EvidenceQueueStore();
  final _uuid = const Uuid();
  bool _draining = false;

  @override
  List<QueuedEvidence> build() {
    // Suscripción a cambios de conectividad: al recuperar cobertura, drenar.
    final sub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork =
          results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) drain();
    });
    ref.onDispose(sub.cancel);

    // Backstop: drenar cuando la app vuelve a primer plano (el usuario pudo
    // salir de una zona sin cobertura sin que cambiara la interfaz de red).
    final lifecycle = AppLifecycleListener(
      onResume: () => drain(),
    );
    ref.onDispose(lifecycle.dispose);

    // Carga inicial desde disco + primer intento de drenado.
    _hydrate();
    return const [];
  }

  Future<void> _hydrate() async {
    final loaded = await _store.load();
    // Cualquier entrada que quedara en 'uploading' de una sesión anterior
    // (la app se cerró a mitad) vuelve a 'pending'.
    final normalized = loaded
        .map((e) => e.status == QueuedEvidenceStatus.uploading
            ? e.copyWith(status: QueuedEvidenceStatus.pending)
            : e)
        .toList();
    state = normalized;
    if (normalized.isNotEmpty) drain();
  }

  Future<void> _persist() => _store.save(state);

  /// Encola una evidencia capturada y lanza un intento de envío inmediato.
  /// Devuelve el id de la entrada creada.
  Future<String> enqueue({
    required String pactId,
    required String milestoneId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? description,
    double? gpsLatitude,
    double? gpsLongitude,
    double? gpsAccuracyMeters,
    DateTime? clientTimestamp,
  }) async {
    final id = _uuid.v4();
    final ext = _extFromName(filename);
    final storagePath = EvidenceUploader.computeStoragePath(
      pactId: pactId,
      milestoneId: milestoneId,
      bytes: bytes,
      filename: filename,
    );
    final localPath = await _store.writeBytes(id, bytes, ext);

    final entry = QueuedEvidence(
      id: id,
      pactId: pactId,
      milestoneId: milestoneId,
      localPath: localPath,
      filename: filename,
      mimeType: mimeType,
      storagePath: storagePath,
      sha256Hash: EvidenceUploader.hashOf(bytes),
      sizeBytes: bytes.length,
      clientTimestamp: clientTimestamp ?? DateTime.now(),
      createdAt: DateTime.now(),
      description: description,
      gpsLatitude: gpsLatitude,
      gpsLongitude: gpsLongitude,
      gpsAccuracyMeters: gpsAccuracyMeters,
    );

    state = [...state, entry];
    await _persist();
    await drain();
    return id;
  }

  /// Intenta subir todas las entradas pendientes/fallidas. Idempotente y
  /// reentrante-seguro: si ya hay un drenado en curso, no arranca otro.
  Future<void> drain() async {
    if (_draining) return;
    if (SupabaseConfig.currentUser == null) return; // hace falta sesión

    // Sin cobertura no marcamos error: dejamos las entradas 'pending'.
    final conn = await Connectivity().checkConnectivity();
    final hasNetwork = conn.any((r) => r != ConnectivityResult.none);
    if (!hasNetwork) return;

    _draining = true;
    try {
      final uploader = ref.read(evidenceUploaderProvider);
      final repo = ref.read(pactsRepositoryProvider);

      // Copia estable de los ids a procesar (el estado muta durante el bucle).
      final toProcess = state
          .where((e) => e.status != QueuedEvidenceStatus.uploading)
          .map((e) => e.id)
          .toList();

      for (final entryId in toProcess) {
        final entry = _byId(entryId);
        if (entry == null) continue;

        _update(entryId,
            (e) => e.copyWith(status: QueuedEvidenceStatus.uploading));

        try {
          final bytes = await _store.readBytes(entry.localPath);
          if (bytes == null) {
            // El fichero desapareció: no hay nada que subir, descartamos.
            await _discard(entryId);
            continue;
          }

          // 1. Storage (idempotente: tolera "ya existe").
          await uploader.uploadToPath(
            storagePath: entry.storagePath,
            bytes: bytes,
            mimeType: entry.mimeType,
          );

          // 2. Registro en BD.
          await repo.recordMilestoneEvidence(
            milestoneId: entry.milestoneId,
            evidenceType: 'photo',
            storagePath: entry.storagePath,
            sha256Hash: entry.sha256Hash,
            fileSizeBytes: entry.sizeBytes,
            mimeType: entry.mimeType,
            description: entry.description,
            gpsLatitude: entry.gpsLatitude,
            gpsLongitude: entry.gpsLongitude,
            gpsAccuracyMeters: entry.gpsAccuracyMeters,
            clientTimestamp: entry.clientTimestamp,
          );

          // Éxito: fuera de la cola + refrescar el hito para que aparezca.
          await _discard(entryId);
          ref.invalidate(milestoneDetailProvider(entry.milestoneId));
        } catch (e) {
          if (_isOffline(e)) {
            // Se cayó la red a mitad: volvemos a 'pending', sin contar intento.
            _update(entryId,
                (x) => x.copyWith(status: QueuedEvidenceStatus.pending));
            break; // sin red, no seguimos con el resto
          }
          _update(
            entryId,
            (x) => x.copyWith(
              status: QueuedEvidenceStatus.failed,
              attempts: x.attempts + 1,
              lastError: e.toString(),
            ),
          );
        }
      }
      await _persist();
    } finally {
      _draining = false;
    }
  }

  /// Reintenta una entrada fallida (la vuelve a 'pending' y drena).
  Future<void> retry(String entryId) async {
    _update(entryId,
        (e) => e.copyWith(status: QueuedEvidenceStatus.pending, clearError: true));
    await _persist();
    await drain();
  }

  /// Reintenta todas las fallidas de un hito.
  Future<void> retryMilestone(String milestoneId) async {
    state = state
        .map((e) => e.milestoneId == milestoneId &&
                e.status == QueuedEvidenceStatus.failed
            ? e.copyWith(status: QueuedEvidenceStatus.pending, clearError: true)
            : e)
        .toList();
    await _persist();
    await drain();
  }

  /// Descarta una entrada (con su fichero). Para que el usuario pueda
  /// desechar una captura que ya no quiere reintentar.
  Future<void> discard(String entryId) => _discard(entryId, persist: true);

  Future<void> _discard(String entryId, {bool persist = false}) async {
    final entry = _byId(entryId);
    if (entry != null) await _store.deleteFile(entry.localPath);
    state = state.where((e) => e.id != entryId).toList();
    if (persist) await _persist();
  }

  QueuedEvidence? _byId(String id) {
    for (final e in state) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _update(
      String id, QueuedEvidence Function(QueuedEvidence) transform) {
    state = state.map((e) => e.id == id ? transform(e) : e).toList();
  }

  bool _isOffline(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('network is unreachable') ||
        s.contains('clientexception') ||
        s.contains('timeoutexception');
  }

  String _extFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot).toLowerCase();
  }
}

/// Cola global de evidencias pendientes. Se mantiene viva durante toda la
/// sesión (se observa en la raíz de la app) para que el drenado por
/// conectividad y por reanudación funcione aunque no haya ninguna pantalla
/// de evidencias abierta.
final evidenceQueueProvider =
    NotifierProvider<EvidenceQueueNotifier, List<QueuedEvidence>>(
  EvidenceQueueNotifier.new,
);

/// Entradas pendientes de un hito concreto (derivado de la cola global).
final pendingEvidenceForMilestoneProvider =
    Provider.family<List<QueuedEvidence>, String>((ref, milestoneId) {
  final all = ref.watch(evidenceQueueProvider);
  return all.where((e) => e.milestoneId == milestoneId).toList();
});
