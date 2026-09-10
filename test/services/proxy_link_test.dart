import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/proxy_link.dart';

void main() {
  group('parseProxyLink', () {
    test('reads an MTProto link', () {
      final link = parseProxyLink(
        'https://t.me/proxy?server=1.2.3.4&port=443&secret=ee0011',
      );

      expect(link?.server, '1.2.3.4');
      expect(link?.port, 443);
      expect(link?.type['@type'], 'proxyTypeMtproto');
      expect(link?.type['secret'], 'ee0011');
    });

    test('reads a SOCKS link with credentials', () {
      final link = parseProxyLink(
        'https://t.me/socks?server=proxy.example&port=1080&user=me&pass=pw',
      );

      expect(link?.type['@type'], 'proxyTypeSocks5');
      expect(link?.type['username'], 'me');
      expect(link?.type['password'], 'pw');
    });

    test('reads the tg:// spelling, where the host names the kind', () {
      final link = parseProxyLink('tg://socks?server=1.2.3.4&port=1080');

      expect(link?.type['@type'], 'proxyTypeSocks5');
      // Credentials are optional for SOCKS, so an empty pair still parses.
      expect(link?.type['username'], '');
    });

    test('tolerates surrounding whitespace, as a paste often has', () {
      final link = parseProxyLink(
        '  tg://proxy?server=1.2.3.4&port=443&secret=ff \n',
      );

      expect(link?.server, '1.2.3.4');
    });

    test('rejects an MTProto link with no secret', () {
      // The secret is what identifies the proxy; without it the entry would
      // be stored and never connect.
      expect(
        parseProxyLink('https://t.me/proxy?server=1.2.3.4&port=443'),
        isNull,
      );
    });

    test('rejects a port outside the valid range', () {
      expect(
        parseProxyLink('https://t.me/socks?server=1.2.3.4&port=70000'),
        isNull,
      );
      expect(
        parseProxyLink('https://t.me/socks?server=1.2.3.4&port=0'),
        isNull,
      );
    });

    test('rejects a link with no server', () {
      expect(parseProxyLink('https://t.me/socks?port=1080'), isNull);
    });

    test('rejects a look-alike host', () {
      expect(
        parseProxyLink('https://t-me.example/socks?server=1.2.3.4&port=1080'),
        isNull,
      );
    });

    test('rejects a Telegram link that is not a proxy', () {
      expect(parseProxyLink('https://t.me/durov'), isNull);
    });

    test('rejects text that is not a link at all', () {
      expect(parseProxyLink('just some text'), isNull);
      expect(parseProxyLink(''), isNull);
    });
  });
}
