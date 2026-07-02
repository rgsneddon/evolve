import 'dart:io';

Map<String, String>? _fileEnv;

const _dartDefineEnv = <String, String>{
  'X_CLIENT_ID': String.fromEnvironment('X_CLIENT_ID'),
  'X_CLIENT_SECRET': String.fromEnvironment('X_CLIENT_SECRET'),
  'XAI_API_KEY': String.fromEnvironment('XAI_API_KEY'),
  'GROK_PROXY_MOCK': String.fromEnvironment('GROK_PROXY_MOCK'),
  'GROK_PROXY_PUBLIC_URL': String.fromEnvironment('GROK_PROXY_PUBLIC_URL'),
  'XAI_CONSTRUAL_MODEL': String.fromEnvironment('XAI_CONSTRUAL_MODEL'),
};

/// Build-time defines, platform env, then [grok_proxy.local.env] in cwd or parents.
String? readEnv(String key) {
  final fromDefine = _dartDefineEnv[key]?.trim();
  if (fromDefine != null && fromDefine.isNotEmpty) return fromDefine;

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
  final candidates = <String>[];
  final seen = <String>{};

  void add(String path) {
    final normalized = path.replaceAll('/', Platform.pathSeparator);
    if (seen.add(normalized)) candidates.add(normalized);
  }

  void walkParents(String start, {int maxDepth = 12}) {
    if (start.isEmpty) return;
    var dir = start;
    for (var i = 0; i < maxDepth; i++) {
      add('$dir${Platform.pathSeparator}grok_proxy.local.env');
      final parent = Directory(dir).parent.path;
      if (parent == dir) break;
      dir = parent;
    }
  }

  // Release desktop shortcuts run evolve.exe deep under build/ — walk up to project root.
  try {
    final exe = Platform.resolvedExecutable;
    if (exe.isNotEmpty) {
      walkParents(File(exe).parent.path);
    }
  } catch (_) {}

  try {
    walkParents(Directory.current.path, maxDepth: 8);
  } catch (_) {}

  try {
    final script = Platform.script.toFilePath();
    if (script.isNotEmpty) {
      walkParents(File(script).parent.path, maxDepth: 6);
    }
  } catch (_) {}

  return candidates;
}