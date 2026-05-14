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

  /// Sube un archivo a Storage y devuelve metadatos.
  ///
  /// Path final: `{pact_id}/{milestone_id}/{epoch}-{hash8}.{ext}`
  Future<UploadResult> uploadFile({
    required String pactId,
    required String milestoneId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    // 1. Hash SHA-256 del archivo (evidencia de integridad)
    final digest = sha256.convert(bytes);
    final hashHex = digest.toString();

    // 2. Path único en Storage
    final ext = _extFromName(filename);
    final stem =
        '${DateTime.now().millisecondsSinceEpoch}-${hashHex.substring(0, 8)}';
    final storagePath = '$pactId/$milestoneId/$stem$ext';

    // 3. Subir a Supabase Storage
    final storage = SupabaseConfig.client.storage.from(_bucketName);
    await storage.uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: mimeType,
        upsert: false,
      ),
    );

    return UploadResult(
      storagePath: storagePath,
      sha256Hash: hashHex,
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

  String _extFromName(String name) {
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
