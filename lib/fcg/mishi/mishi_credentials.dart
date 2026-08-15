import 'dart:io';

import 'mishi_first_run.dart';

/// Username/password retain for the desktop Mishi moderator app.
///
/// Format (txt, one field per line):
///   username=<value>
///   password=<value>
///
/// The same [MishiCredentialStore] is used by the GUI and by tests.
class MishiCredentialRecord {
  const MishiCredentialRecord({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  bool get isEmpty => username.isEmpty && password.isEmpty;
}

class MishiCredentialStore {
  MishiCredentialStore({required this.file});

  /// Default retain filename. The moderator must only ever see this one file,
  /// always on the Desktop — never a repo, build, tmp, or numbered copy.
  static const fileName = 'mishi_credentials.txt';

  final File file;

  /// True for `mishi_credentials.txt`, `mishi_credentials 2.txt`, `mishi_creds.txt`.
  static bool isCredentialFileName(String name) {
    final base = name.toLowerCase();
    return base.startsWith('mishi_cred') && base.endsWith('.txt');
  }

  /// Desktop folder that receives the setup-strings txt on download / first launch.
  static Directory desktopDirectory({Directory? desktopDir, String? home}) {
    if (desktopDir != null) return desktopDir;
    final root = (home ?? Platform.environment['HOME'] ?? '').trim();
    if (root.isEmpty) {
      return Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}Desktop',
      );
    }
    return Directory('$root${Platform.pathSeparator}Desktop');
  }

  static File desktopFile({Directory? desktopDir, String? home}) {
    final dir = desktopDirectory(desktopDir: desktopDir, home: home);
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Places exactly one [fileName] on the Desktop. Migrates content from any
  /// shadow copy, then deletes every other `mishi_cred*.txt` the user could see.
  static File ensureOnDesktop({
    Directory? desktopDir,
    String? home,
    String username = '',
    String password = '',
    List<Directory>? extraSearchRoots,
  }) {
    final dest = desktopFile(desktopDir: desktopDir, home: home);
    dest.parent.createSync(recursive: true);
    final roots = <Directory>[
      dest.parent,
      ...?extraSearchRoots,
      if (desktopDir == null && home == null) ..._productionShadowRoots(),
    ];
    String? migrated;
    for (final found in _listCredentialFiles(roots)) {
      if (_samePath(found, dest)) continue;
      if (migrated == null && dest.existsSync()) {
        final existing = dest.readAsStringSync();
        if (existing.trim().isNotEmpty) migrated = existing;
      }
      if (migrated == null && found.existsSync()) {
        final raw = found.readAsStringSync();
        if (raw.trim().isNotEmpty) migrated = raw;
      }
      try {
        found.deleteSync();
      } on FileSystemException {
        // Best-effort: a locked shadow must not block the Desktop file.
      }
    }
    if (!dest.existsSync()) {
      dest.writeAsStringSync(
        migrated ??
            MishiFirstRunGuide.template(username: username, password: password),
      );
    }
    return dest;
  }

  /// User-visible `mishi_cred*.txt` files after [ensureOnDesktop] (tests assert 1).
  static List<File> userVisibleCredentialFiles({
    Directory? desktopDir,
    String? home,
    List<Directory>? extraSearchRoots,
  }) {
    final dest = desktopFile(desktopDir: desktopDir, home: home);
    final roots = <Directory>[
      dest.parent,
      ...?extraSearchRoots,
      if (desktopDir == null && home == null) ..._productionShadowRoots(),
    ];
    return _listCredentialFiles(roots);
  }

  static List<Directory> _productionShadowRoots() {
    final sep = Platform.pathSeparator;
    final cwd = Directory.current.path;
    final tmp = Directory.systemTemp.path;
    final home = (Platform.environment['HOME'] ?? '').trim();
    return [
      Directory.current,
      Directory('$cwd${sep}mishi'),
      Directory('$cwd${sep}build${sep}mishi'),
      Directory.systemTemp,
      Directory('$tmp${sep}mishi'),
      if (home.isNotEmpty) Directory(home),
      if (home.isNotEmpty) Directory('$home${sep}Documents'),
      if (home.isNotEmpty) Directory('$home${sep}Downloads'),
    ];
  }

  static List<File> _listCredentialFiles(Iterable<Directory> roots) {
    final seen = <String>{};
    final out = <File>[];
    for (final root in roots) {
      if (!root.existsSync()) continue;
      List<FileSystemEntity> entries;
      try {
        entries = root.listSync(followLinks: false);
      } on FileSystemException {
        continue;
      }
      for (final entry in entries) {
        if (entry is! File) continue;
        if (!isCredentialFileName(entry.uri.pathSegments.last)) continue;
        final key = entry.absolute.path;
        if (!seen.add(key)) continue;
        out.add(entry);
      }
    }
    return out;
  }

  static bool _samePath(File a, File b) => a.absolute.path == b.absolute.path;

  /// Writes username + password and returns the record that was stored.
  MishiCredentialRecord write({
    required String username,
    required String password,
  }) {
    final record = MishiCredentialRecord(
      username: username.trim(),
      password: password,
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(_encode(record));
    return record;
  }

  /// Reads the last retained username/password. Empty file → empty record.
  MishiCredentialRecord read() {
    if (!file.existsSync()) {
      return const MishiCredentialRecord(username: '', password: '');
    }
    return _decode(file.readAsStringSync());
  }

  static String _encode(MishiCredentialRecord record) {
    return 'username=${record.username}\npassword=${record.password}\n';
  }

  static MishiCredentialRecord _decode(String raw) {
    var username = '';
    var password = '';
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trimRight();
      if (trimmed.startsWith('username=')) {
        username = trimmed.substring('username='.length);
      } else if (trimmed.startsWith('password=')) {
        password = trimmed.substring('password='.length);
      }
    }
    return MishiCredentialRecord(username: username, password: password);
  }
}
