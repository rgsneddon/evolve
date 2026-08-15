import 'dart:io';

import 'package:evolve/fcg/mishi/mishi_approve.dart';
import 'package:evolve/fcg/mishi/mishi_credentials.dart';
import 'package:evolve/fcg/mishi/mishi_first_run.dart';
import 'package:evolve/fcg/mishi/mishi_rpai.dart';
import 'package:evolve/fcg/mishi/mishi_surface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mishi-logic-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('txt document retains username password and reads them back', () {
    final file = File('${tempDir.path}/${MishiCredentialStore.fileName}');
    expect(file.existsSync(), isFalse);
    final store = MishiCredentialStore(file: file);
    final empty = store.read();
    expect(empty.username, '');
    expect(empty.password, '');

    final written = store.write(username: 'mod_ainsdale', password: 'ward-pass-1');
    expect(written.username, 'mod_ainsdale');
    expect(written.password, 'ward-pass-1');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('username=mod_ainsdale'));
    expect(file.readAsStringSync(), contains('password=ward-pass-1'));

    final reread = MishiCredentialStore(file: file).read();
    expect(reread.username, 'mod_ainsdale');
    expect(reread.password, 'ward-pass-1');
  });

  test('download / first launch places setup strings on the Desktop', () {
    final desktop = Directory('${tempDir.path}${Platform.pathSeparator}Desktop');
    expect(desktop.existsSync(), isFalse);
    final placed = MishiCredentialStore.ensureOnDesktop(desktopDir: desktop);
    expect(placed.existsSync(), isTrue);
    expect(placed.path, endsWith('Desktop${Platform.pathSeparator}${MishiCredentialStore.fileName}'));
    expect(placed.readAsStringSync(), contains('username='));
    expect(placed.readAsStringSync(), contains('password='));
    final again = MishiCredentialStore.ensureOnDesktop(desktopDir: desktop);
    expect(again.path, placed.path);
    expect(
      MishiCredentialStore.desktopFile(desktopDir: desktop).path,
      placed.path,
    );
  });

  test('user sees exactly one mishi_cred txt — shadows are deleted', () {
    final sep = Platform.pathSeparator;
    final desktop = Directory('${tempDir.path}${sep}Desktop')..createSync();
    final repo = Directory('${tempDir.path}${sep}mishi')..createSync();
    final build = Directory('${tempDir.path}${sep}build${sep}mishi')
      ..createSync(recursive: true);
    final tmp = Directory('${tempDir.path}${sep}tmp${sep}mishi')
      ..createSync(recursive: true);
    File('${desktop.path}${sep}mishi_credentials.txt')
        .writeAsStringSync('username=keep\npassword=secret\n');
    File('${desktop.path}${sep}mishi_credentials 2.txt')
        .writeAsStringSync('username=dup\npassword=\n');
    File('${repo.path}${sep}mishi_credentials.txt')
        .writeAsStringSync('username=repo\npassword=\n');
    File('${build.path}${sep}mishi_credentials.txt')
        .writeAsStringSync('username=build\npassword=\n');
    File('${tmp.path}${sep}mishi_credentials.txt')
        .writeAsStringSync('username=tmp\npassword=\n');

    final roots = [desktop, repo, build, tmp, tempDir];
    final kept = MishiCredentialStore.ensureOnDesktop(
      desktopDir: desktop,
      extraSearchRoots: roots,
    );
    expect(kept.path, endsWith('Desktop${sep}mishi_credentials.txt'));
    expect(kept.readAsStringSync(), contains('username=keep'));
    final visible = MishiCredentialStore.userVisibleCredentialFiles(
      desktopDir: desktop,
      extraSearchRoots: roots,
    );
    expect(visible, hasLength(1));
    expect(visible.single.path, kept.path);
    expect(File('${desktop.path}${sep}mishi_credentials 2.txt').existsSync(), isFalse);
    expect(File('${repo.path}${sep}mishi_credentials.txt').existsSync(), isFalse);
    expect(File('${build.path}${sep}mishi_credentials.txt').existsSync(), isFalse);
    expect(File('${tmp.path}${sep}mishi_credentials.txt').existsSync(), isFalse);
  });

  test('first-open guide tells the mod which Desktop username to register with', () {
    const rec = MishiCredentialRecord(username: 'mod_ainsdale', password: 'ward-pass');
    const path = '/Users/mod/Desktop/mishi_credentials.txt';
    final guide = MishiFirstRunGuide(record: rec, filePath: path);
    expect(guide.needsGuide, isFalse);
    expect(guide.usernameToUse, 'mod_ainsdale');
    expect(guide.usernameAdvice, contains('mod_ainsdale'));
    expect(guide.usernameAdvice, contains('Desktop txt'));
    expect(guide.steps.first, contains(path));
    expect(guide.steps[3], contains('WRITE CREDENTIALS'));

    const empty = MishiCredentialRecord(username: '', password: '');
    final emptyGuide = MishiFirstRunGuide(record: empty, filePath: path);
    expect(emptyGuide.needsGuide, isTrue);
    expect(emptyGuide.usernameAdvice, contains('username='));
  });

  test('approve grants only the named forum month and voting epoch pair', () {
    final book = MishiAccessBook();
    const user = 'voter.alice';
    book.requestAccess(
      username: user,
      forumMonth: '2026-08',
      votingEpoch: 'epoch-2026-08-w1',
    );
    expect(
      book.hasAccess(
        username: user,
        forumMonth: '2026-08',
        votingEpoch: 'epoch-2026-08-w1',
      ),
      isFalse,
    );

    book.approve(
      username: user,
      forumMonth: '2026-08',
      votingEpoch: 'epoch-2026-08-w1',
    );
    expect(
      book.hasAccess(
        username: user,
        forumMonth: '2026-08',
        votingEpoch: 'epoch-2026-08-w1',
      ),
      isTrue,
    );
    expect(
      book.hasAccess(
        username: user,
        forumMonth: '2026-08',
        votingEpoch: 'epoch-2026-08-w2',
      ),
      isFalse,
    );
    expect(
      book.hasAccess(
        username: user,
        forumMonth: '2026-09',
        votingEpoch: 'epoch-2026-08-w1',
      ),
      isFalse,
    );
    expect(
      book.hasAccess(
        username: 'voter.bob',
        forumMonth: '2026-08',
        votingEpoch: 'epoch-2026-08-w1',
      ),
      isFalse,
    );
  });

  test('unapproved and denied users stay denied', () {
    final book = MishiAccessBook();
    book.requestAccess(
      username: 'pending.user',
      forumMonth: '2026-08',
      votingEpoch: 'epoch-a',
    );
    book.deny(
      username: 'denied.user',
      forumMonth: '2026-08',
      votingEpoch: 'epoch-a',
    );
    expect(
      book.hasAccess(
        username: 'pending.user',
        forumMonth: '2026-08',
        votingEpoch: 'epoch-a',
      ),
      isFalse,
    );
    expect(
      book.hasAccess(
        username: 'denied.user',
        forumMonth: '2026-08',
        votingEpoch: 'epoch-a',
      ),
      isFalse,
    );
    expect(
      book.hasAccess(
        username: 'ghost.user',
        forumMonth: '2026-08',
        votingEpoch: 'epoch-a',
      ),
      isFalse,
    );
  });

  test('rpAI tab is part of the Mishi surface model', () {
    final surface = MishiSurfaceModel();
    expect(MishiSurfaceModel.tabs, contains(MishiTab.rpai));
    expect(surface.hasRpaiTab, isTrue);
    expect(surface.tabLabels, contains('rpAI'));
    expect(MishiThemeTokens.darkOnly, isTrue);
    expect(MishiThemeTokens.themeToggleAllowed, isFalse);
    surface.select(MishiTab.rpai);
    expect(surface.active, MishiTab.rpai);
  });
}
