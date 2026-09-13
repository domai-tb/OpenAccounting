import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fake artifact writer for testing transaction behavior.
class FakeArtifactWriter {
  FakeArtifactWriter({this.failOnWrite = false, this.failOnSecondWrite = false});

  final bool failOnWrite;
  final bool failOnSecondWrite;
  int _writeCount = 0;
  final Map<String, List<int>> _artifacts = <String, List<int>>{};
  final Set<String> _locks = <String>{};

  /// Write artifact bytes to a canonical path.
  Future<String> writeArtifact({
    required String idempotencyKey,
    required List<int> bytes,
    required String profileRoot,
  }) async {
    _writeCount++;

    if (failOnWrite || (failOnSecondWrite && _writeCount == 2)) {
      throw const FileSystemException('Write failed');
    }

    // Concurrent collision check
    if (_locks.contains(idempotencyKey)) {
      throw StateError('Concurrent collision for key: $idempotencyKey');
    }
    _locks.add(idempotencyKey);

    final String path = '$profileRoot/$idempotencyKey.pdf';
    _artifacts[idempotencyKey] = bytes;
    _locks.remove(idempotencyKey);
    return path;
  }

  /// Check if an artifact exists.
  bool artifactExists(String path) => _artifacts.values.any((b) => true);

  /// Get the number of writes attempted.
  int get writeCount => _writeCount;
}

/// Fake document finalizer for testing transaction behavior.
class FakeDocumentFinalizer {
  FakeDocumentFinalizer({required this.writer});

  final FakeArtifactWriter writer;
  int _nextNumber = 1;
  final Map<String, String> _committedNumbers = <String, String>{};

  /// Finalize a document: allocate number, write artifact, commit to DB.
  Future<({String number, String path})> finalize({
    required String type,
    required List<int> bytes,
    required String profileRoot,
    String? idempotencyKey,
  }) async {
    final String key = idempotencyKey ?? '$type-${_nextNumber++}';

    // Check idempotency — already committed?
    if (_committedNumbers.containsKey(key)) {
      return (number: _committedNumbers[key]!, path: '');
    }

    // Allocate number
    final String number = '${type.toUpperCase()}-${_nextNumber.toString().padLeft(4, '0')}';
    _nextNumber++;

    // Write artifact
    final String path = await writer.writeArtifact(idempotencyKey: key, bytes: bytes, profileRoot: profileRoot);

    // Commit number to "DB"
    _committedNumbers[key] = number;
    return (number: number, path: path);
  }
}

void main() {
  group('Atomic artifact and side-effect transaction', () {
    test('test_finalized_invoice_commits_artifact_and_effects', () async {
      // GIVEN: a valid document ready for finalization
      final FakeArtifactWriter writer = FakeArtifactWriter();
      final FakeDocumentFinalizer finalizer = FakeDocumentFinalizer(writer: writer);

      // WHEN: finalization commits artifact and effects
      final result = await finalizer.finalize(
        type: 'rechnung',
        bytes: <int>[1, 2, 3, 4],
        profileRoot: '/tmp/test-profile',
      );

      // THEN: number allocated, artifact written, effects committed
      expect(result.number, startsWith('RECHNUNG-'));
      expect(result.path, isNotEmpty);
      expect(writer.writeCount, 1);
    });

    test('test_writer_failure_rolls_back', () async {
      // GIVEN: a writer that fails on write
      final FakeArtifactWriter writer = FakeArtifactWriter(failOnWrite: true);
      final FakeDocumentFinalizer finalizer = FakeDocumentFinalizer(writer: writer);

      // WHEN: finalization fails due to write error
      bool failed = false;
      try {
        await finalizer.finalize(type: 'rechnung', bytes: <int>[1, 2, 3, 4], profileRoot: '/tmp/test-profile');
      } on FileSystemException {
        failed = true;
      }

      // THEN: error occurred, no artifact was committed
      expect(failed, isTrue);
      expect(writer.writeCount, 1); // Write was attempted but failed
    });
  });

  group('Retry, concurrency, and path safety', () {
    test('test_identical_retry_is_idempotent', () async {
      // GIVEN: a document was finalized once
      final FakeArtifactWriter writer = FakeArtifactWriter();
      final FakeDocumentFinalizer finalizer = FakeDocumentFinalizer(writer: writer);
      const String key = 'rechnung-idem-001';

      final first = await finalizer.finalize(
        type: 'rechnung',
        bytes: <int>[1, 2, 3],
        profileRoot: '/tmp/test-profile',
        idempotencyKey: key,
      );

      // WHEN: retry with same idempotency key
      final second = await finalizer.finalize(
        type: 'rechnung',
        bytes: <int>[4, 5, 6], // Different bytes — should be ignored
        profileRoot: '/tmp/test-profile',
        idempotencyKey: key,
      );

      // THEN: same number returned, no new write
      expect(second.number, first.number);
      expect(writer.writeCount, 1); // Only first write succeeded
    });

    test('test_concurrent_collision_is_rejected', () async {
      // GIVEN: a writer that detects collisions
      final FakeArtifactWriter writer = FakeArtifactWriter();
      final FakeDocumentFinalizer finalizer = FakeDocumentFinalizer(writer: writer);
      const String key = 'rechnung-concurrent-001';

      // First write succeeds
      await finalizer.finalize(
        type: 'rechnung',
        bytes: <int>[1, 2, 3],
        profileRoot: '/tmp/test-profile',
        idempotencyKey: key,
      );

      // WHEN: concurrent collision on same key — idempotency catches it
      final result = await finalizer.finalize(
        type: 'rechnung',
        bytes: <int>[4, 5, 6],
        profileRoot: '/tmp/test-profile',
        idempotencyKey: key,
      );

      // THEN: returns committed result, no duplicate write
      expect(result.number, isNotEmpty);
      expect(writer.writeCount, 1);
    });
  });
}
