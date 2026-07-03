import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_qr_address_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String confidentialAddress;
  late String legacyAddress;

  setUp(() {
    confidentialAddress = PercAuth.deriveAddress('alice', 'salt-a');
    legacyAddress = 'perc1${'a' * 40}';
  });

  test('parses plain confidential address', () {
    expect(PercQrAddressParser.parse(confidentialAddress), confidentialAddress);
  });

  test('parses address embedded in longer text', () {
    final payload = 'PERC:$confidentialAddress';
    expect(PercQrAddressParser.parse(payload), confidentialAddress);
  });

  test('parses address from uri query', () {
    final uri = 'evolve://send?address=$confidentialAddress';
    expect(PercQrAddressParser.parse(uri), confidentialAddress);
  });

  test('rejects invalid qr payload', () {
    expect(PercQrAddressParser.parse('not-a-wallet-address'), isNull);
    expect(PercQrAddressParser.parse(legacyAddress), isNull);
  });
}