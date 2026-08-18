import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/datasources/supabase/supabase_client.dart';

/// Encapsula la subida de un archivo a Supabase Storage y la generación
/// de URLs firmadas para visualizarlo.
///
/// El registro de la evidencia en BD se hace después con el repo:
///   1. uploadFile() → devuelve storage_path + sha256
///   2. PactsRepository.recordMilestoneEvidence() → crea fila en BD
///
/// La separación permite reintentar el step 2 si la red falla sin tener
/// que reupload (idempotencia básica).
class EvidenceUploader {
  EvidenceUploader();

  static const _bucketName = 'milestone-evidences';

  /// SHA-256 del contenido en hex (evidencia de integridad).
  static String hashOf(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Calcula la ruta de Storage de forma DETERMINISTA a partir del contenido.
  ///
  /// Path final: `{pact_id}/{milestone_id}/{epoch}-{hash8}.{ext}`
  ///
  /// La cola offline la calcula UNA vez al encolar y la persiste, de modo que
  /// el reintento suba siempre a la misma ruta (idempotencia). El epoch es el
  /// del momento de captura, no el del reintento.
  static String computeStoragePath({
    required String pactId,
    required String milestoneId,
    required Uint8List bytes,
    required String filename,
    DateTime? capturedAt,
  }) {
    final hashHex = hashOf(bytes);
    final ext = _extOf(filename);
    final epoch = (capturedAt ?? DateTime.now()).millisecondsSinceEpoch;
    return '$pactId/$milestoneId/$epoch-${hashHex.substring(0, 8)}$ext';
  }

  /// Sube bytes a una ruta de Storage YA CALCULADA. Idempotente: si el
  /// objeto ya existe (un reintento tras subir pero fallar el registro en
  /// BD), lo trata como éxito en vez de propagar el error.
  Future<void> uploadToPath({
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final storage = SupabaseConfig.client.storage.from(_bucketName);
    try {
      await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: false,
        ),
      );
    } on StorageException catch (e) {
      // 409 / "Duplicate" / "already exists" → ya estaba subido.
      final msg = e.message.toLowerCase();
      final isDuplicate = e.statusCode == '409' ||
          msg.contains('already exists') ||
          msg.contains('duplicate') ||
          msg.contains('resource already exists');
      if (!isDuplicate) rethrow;
    }
  }

  /// Sube un archivo a Storage y devuelve metadatos. Ruta única por llamada.
  Future<UploadResult> uploadFile({
    required String pactId,
    required String milestoneId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final storagePath = computeStoragePath(
      pactId: pactId,
      milestoneId: milestoneId,
      bytes: bytes,
      filename: filename,
    );
    await uploadToPath(
      storagePath: storagePath,
      bytes: bytes,
      mimeType: mimeType,
    );
    return UploadResult(
      storagePath: storagePath,
      sha256Hash: hashOf(bytes),
      sizeBytes: bytes.length,
      mimeType: mimeType,
    );
  }

  /// URL firmada temporal para descargar/visualizar la evidencia.
  /// Bucket privado → necesita signed URL con expiración.
  Future<String> createSignedUrl({
    required String storagePath,
    Duration expiresIn = const Duration(hours: 1),
  }) async {
    final storage = SupabaseConfig.client.storage.from(_bucketName);
    return storage.createSignedUrl(storagePath, expiresIn.inSeconds);
  }

  static String _extOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot).toLowerCase();
  }
}

class UploadResult {
  UploadResult({
    required this.storagePath,
    required this.sha256Hash,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String storagePath;
  final String sha256Hash;
  final int sizeBytes;
  final String mimeType;
}
