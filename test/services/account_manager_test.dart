import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/account_manager.dart';

void main() {
  group('nextAccountId', () {
    test('starts at the default account id', () {
      expect(nextAccountId(const []), 1);
    });

    test('follows the highest id, not the count', () {
      const accounts = [
        Account(id: 1, directory: ''),
        Account(id: 5, directory: 'account_5'),
      ];

      expect(nextAccountId(accounts), 6);
    });

    test('never reuses the id of a removed account', () {
      const remaining = [Account(id: 3, directory: 'account_3')];

      // Accounts 1 and 2 were removed; their directories must not be adopted.
      expect(nextAccountId(remaining), 4);
    });
  });

  group('accountDirectory', () {
    test('is distinct per account', () {
      expect(accountDirectory(2), isNot(accountDirectory(3)));
    });
  });

  group('Account', () {
    test('is disposable only while explicitly marked pending', () {
      const added = Account(id: 2, directory: 'account_2', isPending: true);

      expect(added.isPending, isTrue);
      expect(added.copyWith(isPending: false).isPending, isFalse);
    });

    test('a missing user id does not make an account disposable', () {
      // At startup no client has answered `getMe` yet. Reading "no user id"
      // as "never signed in" let a switch close and forget a real account.
      const signedIn = Account(id: 1, directory: '');

      expect(signedIn.userId, 0);
      expect(signedIn.isPending, isFalse);
    });

    test('keeps its directory through copyWith', () {
      const legacy = Account(id: 1, directory: '');

      final signedIn = legacy.copyWith(userId: 7, name: 'Ada');

      // The legacy account's database is the documents directory itself, so
      // losing the empty value here would point it at a fresh, empty database.
      expect(signedIn.directory, '');
      expect(signedIn.id, 1);
    });
  });

  group('encodeAccounts / decodeAccounts', () {
    test('round-trips every field', () {
      const accounts = [
        Account(id: 1, directory: ''),
        Account(
          id: 4,
          directory: 'account_4',
          userId: 99,
          name: 'Grace Hopper',
          phoneNumber: '15550100',
        ),
      ];

      final decoded = decodeAccounts(encodeAccounts(accounts));

      expect(decoded.length, 2);
      expect(decoded.first.directory, '');
      expect(decoded.last.name, 'Grace Hopper');
      expect(decoded.last.phoneNumber, '15550100');
      expect(decoded.last.userId, 99);
    });

    test('returns nothing for a missing value', () {
      expect(decodeAccounts(null), isEmpty);
      expect(decodeAccounts(''), isEmpty);
    });

    test('discards an unreadable value instead of throwing', () {
      // A corrupt list must fall back to "no accounts", which makes the app
      // adopt the legacy database rather than crash on launch.
      expect(decodeAccounts('not json'), isEmpty);
      expect(decodeAccounts('{"id":1}'), isEmpty);
    });

    test('fills in fields written by an older build', () {
      final decoded = decodeAccounts('[{"id":2,"directory":"account_2"}]');

      expect(decoded.single.userId, 0);
      expect(decoded.single.name, '');
      // A record from a build without the flag is a signed-in account, never
      // a leftover to be discarded.
      expect(decoded.single.isPending, isFalse);
    });

    test('round-trips the pending flag', () {
      const added = [Account(id: 3, directory: 'account_3', isPending: true)];

      expect(decodeAccounts(encodeAccounts(added)).single.isPending, isTrue);
    });
  });
}
