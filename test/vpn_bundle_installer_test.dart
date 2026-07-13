import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

void main() {
  test('Inno Setup script bundles VPN runtime and post-install profile hook', () {
    final iss = evolveRepoFile('installer/windows/evolve.iss');
    final text = iss.readAsStringSync();
    expect(text, contains('MaterializeVpnProfile'));
    expect(text, contains(r'{app}\vpn\demo1.conf'));
    expect(text, contains(r'{localappdata}\EVOLVE_TUNNEL'));
    expect(text, contains('recursesubdirs'));
  });

  test('stage_vpn_bundle.ps1 stages runtime and manifest under Release/vpn', () {
    final script = evolveRepoFile('scripts/stage_vpn_bundle.ps1');
    expect(script.existsSync(), isTrue);

    final release = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}evolve_release_fixture',
    );
    if (release.existsSync()) release.deleteSync(recursive: true);
    release.createSync(recursive: true);
    File('${release.path}${Platform.pathSeparator}evolve.exe')
        .writeAsStringSync('stub');

    final result = Process.runSync(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        '-ReleaseDir',
        release.path,
      ],
      runInShell: true,
    );
    expect(
      result.exitCode,
      0,
      reason: 'stage_vpn_bundle.ps1 failed: ${result.stderr}',
    );

    final vpnDir = Directory('${release.path}${Platform.pathSeparator}vpn');
    expect(vpnDir.existsSync(), isTrue);
    expect(
      File('${vpnDir.path}${Platform.pathSeparator}wireguard.exe').existsSync(),
      isTrue,
      reason: 'bundled wireguard.exe required',
    );
    expect(
      File('${vpnDir.path}${Platform.pathSeparator}wg.exe').existsSync(),
      isTrue,
    );
    expect(
      File('${vpnDir.path}${Platform.pathSeparator}bundle.manifest.json')
          .existsSync(),
      isTrue,
    );

    final manifest = jsonDecode(
      File('${vpnDir.path}${Platform.pathSeparator}bundle.manifest.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest['runtime_staged'], isTrue);
    expect(manifest['node_endpoint'], '104.156.224.47:51820');

    if (manifest['profile_staged'] == true) {
      expect(
        File('${vpnDir.path}${Platform.pathSeparator}demo1.conf').existsSync(),
        isTrue,
      );
    }

    release.deleteSync(recursive: true);
  });

  test('staged installer output directory includes vpn bundle after packaging script',
      () {
    final manifest = evolveRepoFile('installer/windows/vpn/README.txt');
    expect(manifest.existsSync(), isTrue);
    final buildScript = evolveRepoFile('scripts/build_windows_installer.ps1');
    final buildText = buildScript.readAsStringSync();
    expect(buildText, contains('stage_vpn_bundle.ps1'));
  });
}