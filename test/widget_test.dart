import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/main.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/widgets/evolve_banner.dart';

void main() {
  testWidgets('app loads with both analysis modes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = EvolveProvider();
    await provider.initialize();

    await tester.pumpWidget(EvolveApp(evolveProvider: provider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Evolve'), findsOneWidget);
    expect(find.byType(EvolveBanner), findsOneWidget);
    expect(find.textContaining('SELECT THE REGION OR COUNTRY'), findsOneWidget);
    expect(find.text('YOUR SCENARIO'), findsOneWidget);
    expect(find.text('RESULTS'), findsOneWidget);
    expect(find.text('POSE YOUR QUESTION HERE (optional)'), findsOneWidget);
    expect(find.text('RUN ANALYSIS'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(2));
  });
}