import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

File? _perccentChecksumsManifest() {
  final walletRoot = Directory(
    '${Directory(evolveRepoRoot()).parent.path}${Platform.pathSeparator}perccent_wallet',
  );
  if (!walletRoot.existsSync()) return null;
  final downloads = Directory('${walletRoot.path}${Platform.pathSeparator}build${Platform.pathSeparator}downloads');
  if (!downloads.existsSync()) return null;
  final versions = downloads
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.split(Platform.pathSeparator).last.startsWith('v'))
      .toList();
  if (versions.isEmpty) return null;
  versions.sort((a, b) {
    final av = a.path.split(Platform.pathSeparator).last.replaceFirst('v', '');
    final bv = b.path.split(Platform.pathSeparator).last.replaceFirst('v', '');
    return av.compareTo(bv);
  });
  final manifest = File(
    '${versions.last.path}${Platform.pathSeparator}checksums.json',
  );
  return manifest.existsSync() ? manifest : null;
}

void main() {
  test('downloads index matches current release wording', () {
    final pubspec = evolveRepoFile('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue);
    final pubspecText = pubspec.readAsStringSync();
    final versionMatch =
        RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)').firstMatch(pubspecText);
    expect(versionMatch, isNotNull, reason: 'pubspec version line required');
    final release = versionMatch!.group(1)!;
    final build = versionMatch.group(2)!;

    final index = evolveRepoFile('downloads/index.html');
    expect(index.existsSync(), isTrue, reason: 'downloads/index.html must exist');

    final html = index.readAsStringSync();
    expect(html, contains('v$release'));
    expect(html, contains('build $build'));
    expect(html, contains('Windows setup installer'));
    expect(html, contains('not Authenticode-signed'));
    expect(html, isNot(contains('signed setup package')));
    expect(
      html,
      contains(
        'github.com/rgsneddon/evolve/releases/download/v$release/evolve-v$release-windows-x64-setup.exe',
      ),
    );
    expect(
      html,
      contains(
        'github.com/rgsneddon/evolve/releases/download/v$release/evolve-v$release-android-setup.apk',
      ),
    );
    expect(html, contains('<article class="card ios">'));
    expect(
      html,
      contains(
        'github.com/rgsneddon/evolve/releases/download/v$release/evolve-v$release-ios-setup.ipa',
      ),
    );
  });

  test('perccent-wallet section uses perccent release checksum not evolve windows hash', () {
    final index = evolveRepoFile('downloads/index.html');
    final html = index.readAsStringSync();

    expect(html, contains('<section class="perccent-wallet">'));

    final manifestFile = _perccentChecksumsManifest();
    expect(manifestFile, isNotNull, reason: 'perccent_wallet build/downloads checksums.json required');
    final manifest = jsonDecode(manifestFile!.readAsStringSync()) as Map<String, dynamic>;
    final packages = manifest['packages'] as List<dynamic>;
    final windows = packages.cast<Map<String, dynamic>>().firstWhere(
      (p) => (p['file'] as String).contains('perccent-wallet') && (p['file'] as String).contains('windows'),
    );
    final sha256 = windows['sha256'] as String;
    final fileName = windows['file'] as String;
    final versionMatch = RegExp(r'perccent-wallet-v([0-9.]+)-').firstMatch(fileName);
    expect(versionMatch, isNotNull);
    final perccentRelease = versionMatch!.group(1)!;

    final sectionStart = html.indexOf('<section class="perccent-wallet">');
    final sectionEnd = html.indexOf('</section>', sectionStart);
    final section = html.substring(sectionStart, sectionEnd);

    expect(section, contains('id="perccent-sha256"'));
    expect(section, contains(sha256));
    expect(section, contains(fileName));
    expect(
      section,
      contains(
        'github.com/rgsneddon/perccent-wallet/releases/download/v$perccentRelease/$fileName',
      ),
    );
    expect(section, contains('id="perccent-setup-name"'));
    expect(section, contains('<code id="perccent-setup-name">$fileName</code>'));
    expect(section, isNot(contains('evolve-v')));
  });

  test('perccent-wallet section includes android installer from manifest', () {
    final index = evolveRepoFile('downloads/index.html');
    final html = index.readAsStringSync();

    final manifestFile = _perccentChecksumsManifest();
    expect(manifestFile, isNotNull, reason: 'perccent_wallet build/downloads checksums.json required');
    final manifest = jsonDecode(manifestFile!.readAsStringSync()) as Map<String, dynamic>;
    final packages = manifest['packages'] as List<dynamic>;
    final android = packages.cast<Map<String, dynamic>>().firstWhere(
      (p) => (p['file'] as String).contains('perccent-wallet') && (p['file'] as String).contains('android'),
    );
    final sha256 = android['sha256'] as String;
    final fileName = android['file'] as String;
    final versionMatch = RegExp(r'perccent-wallet-v([0-9.]+)-').firstMatch(fileName);
    expect(versionMatch, isNotNull);
    final perccentRelease = versionMatch!.group(1)!;

    final sectionStart = html.indexOf('<section class="perccent-wallet">');
    final sectionEnd = html.indexOf('</section>', sectionStart);
    final section = html.substring(sectionStart, sectionEnd);

    expect(section, contains('id="perccent-apk-sha256"'));
    expect(section, contains(sha256));
    expect(section, contains(fileName));
    expect(
      section,
      contains(
        'github.com/rgsneddon/perccent-wallet/releases/download/v$perccentRelease/$fileName',
      ),
    );
    expect(section, contains('id="perccent-apk-name"'));
    expect(section, contains('<code id="perccent-apk-name">$fileName</code>'));
    expect(section, contains('Download Android Installer'));
  });

  test('perccent-wallet section includes ios installer card', () {
    final index = evolveRepoFile('downloads/index.html');
    final html = index.readAsStringSync();

    final manifestFile = _perccentChecksumsManifest();
    expect(manifestFile, isNotNull);
    final manifest = jsonDecode(manifestFile!.readAsStringSync()) as Map<String, dynamic>;
    final packages = manifest['packages'] as List<dynamic>;
    final windows = packages.cast<Map<String, dynamic>>().firstWhere(
      (p) => (p['file'] as String).contains('perccent-wallet') && (p['file'] as String).contains('windows'),
    );
    final versionMatch = RegExp(r'perccent-wallet-v([0-9.]+)-').firstMatch(windows['file'] as String);
    expect(versionMatch, isNotNull);
    final perccentRelease = versionMatch!.group(1)!;

    final sectionStart = html.indexOf('<section class="perccent-wallet">');
    final sectionEnd = html.indexOf('</section>', sectionStart);
    final section = html.substring(sectionStart, sectionEnd);

    expect(section, contains('<article class="card ios">'));
    expect(section, contains('id="perccent-ios-name"'));
    expect(section, contains('id="perccent-ios-sha256"'));
    expect(
      section,
      contains(
        'github.com/rgsneddon/perccent-wallet/releases/download/v$perccentRelease/perccent-wallet-v$perccentRelease-ios-setup.ipa',
      ),
    );

    final iosPkg = packages.cast<Map<String, dynamic>>().where(
      (p) => (p['file'] as String).contains('ios-setup.ipa'),
    );
    if (iosPkg.isNotEmpty) {
      expect(section, contains(iosPkg.first['sha256'] as String));
    }
  });
}