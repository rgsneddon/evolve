import 'package:flutter_test/flutter_test.dart';

import 'package:evolve/perc/services/perc_account_privacy.dart';

void main() {
  test('obfuscateUsername returns stable five-character aliases', () {
    final a = PercAccountPrivacy.obfuscateUsername('alice');
    final b = PercAccountPrivacy.obfuscateUsername('alice');
    final c = PercAccountPrivacy.obfuscateUsername('bob');
    expect(a, b);
    expect(a, isNot(c));
    expect(a.length, PercAccountPrivacy.aliasLength);
    expect(a, matches(RegExp(r'^[A-Za-z0-9]{5}$')));
  });

  test('sanitizeLedgerForPublic strips credentials and obfuscates usernames', () {
    final sanitized = PercAccountPrivacy.sanitizeLedgerForPublic({
      'sessionUsername': 'alice',
      'accounts': {
        'alice': {
          'username': 'alice',
          'passwordHash': 'secret',
          'salt': 'secret',
          'passwordSet': true,
          'address': 'percpriv1abc',
          'balance': {'microUnits': 1},
          'transactions': [
            {
              'fromUsername': 'alice',
              'toUsername': 'bob',
            },
          ],
        },
      },
      'blocks': [
        {
          'triggerUsername': 'alice',
          'transactions': [
            {'fromUsername': 'alice', 'toUsername': 'bob'},
          ],
        },
      ],
    });

    final keys = (sanitized['accounts'] as Map).keys.toList();
    expect(keys, isNot(contains('alice')));
    expect(keys.first.length, PercAccountPrivacy.aliasLength);

    final account = (sanitized['accounts'] as Map).values.first as Map;
    expect(account.containsKey('passwordHash'), isFalse);
    expect(account.containsKey('salt'), isFalse);
    expect(account.containsKey('passwordSet'), isFalse);
    expect(account['username'], keys.first);
  });

  test('sanitizeLedgerForPublic obfuscates ward proposal and ballot usernames', () {
    final sanitized = PercAccountPrivacy.sanitizeLedgerForPublic({
      'wardProposals': [
        {'id': 'p1', 'proposerUsername': 'alice', 'title': 'Test'},
      ],
      'wardBallots': [
        {'proposalId': 'p1', 'voterUsername': 'bob', 'choice': 'forProposal'},
      ],
    });

    final proposal = (sanitized['wardProposals'] as List).first as Map;
    final ballot = (sanitized['wardBallots'] as List).first as Map;
    expect(proposal['proposerUsername'], isNot('alice'));
    expect(proposal['proposerUsername'].toString().length, 5);
    expect(ballot['voterUsername'], isNot('bob'));
    expect(ballot['voterUsername'].toString().length, 5);
  });

  test('sanitizeLedgerForPublic aliases treasury account key', () {
    final sanitized = PercAccountPrivacy.sanitizeLedgerForPublic({
      'accounts': {
        'evolve_treasury': {
          'username': 'evolve_treasury',
          'passwordHash': 'secret',
          'salt': 'secret',
          'passwordSet': true,
          'address': 'percpriv1treasury',
          'balance': {'microUnits': 1},
          'transactions': [],
        },
      },
    });
    final alias =
        PercAccountPrivacy.obfuscateUsername('evolve_treasury');
    expect((sanitized['accounts'] as Map).containsKey(alias), isTrue);
    expect((sanitized['accounts'] as Map).containsKey('evolve_treasury'),
        isFalse);
  });

  test('publicDisplayName hides other users but keeps viewer name', () {
    expect(
      PercAccountPrivacy.publicDisplayName('alice', viewerUsername: 'alice'),
      'alice',
    );
    expect(
      PercAccountPrivacy.publicDisplayName('bob', viewerUsername: 'alice').length,
      PercAccountPrivacy.aliasLength,
    );
  });
}