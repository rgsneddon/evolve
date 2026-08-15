import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/perc_public_endpoint.dart';

void main() {
  test('detects loopback and private hosts', () {
    expect(PercPublicEndpoint.isLoopbackOrPrivateHost('127.0.0.1'), isTrue);
    expect(PercPublicEndpoint.isLoopbackOrPrivateHost('localhost'), isTrue);
    expect(PercPublicEndpoint.isLoopbackOrPrivateHost('192.168.1.4'), isTrue);
    expect(PercPublicEndpoint.isLoopbackOrPrivateHost('10.0.0.2'), isTrue);
    expect(PercPublicEndpoint.isLoopbackOrPrivateHost('172.16.0.1'), isTrue);
    expect(PercPublicEndpoint.isLoopbackOrPrivateHost('203.0.113.10'), isFalse);
  });

  test('detects internet endpoints', () {
    expect(
      PercPublicEndpoint.isInternetEndpoint('http://203.0.113.10:9477'),
      isTrue,
    );
    expect(
      PercPublicEndpoint.isInternetEndpoint('http://127.0.0.1:9477'),
      isFalse,
    );
  });

  test('rejects cleartext public :9477 as a chain hop', () {
    expect(
      PercPublicEndpoint.isUnreachableCleartextPublicNode(
        'http://217.142.21.226:9477',
      ),
      isTrue,
    );
    expect(
      PercPublicEndpoint.isChainFetchEndpoint('http://217.142.21.226:9477'),
      isFalse,
    );
    expect(
      PercPublicEndpoint.isChainFetchEndpoint('http://203.0.113.10:9477'),
      isFalse,
    );
    expect(
      PercPublicEndpoint.isChainFetchEndpoint(
        'https://135.181.152.10.sslip.io/perc',
      ),
      isTrue,
    );
    expect(
      PercPublicEndpoint.isChainFetchEndpoint('http://127.0.0.1:12345'),
      isTrue,
    );
  });

  test('preferredChainFetchEndpoint keeps rendezvous over dead :9477', () {
    expect(
      PercPublicEndpoint.preferredChainFetchEndpoint(
        rendezvousUrl: 'https://135.181.152.10.sslip.io/perc',
        advertised: const [
          'http://217.142.21.226:9477',
          'http://203.0.113.10:9477',
        ],
      ),
      'https://135.181.152.10.sslip.io/perc',
    );
    expect(
      PercPublicEndpoint.chainFetchEndpoints(const [
        'http://217.142.21.226:9477',
        'https://135.181.152.10.sslip.io/perc',
        'http://127.0.0.1:9',
      ]),
      [
        'https://135.181.152.10.sslip.io/perc',
        'http://127.0.0.1:9',
      ],
    );
  });
}