import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/widgets/region_flag.dart';

void main() {
  test('UK, USA, and Europe regions are listed with flag assets', () {
    final ids = LocaleConfig.regions.map((r) => r.id).toList();
    expect(ids, contains('uk_ireland'));
    expect(ids, contains('usa'));
    expect(ids, contains('europe'));
    expect(ids.indexOf('uk_ireland'), lessThan(ids.indexOf('americas')));
    expect(ids.indexOf('usa'), lessThan(ids.indexOf('americas')));
    expect(ids.indexOf('europe'), lessThan(ids.indexOf('mena')));
  });

  testWidgets('RegionFlag renders UK, US, and EU image assets', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              RegionFlag(regionId: 'uk_ireland'),
              RegionFlag(regionId: 'usa'),
              RegionFlag(regionId: 'europe'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNWidgets(3));
  });
}