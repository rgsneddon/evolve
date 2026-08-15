import 'dart:io';

import 'perc_app_version.dart';

/// GitHub-commit release-bundle membership for the two-machine Evolve split.
///
/// This Mac produces Android, macOS, and iOS. The Windows laptop produces
/// Windows, Linux, and Arch Linux. Membership is driven by
/// [PercAppVersion.current] so Mac packages must sit in that version’s folder.
class EvolveReleaseBundle {
  const EvolveReleaseBundle._();

  static const String thisMacLabel = 'this Mac';
  static const String windowsLaptopLabel = 'Windows laptop';

  /// Platforms this Mac produces for a GitHub-commit bundle.
  static const List<String> thisMacPlatforms = ['android', 'macos', 'ios'];

  /// Platforms the Windows laptop produces — not required on this Mac.
  static const List<String> windowsLaptopPlatforms = [
    'windows',
    'linux',
    'archlinux',
  ];

  static String get currentRelease =>
      PercAppVersion.releaseOf(PercAppVersion.current);

  static String get bundleDirectoryName => 'v$currentRelease';

  /// Canonical staging dir used by `scripts/build_*_installer.ps1`.
  static String get bundleRelativePath =>
      'build/downloads/$bundleDirectoryName';

  /// Installer-script basenames for this Mac’s commit deliverables.
  static List<String> macOwnedPackageBasenames([String? release]) {
    final v = release ?? currentRelease;
    return [
      'evolve-v$v-android-setup.apk',
      'evolve-v$v-macos-x64.zip',
      'evolve-v$v-ios-setup.ipa',
    ];
  }

  /// Laptop-owned basenames — never required on this Mac.
  static List<String> laptopOwnedPackageBasenames([String? release]) {
    final v = release ?? currentRelease;
    return [
      'evolve-v$v-windows-x64-setup.exe',
      'evolve-v$v-linux-x64.tar.gz',
      'evolve-v$v-archlinux-x64.tar.gz',
    ];
  }

  static bool isRequiredOnThisMac(String basename) =>
      macOwnedPackageBasenames().contains(basename);

  static bool get laptopPackagesRequiredOnThisMac => false;

  /// Inspects the shipped current-version folder (not another `v*`).
  static EvolveReleaseBundleMembership inspect(Directory repoRoot) {
    final release = currentRelease;
    final relative = bundleRelativePath;
    final bundleDir = Directory(
      '${repoRoot.path}${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}',
    );
    final macNames = macOwnedPackageBasenames(release);
    final present = <String>[];
    final missing = <String>[];
    final onlyElsewhere = <String>[];

    for (final name in macNames) {
      final here = File(
        '${bundleDir.path}${Platform.pathSeparator}$name',
      );
      if (here.existsSync()) {
        present.add(name);
        continue;
      }
      missing.add(name);
      if (_existsInOtherVersionFolder(repoRoot, release, name)) {
        onlyElsewhere.add(name);
      }
    }

    return EvolveReleaseBundleMembership(
      release: release,
      bundleRelativePath: relative,
      bundleDirectory: bundleDir,
      presentMacOwned: present,
      missingMacOwned: missing,
      macOwnedOnlyInOtherVersionFolders: onlyElsewhere,
      laptopPackagesRequired: laptopPackagesRequiredOnThisMac,
    );
  }

  static bool _existsInOtherVersionFolder(
    Directory repoRoot,
    String release,
    String basename,
  ) {
    final downloads = Directory(
      '${repoRoot.path}${Platform.pathSeparator}build'
      '${Platform.pathSeparator}downloads',
    );
    if (!downloads.existsSync()) return false;
    for (final entity in downloads.listSync()) {
      if (entity is! Directory) continue;
      final name = entity.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last;
      if (!name.startsWith('v') || name == 'v$release') continue;
      if (File('${entity.path}${Platform.pathSeparator}$basename')
          .existsSync()) {
        return true;
      }
    }
    return false;
  }
}

class EvolveReleaseBundleMembership {
  const EvolveReleaseBundleMembership({
    required this.release,
    required this.bundleRelativePath,
    required this.bundleDirectory,
    required this.presentMacOwned,
    required this.missingMacOwned,
    required this.macOwnedOnlyInOtherVersionFolders,
    required this.laptopPackagesRequired,
  });

  final String release;
  final String bundleRelativePath;
  final Directory bundleDirectory;
  final List<String> presentMacOwned;
  final List<String> missingMacOwned;
  final List<String> macOwnedOnlyInOtherVersionFolders;
  final bool laptopPackagesRequired;

  bool get macOwnedComplete =>
      missingMacOwned.isEmpty && macOwnedOnlyInOtherVersionFolders.isEmpty;
}
