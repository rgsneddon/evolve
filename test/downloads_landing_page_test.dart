import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

String _evolveAdvertisedReleaseTag(String html, String release) {
  final match = RegExp(
    'releases/download/(v[^/]+)/evolve-v${RegExp.escape(release)}-windows-x64-setup.exe',
  ).firstMatch(html);
  expect(
    match,
    isNotNull,
    reason: 'Windows Evolve card must advertise a GitHub Releases download href',
  );
  final tag = match!.group(1)!;
  expect(
    tag,
    isNot(contains('macos-ios-android')),
    reason: 'advertised bundle must not be a platform-suffix sibling',
  );
  return tag;
}

void _expectUnifiedEvolveReleaseDownloads(String html, String release) {
  final tag = _evolveAdvertisedReleaseTag(html, release);
  for (final file in [
    'evolve-v$release-windows-x64-setup.exe',
    'evolve-v$release-android-setup.apk',
    'evolve-v$release-macos-x64.zip',
    'evolve-v$release-ios-setup.ipa',
  ]) {
    expect(
      html,
      contains(
        'github.com/rgsneddon/evolve/releases/download/$tag/$file',
      ),
    );
  }
  expect(html, isNot(contains('v$release-macos-ios-android')));
}

String _perccentWalletSection(String html) {
  final marker = html.indexOf('class="perccent-wallet"');
  expect(marker, greaterThan(-1), reason: 'MY PERC section required');
  final sectionStart = html.lastIndexOf('<section', marker);
  final sectionEnd = html.indexOf('</section>', sectionStart);
  expect(sectionEnd, greaterThan(sectionStart));
  return html.substring(sectionStart, sectionEnd);
}

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
  test('download.html matches current release wording', () {
    final pubspec = evolveRepoFile('pubspec.yaml');
    final pubspecText = pubspec.readAsStringSync();
    final versionMatch =
        RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)').firstMatch(pubspecText);
    expect(versionMatch, isNotNull);
    final release = versionMatch!.group(1)!;
    final build = versionMatch.group(2)!;

    final page = evolveRepoFile('download.html');
    expect(page.existsSync(), isTrue, reason: 'download.html must exist');
    final html = page.readAsStringSync();
    expect(html, contains('v$release'));
    expect(html, contains('build $build'));
    expect(html, contains('<article class="card ios">'));
    expect(html, contains('<article class="card macos">'));
    _expectUnifiedEvolveReleaseDownloads(html, release);
    // Real package presentation — not the historical 4 KB / ~0 MB stub
    expect(html, isNot(contains('~0 MB')));
    expect(html, isNot(contains('v4.0.0')));
    expect(html, isNot(contains('Open Web App')));
    expect(html, isNot(contains('class="card web"')));
    expect(html, isNot(contains('btn-web')));
  });

  test('README and installer JSON use the same advertised 4.1.11 download tag as landing pages', () {
    final pubspec = evolveRepoFile('pubspec.yaml').readAsStringSync();
    final release =
        RegExp(r'version:\s*(\d+\.\d+\.\d+)\+').firstMatch(pubspec)!.group(1)!;
    final landing = evolveRepoFile('download.html').readAsStringSync();
    final tag = _evolveAdvertisedReleaseTag(landing, release);
    final readme = evolveRepoFile('README.md').readAsStringSync();
    _expectUnifiedEvolveReleaseDownloads(readme, release);
    expect(
      _evolveAdvertisedReleaseTag(readme, release),
      tag,
      reason: 'README must use the same GitHub release tag as download.html',
    );
    for (final meta in [
      'installer/android/evolve-v$release-android.json',
      'installer/ios/evolve-v$release-ios.json',
      'installer/macos/evolve-v$release-macos.json',
    ]) {
      final json = evolveRepoFile(meta).readAsStringSync();
      expect(
        json,
        contains('releases/download/$tag/'),
        reason: '$meta must use advertised tag $tag',
      );
      expect(json, isNot(contains('macos-ios-android')));
    }
  });

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

    final statusPath = evolveRepoFile('build/downloads/v$release/signing-status.json');
    if (statusPath.existsSync()) {
      final status = jsonDecode(statusPath.readAsStringSync()) as Map<String, dynamic>;
      final windowsSigned = (status['windows'] as Map)['authenticodeSigned'] as bool;
      final androidRelease = (status['android'] as Map)['releaseSigned'] as bool;
      if (windowsSigned) {
        expect(html, contains('Authenticode-signed'));
      } else {
        expect(html, contains('SmartScreen may ask you to confirm'));
      }
      if (androidRelease) {
        expect(html, anyOf(
          contains('release-key signed'),
          contains('Evolve release key (not debug)'),
        ));
      }
    }
    expect(html, contains('<article class="card macos">'));
    _expectUnifiedEvolveReleaseDownloads(html, release);
    expect(html, isNot(contains('~0 MB')));
    expect(html, isNot(contains('Open Web App')));
    expect(html, isNot(contains('class="card web"')));
    expect(html, isNot(contains('btn-web')));
    final perccentSection = _perccentWalletSection(html);
    expect(perccentSection, contains('<article class="card ios">'));
    expect(perccentSection, contains('<h2>iOS</h2>'));
    expect(perccentSection, contains('perccent-wallet'));
    expect(perccentSection, contains('ios-setup.ipa'));
  });

  test('perccent-wallet section uses perccent release checksum not evolve windows hash', () {
    final index = evolveRepoFile('downloads/index.html');
    final html = index.readAsStringSync();

    expect(html, contains('class="perccent-wallet"'));

    final manifestFile = _perccentChecksumsManifest();
    if (manifestFile == null) {
      return;
    }
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

    final section = _perccentWalletSection(html);

    expect(section, contains(fileName));
    expect(
      section,
      contains(
        'github.com/rgsneddon/perccent-wallet/releases/download/v$perccentRelease/$fileName',
      ),
    );
    expect(section, isNot(contains('evolve-v')));
  });

  test('perccent-wallet section includes android installer from manifest', () {
    final index = evolveRepoFile('downloads/index.html');
    final html = index.readAsStringSync();

    final manifestFile = _perccentChecksumsManifest();
    if (manifestFile == null) {
      return;
    }
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

    final section = _perccentWalletSection(html);

    expect(section, contains('android-setup.apk'));
    expect(section, contains('Download Android Installer'));
    expect(section, contains('perccent-wallet'));
    expect(fileName, contains('android-setup.apk'));
  });

  test('perccent-wallet section includes ios installer card', () {
    final index = evolveRepoFile('downloads/index.html');
    final html = index.readAsStringSync();

    final manifestFile = _perccentChecksumsManifest();
    if (manifestFile == null) {
      return;
    }
    final manifest = jsonDecode(manifestFile!.readAsStringSync()) as Map<String, dynamic>;
    final packages = manifest['packages'] as List<dynamic>;
    final iosPkg = packages.cast<Map<String, dynamic>>().firstWhere(
      (p) => (p['file'] as String).contains('ios-setup.ipa'),
      orElse: () => throw StateError('checksums.json missing ios-setup.ipa package'),
    );
    final fileName = iosPkg['file'] as String;
    final iosUrl = iosPkg['url'] as String?;
    final versionMatch = RegExp(r'perccent-wallet-v([0-9.]+)-').firstMatch(fileName);
    expect(versionMatch, isNotNull);
    final iosRelease = versionMatch!.group(1)!;
    final expectedHref = iosUrl ??
        'https://github.com/rgsneddon/perccent-wallet/releases/download/v$iosRelease/$fileName';

    final section = _perccentWalletSection(html);

    expect(section, contains('<article class="card ios">'));
    expect(section, contains(expectedHref.replaceFirst('https://', '')));
    expect(section, contains(fileName));
    expect(section, contains(iosPkg['sha256'] as String));
    expect(section, isNot(contains('~0 MB')));
  });
}