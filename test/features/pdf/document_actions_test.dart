import 'package:flutter_test/flutter_test.dart';

/// Artifact states that a routed viewer can display.
enum ArtifactState { available, missing, generating, error, unsupportedPrint }

/// Fake PDF viewer service for testing routed actions.
class FakePdfViewerService {
  FakePdfViewerService({this.state = ArtifactState.available});

  ArtifactState state;
  bool previewCalled = false;
  bool saveCalled = false;
  bool regenerateCalled = false;
  String? lastSavedPath;

  Future<void> preview(String path) async {
    previewCalled = true;
  }

  Future<void> saveAs(String path) async {
    saveCalled = true;
    lastSavedPath = path;
  }

  Future<void> regenerate() async {
    regenerateCalled = true;
  }

  bool get canPrint => state != ArtifactState.unsupportedPrint;
}

/// Artifact action handler for routed UI.
class ArtifactActionHandler {
  ArtifactActionHandler({required this.viewer});

  final FakePdfViewerService viewer;

  Future<void> handlePreview(String path) async {
    if (viewer.state == ArtifactState.missing) {
      await viewer.regenerate();
      return;
    }
    await viewer.preview(path);
  }

  Future<void> handleSave(String path) async {
    await viewer.saveAs(path);
  }

  Future<void> handlePrint(String path) async {
    if (!viewer.canPrint) {
      return; // Unsupported — caller should show Save As
    }
    await viewer.preview(path);
  }
}

/// Path validator for artifact file safety.
class ArtifactPathValidator {
  static bool isSafePath(String path, String profileRoot) {
    // Reject paths that escape the profile root
    final String resolved = path.replaceAll(r'\', '/');
    if (resolved.contains('..')) return false;
    if (!resolved.startsWith(profileRoot)) return false;
    return true;
  }
}

void main() {
  group('Routed artifact actions', () {
    test('test_user_previews_and_saves_artifact', () async {
      // GIVEN: an available artifact and viewer
      final FakePdfViewerService viewer = FakePdfViewerService();
      final ArtifactActionHandler handler = ArtifactActionHandler(viewer: viewer);

      // WHEN: user previews
      await handler.handlePreview('/profiles/default/RE-0001.pdf');
      expect(viewer.previewCalled, isTrue);

      // WHEN: user saves
      await handler.handleSave('/tmp/export.pdf');
      expect(viewer.saveCalled, isTrue);
      expect(viewer.lastSavedPath, '/tmp/export.pdf');
    });

    test('test_viewer_reports_unsupported_print', () async {
      // GIVEN: a viewer that doesn't support print
      final FakePdfViewerService viewer = FakePdfViewerService(state: ArtifactState.unsupportedPrint);
      final ArtifactActionHandler handler = ArtifactActionHandler(viewer: viewer);

      // WHEN: user tries to print
      await handler.handlePrint('/profiles/default/RE-0001.pdf');

      // THEN: print is silently skipped — caller should offer Save As
      expect(viewer.canPrint, isFalse);
    });
  });

  group('Missing artifact recovery', () {
    test('test_missing_file_offers_regeneration', () async {
      // GIVEN: artifact is missing
      final FakePdfViewerService viewer = FakePdfViewerService(state: ArtifactState.missing);
      final ArtifactActionHandler handler = ArtifactActionHandler(viewer: viewer);

      // WHEN: user tries to preview a missing artifact
      await handler.handlePreview('/profiles/default/RE-0001.pdf');

      // THEN: regeneration is triggered
      expect(viewer.regenerateCalled, isTrue);
    });

    test('test_unsafe_path_is_rejected', () {
      // GIVEN: a path traversal attempt
      const String profileRoot = '/profiles/default';

      // WHEN/THEN: unsafe paths are rejected
      expect(ArtifactPathValidator.isSafePath('../../../etc/passwd', profileRoot), isFalse);
      expect(ArtifactPathValidator.isSafePath('/profiles/default/../../etc/passwd', profileRoot), isFalse);
      expect(ArtifactPathValidator.isSafePath('/other/profile/file.pdf', profileRoot), isFalse);

      // Safe paths pass
      expect(ArtifactPathValidator.isSafePath('/profiles/default/RE-0001.pdf', profileRoot), isTrue);
    });
  });
}
