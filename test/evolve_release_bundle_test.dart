import 'dart:io';

import 'package:evolve/perc/evolve_release_bundle.dart';
import 'package:evolve/perc/perc_app_version.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

final _scratch = Platform.environment['SCRATCH'] ??
    '/var/folders/qb/tz4y4zts04z4846pbq95l6kw0000gp/T/grok-goal-3dace18184e6/implementer';

void _writeLog(String filename, String body) {
  Directory(_scratch).createSync(recursive: true);
  File('$_scratch${Platform.pathSeparator}$filename').writeAsStringSync(body);
}

String _pubspecVersion() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version:\s*([0-9.]+\+\d+)', multiLine: true)
      .firstMatch(pubspec);
  if (match == null) {
    fail('pubspec.yaml missing version: line');
  }
  return match.group(1)!;
}

void main() {
  test('machine-split record names this Mac and the Windows laptop', () {
    final split = File(
      '${evolveRepoRoot()}${Platform.pathSeparator}docs'
      '${Platform.pathSeparator}MACHINE_SPLIT.md',
    );
    expect(split.existsSync(), isTrue);
    final body = split.readAsStringSync();
    expect(body, contains('this Mac → Android + macOS + iOS'));
    expect(
      body,
      contains('the Windows laptop → Windows + Linux + Arch Linux'),
    );
    expect(EvolveReleaseBundle.thisMacLabel, 'this Mac');
    expect(EvolveReleaseBundle.windowsLaptopLabel, 'Windows laptop');
    expect(
      EvolveReleaseBundle.thisMacPlatforms,
      ['android', 'macos', 'ios'],
    );
    expect(
      EvolveReleaseBundle.windowsLaptopPlatforms,
      ['windows', 'linux', 'archlinux'],
    );
    _writeLog(
      'machine-split.log',
      body,
    );
  });

  test('current version pin drives Mac-owned bundle membership', () {
    expect(PercAppVersion.current, _pubspecVersion());
    expect(
      EvolveReleaseBundle.currentRelease,
      PercAppVersion.releaseOf(PercAppVersion.current),
    );

    final repo = Directory(evolveRepoRoot());
    final membership = EvolveReleaseBundle.inspect(repo);

    expect(membership.release, PercAppVersion.releaseOf(PercAppVersion.current));
    expect(
      membership.bundleRelativePath,
      'build/downloads/v${membership.release}',
    );
    expect(membership.laptopPackagesRequired, isFalse);
    expect(
      EvolveReleaseBundle.laptopPackagesRequiredOnThisMac,
      isFalse,
    );

    final macNames = EvolveReleaseBundle.macOwnedPackageBasenames();
    expect(macNames, hasLength(3));
    for (final name in macNames) {
      expect(name, contains('v${membership.release}'));
      expect(EvolveReleaseBundle.isRequiredOnThisMac(name), isTrue);
    }
    for (final name in EvolveReleaseBundle.laptopOwnedPackageBasenames()) {
      expect(EvolveReleaseBundle.isRequiredOnThisMac(name), isFalse);
    }

    expect(
      membership.missingMacOwned,
      isEmpty,
      reason:
          'Mac-owned packages must live in ${membership.bundleRelativePath}',
    );
    expect(
      membership.macOwnedOnlyInOtherVersionFolders,
      isEmpty,
      reason: 'must not live only under a different v* folder',
    );
    expect(membership.presentMacOwned, unorderedEquals(macNames));
    expect(membership.macOwnedComplete, isTrue);

    final listing = membership.bundleDirectory
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toList()
      ..sort();
    expect(membership.release, '4.1.12');
    expect(PercAppVersion.buildOf(PercAppVersion.current), greaterThan(178));
    _writeLog(
      'bundle-4.1.12-mac.log',
      'release=${membership.release}\n'
      'pin=${PercAppVersion.current}\n'
      'bundle=${membership.bundleDirectory.path}\n'
      'present=${membership.presentMacOwned.join(",")}\n'
      'missing=${membership.missingMacOwned.join(",")}\n'
      'onlyElsewhere=${membership.macOwnedOnlyInOtherVersionFolders.join(",")}\n'
      'laptopRequired=${membership.laptopPackagesRequired}\n'
      'listing=${listing.join(",")}\n',
    );
  });
}
