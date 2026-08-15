import 'dart:io';

import 'package:evolve/fcg/mishi/mishi_approve.dart';
import 'package:evolve/fcg/mishi/mishi_first_run.dart';
import 'package:evolve/fcg/mishi/mishi_surface.dart';
import 'package:evolve/fcg/mishi/mishi_rpai.dart';
import 'package:evolve/mishi_desktop/mishi_app.dart';
import 'package:evolve/perc/services/perc_action_block.dart';
import 'package:evolve/perc/services/perc_explorer_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MishiApp is dark-only yellow CLI with rpAI tab', (tester) async {
    final creds = File('test/mishi_widget_creds.txt');
    creds.writeAsStringSync(
      MishiFirstRunGuide.template(username: 'mod_ainsdale', password: 'ward'),
    );
    addTearDown(() {
      if (creds.existsSync()) creds.deleteSync();
    });
    await tester.pumpWidget(
      MishiApp(
        credentialFile: creds,
        book: MishiAccessBook(),
        learner: RpaiLearner(),
        chain: PercActionChain(),
        explorer: PercExplorerConfirm(
          chain: PercActionChain(),
          learner: RpaiLearner(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MishiApp), findsOneWidget);
    expect(find.byType(MishiHome), findsOneWidget);
    expect(find.text('MISHI'), findsOneWidget);
    expect(find.text('DARK LOCKED'), findsOneWidget);
    expect(find.text('mishi@evolve — cli'), findsOneWidget);
    expect(find.byKey(const ValueKey('mishi-tab-rpai')), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, MishiApp.bg);
    expect(MishiThemeTokens.darkOnly, isTrue);
    expect(MishiThemeTokens.themeToggleAllowed, isFalse);

    await tester.tap(find.byKey(const ValueKey('mishi-tab-rpai')));
    await tester.pump();
    expect(find.textContaining('NED'), findsWidgets);
    expect(find.textContaining('best-in-class'), findsOneWidget);
  });
}
