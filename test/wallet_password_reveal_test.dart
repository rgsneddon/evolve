import 'dart:io';

import 'package:evolve/perc/widgets/wallet_password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth sources use WalletPasswordField with hold-to-reveal', () {
    for (final path in [
      'lib/perc/widgets/wallet_auth_panel.dart',
      'lib/perc/screens/wallet_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('WalletPasswordField'));
      expect(source, isNot(contains('obscureText: true')));
    }
    final fieldSource =
        File('lib/perc/widgets/wallet_password_field.dart').readAsStringSync();
    expect(fieldSource, contains('Listener'));
    expect(fieldSource, contains('onPointerDown'));
    expect(fieldSource, contains('Icons.visibility'));
    expect(fieldSource, contains('Icons.visibility_off'));
  });

  testWidgets('WalletPasswordField reveals password only while held', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletPasswordField(
            controller: controller,
            labelText: 'Password',
          ),
        ),
      ),
    );

    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.visibility_off)),
    );
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);

    await gesture.up();
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
  });
}