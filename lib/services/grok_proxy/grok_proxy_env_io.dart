import 'dart:io';

Map<String, String>? _fileEnv;

/// Platform env first, then [grok_proxy.local.env] in cwd or parent folders.
String? readEnv(String key) {
  final platform = Platform.environment[key];
  if (platform != null && platform.trim().isNotEmpty) return platform.trim();
  _ensureFileEnvLoaded();
  return _fileEnv![key];
}

void _ensureFileEnvLoaded() {
  if (_fileEnv != null) return;
  _fileEnv = {};
  for (final path in _localEnvCandidates()) {
    final file = File(path);
    if (!file.existsSync()) continue;
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final name = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      if (value.isNotEmpty) _fileEnv![name] = value;
    }
    return;
  }
}

List<String> _localEnvCandidates() {
  final cwd = Directory.current.path;
  final candidates = <String>[
    'grok_proxy.local.env',
    '../grok_proxy.local.env',
    '../../grok_proxy.local.env',
  ];
  try {
    final exe = Platform.resolvedExecutable;
    if (exe.isNotEmpty) {
      final exeDir = File(exe).parent.path;
      candidates.insert(0, '$exeDir${Platform.pathSeparator}grok_proxy.local.env');
    }
  } catch (_) {}
  final script = Platform.script.toFilePath();
  if (script.isNotEmpty) {
    var dir = File(script).parent.path;
    for (var i = 0; i < 4; i++) {
      candidates.add('$dir${Platform.pathSeparator}grok_proxy.local.env');
      final parent = Directory(dir).parent.path;
      if (parent == dir) break;
      dir = parent;
    }
  }
  candidates.add('$cwd${Platform.pathSeparator}grok_proxy.local.env');
  return candidates.toSet().toList();
}