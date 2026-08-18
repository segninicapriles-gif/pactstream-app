import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pactstream/features/pact/data/evidence_queue.dart';
import 'package:pactstream/features/pact/data/evidence_uploader.dart';

void main() {
  group('EvidenceUploader.computeStoragePath — idempotencia', () {
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final capturedAt = DateTime.utc(2026, 8, 18, 12, 0, 0);

    test('mismos inputs → misma ruta (clave del reintento sin duplicar)', () {
      final a = EvidenceUploader.computeStoragePath(
        pactId: 'p1',
        milestoneId: 'm1',
        bytes: bytes,
        filename: 'foto.jpg',
        capturedAt: capturedAt,
      );
      final b = EvidenceUploader.computeStoragePath(
        pactId: 'p1',
        milestoneId: 'm1',
        bytes: bytes,
        filename: 'foto.jpg',
        capturedAt: capturedAt,
      );
      expect(a, equals(b));
    });

    test('la ruta lleva pact, hito, epoch, hash8 y extensión', () {
      final path = EvidenceUploader.computeStoragePath(
        pactId: 'p1',
        milestoneId: 'm1',
        bytes: bytes,
        filename: 'FOTO.JPG',
        capturedAt: capturedAt,
      );
      final hash8 = EvidenceUploader.hashOf(bytes).substring(0, 8);
      expect(path,
          equals('p1/m1/${capturedAt.millisecondsSinceEpoch}-$hash8.jpg'));
    });

    test('contenido distinto → hash distinto → ruta distinta', () {
      final other = Uint8List.fromList([9, 9, 9]);
      final a = EvidenceUploader.computeStoragePath(
        pactId: 'p1',
        milestoneId: 'm1',
        bytes: bytes,
        filename: 'x.jpg',
        capturedAt: capturedAt,
      );
      final b = EvidenceUploader.computeStoragePath(
        pactId: 'p1',
        milestoneId: 'm1',
        bytes: other,
        filename: 'x.jpg',
        capturedAt: capturedAt,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('QueuedEvidence — serialización', () {
    test('round-trip JSON preserva todos los campos', () {
      final entry = QueuedEvidence(
        id: 'e1',
        pactId: 'p1',
        milestoneId: 'm1',
        localPath: '/tmp/e1.jpg',
        filename: 'e1.jpg',
        mimeType: 'image/jpeg',
        storagePath: 'p1/m1/123-abcd1234.jpg',
        sha256Hash: 'abcd',
        sizeBytes: 2048,
        clientTimestamp: DateTime.utc(2026, 8, 18, 10),
        createdAt: DateTime.utc(2026, 8, 18, 10, 1),
        description: 'muro este',
        gpsLatitude: 9.75,
        gpsLongitude: -63.17,
        gpsAccuracyMeters: 4.2,
        status: QueuedEvidenceStatus.failed,
        attempts: 2,
        lastError: 'boom',
      );

      final round = QueuedEvidence.fromJson(entry.toJson());

      expect(round.id, entry.id);
      expect(round.storagePath, entry.storagePath);
      expect(round.sha256Hash, entry.sha256Hash);
      expect(round.sizeBytes, entry.sizeBytes);
      expect(round.clientTimestamp, entry.clientTimestamp);
      expect(round.description, entry.description);
      expect(round.gpsLatitude, entry.gpsLatitude);
      expect(round.gpsLongitude, entry.gpsLongitude);
      expect(round.gpsAccuracyMeters, entry.gpsAccuracyMeters);
      expect(round.status, QueuedEvidenceStatus.failed);
      expect(round.attempts, 2);
      expect(round.lastError, 'boom');
    });

    test('copyWith(clearError) limpia el error y cambia estado', () {
      final failed = QueuedEvidence(
        id: 'e1',
        pactId: 'p1',
        milestoneId: 'm1',
        localPath: '/tmp/e1.jpg',
        filename: 'e1.jpg',
        mimeType: 'image/jpeg',
        storagePath: 'p1/m1/123-abcd1234.jpg',
        sha256Hash: 'abcd',
        sizeBytes: 10,
        clientTimestamp: DateTime.utc(2026, 8, 18),
        createdAt: DateTime.utc(2026, 8, 18),
        status: QueuedEvidenceStatus.failed,
        attempts: 3,
        lastError: 'boom',
      );

      final retried = failed.copyWith(
        status: QueuedEvidenceStatus.pending,
        clearError: true,
      );

      expect(retried.status, QueuedEvidenceStatus.pending);
      expect(retried.lastError, isNull);
      expect(retried.attempts, 3); // se conserva el histórico de intentos
      expect(retried.sha256Hash, 'abcd'); // el resto intacto
    });

    test('entrada sin GPS ni descripción sobrevive al round-trip', () {
      final entry = QueuedEvidence(
        id: 'e2',
        pactId: 'p2',
        milestoneId: 'm2',
        localPath: '/tmp/e2.png',
        filename: 'e2.png',
        mimeType: 'image/png',
        storagePath: 'p2/m2/456-ffff0000.png',
        sha256Hash: 'ffff',
        sizeBytes: 1,
        clientTimestamp: DateTime.utc(2026, 8, 18),
        createdAt: DateTime.utc(2026, 8, 18),
      );
      final round = QueuedEvidence.fromJson(entry.toJson());
      expect(round.hasGps, isFalse);
      expect(round.description, isNull);
      expect(round.status, QueuedEvidenceStatus.pending);
    });
  });
}
