import 'dart:io';

/// Resolves paths relative to the evolve_app repository root (pubspec.yaml parent).
/// Used by repo-relative integration tests (e.g. downloads landing page).
String evolveRepoRoot() {
  var dir = File(Platform.script.toFilePath()).parent;
  while (!File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate evolve_app root from ${Platform.script}');
    }
    dir = parent;
  }
  return dir.path;
}

File evolveRepoFile(String relativePath) {
  final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
  return File('${evolveRepoRoot()}${Platform.pathSeparator}$normalized');
}