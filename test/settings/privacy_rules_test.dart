import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/pages/settings/privacy_rules.dart';

void main() {
  group('privacy rules', () {
    test('every choice reads back as itself', () {
      for (final visibility in PrivacyVisibility.values) {
        expect(visibilityOf(rulesFor(visibility)), visibility);
      }
    });

    test('reads TDLib response casing', () {
      expect(
        visibilityOf(const [
          {'@type': 'UserPrivacySettingRuleAllowContacts'},
          {'@type': 'UserPrivacySettingRuleRestrictAll'},
        ]),
        PrivacyVisibility.contacts,
      );
    });

    test('an exception list before the broad rule is ignored', () {
      expect(
        visibilityOf(const [
          {
            '@type': 'UserPrivacySettingRuleAllowUsers',
            'userIds': [1, 2],
          },
          {'@type': 'UserPrivacySettingRuleRestrictAll'},
        ]),
        PrivacyVisibility.nobody,
      );
    });

    test('an empty rule list is the closed state', () {
      expect(visibilityOf(const []), PrivacyVisibility.nobody);
    });

    test('requests use lowercase-first type names', () {
      for (final visibility in PrivacyVisibility.values) {
        for (final rule in rulesFor(visibility)) {
          final type = rule['@type'] as String;
          expect(type[0], type[0].toLowerCase(), reason: type);
        }
      }
    });

    test('finding by phone number cannot be closed off', () {
      final rule = privacyRules().firstWhere(
        (rule) =>
            rule.setting == 'userPrivacySettingAllowFindingByPhoneNumber',
      );
      expect(rule.choices, isNot(contains(PrivacyVisibility.nobody)));
    });
  });
}
