import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/widgets/wallet_credential_error_banner.dart';

void main() {
  testWidgets('credential error stays visible until dismiss fades it out',
      (tester) async {
    var cleared = false;
    final bannerKey = GlobalKey<WalletCredentialErrorBannerState>();

    await tester.pumpWidget(
      MaterialApp(
        home: WalletCredentialErrorScope(
          active: true,
          onDismiss: () => bannerKey.currentState?.dismiss(),
          child: Scaffold(
            body: WalletCredentialErrorBanner(
              key: bannerKey,
              errorKey: 'wallet_err_invalid_password',
              message: 'Invalid password',
              onFadeComplete: () => cleared = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Invalid password'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(cleared, isTrue);
    expect(find.text('Invalid password'), findsNothing);
  });

  test('isCredentialError matches login failures only', () {
    expect(
      WalletCredentialErrorBanner.isCredentialError('wallet_err_invalid_password'),
      isTrue,
    );
    expect(
      WalletCredentialErrorBanner.isCredentialError('wallet_err_unknown_account'),
      isTrue,
    );
    expect(
      WalletCredentialErrorBanner.isCredentialError('wallet_err_generic'),
      isFalse,
    );
  });
}