import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// Who a privacy setting lets through.
enum PrivacyVisibility { everybody, contacts, nobody }

/// One privacy setting: its TDLib name, its label and the choices it accepts.
class PrivacyRule {
  const PrivacyRule({
    required this.setting,
    required this.label,
    this.allowNobody = true,
  });

  /// The lowercase-first TDLib `userPrivacySetting*` name.
  final String setting;

  final String Function(BuildContext context) label;

  /// False for settings TDLib refuses to close off entirely.
  final bool allowNobody;

  List<PrivacyVisibility> get choices => allowNobody
      ? PrivacyVisibility.values
      : const [PrivacyVisibility.everybody, PrivacyVisibility.contacts];
}

/// The settings offered, in the order Telegram lists them.
List<PrivacyRule> privacyRules() => [
      PrivacyRule(
        setting: 'userPrivacySettingShowStatus',
        label: (context) => context.l10n.privacyLastSeen,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingShowProfilePhoto',
        label: (context) => context.l10n.privacyProfilePhoto,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingShowBio',
        label: (context) => context.l10n.bio,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingShowPhoneNumber',
        label: (context) => context.l10n.phoneNumber,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingAllowFindingByPhoneNumber',
        label: (context) => context.l10n.privacyFindByPhone,
        allowNobody: false,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingShowLinkInForwardedMessages',
        label: (context) => context.l10n.privacyForwardedMessages,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingAllowCalls',
        label: (context) => context.l10n.calls,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingAllowPeerToPeerCalls',
        label: (context) => context.l10n.privacyPeerToPeerCalls,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingAllowChatInvites',
        label: (context) => context.l10n.privacyGroupInvites,
      ),
      PrivacyRule(
        setting: 'userPrivacySettingAllowPrivateVoiceAndVideoNoteMessages',
        label: (context) => context.l10n.privacyVoiceMessages,
      ),
    ];

/// Reads a rule list back as the choice that produced it, ignoring the
/// per-user and per-chat exception lists.
PrivacyVisibility visibilityOf(List<Map<String, dynamic>> rules) {
  for (final rule in rules) {
    // Responses are PascalCase and requests lowercase-first, and this reads
    // both so a value can be checked against what was just sent.
    switch ((rule['@type'] as String? ?? '').toLowerCase()) {
      case 'userprivacysettingruleallowall':
        return PrivacyVisibility.everybody;
      case 'userprivacysettingruleallowcontacts':
        return PrivacyVisibility.contacts;
      case 'userprivacysettingrulerestrictall':
        return PrivacyVisibility.nobody;
    }
  }
  return PrivacyVisibility.nobody;
}

/// The rules that express [visibility], in TDLib request casing.
List<Map<String, dynamic>> rulesFor(PrivacyVisibility visibility) {
  switch (visibility) {
    case PrivacyVisibility.everybody:
      return [
        {'@type': 'userPrivacySettingRuleAllowAll'},
      ];
    case PrivacyVisibility.contacts:
      return [
        {'@type': 'userPrivacySettingRuleAllowContacts'},
        {'@type': 'userPrivacySettingRuleRestrictAll'},
      ];
    case PrivacyVisibility.nobody:
      return [
        {'@type': 'userPrivacySettingRuleRestrictAll'},
      ];
  }
}

String visibilityLabel(BuildContext context, PrivacyVisibility visibility) {
  switch (visibility) {
    case PrivacyVisibility.everybody:
      return context.l10n.privacyEverybody;
    case PrivacyVisibility.contacts:
      return context.l10n.privacyMyContacts;
    case PrivacyVisibility.nobody:
      return context.l10n.privacyNobody;
  }
}

/// A row that shows who a setting currently lets through and changes it.
class PrivacyRuleTile extends StatefulWidget {
  const PrivacyRuleTile({super.key, required this.rule});

  final PrivacyRule rule;

  @override
  State<PrivacyRuleTile> createState() => _PrivacyRuleTileState();
}

class _PrivacyRuleTileState extends State<PrivacyRuleTile> {
  final ValueNotifier<PrivacyVisibility?> _visibility = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _visibility.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rules = await TDLibClient.getUserPrivacySettingRules(
      setting: widget.rule.setting,
    );
    if (!mounted) return;
    _visibility.value = visibilityOf(rules);
  }

  Future<void> _choose() async {
    final current = _visibility.value;
    final chosen = await showModalBottomSheet<PrivacyVisibility>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<PrivacyVisibility>(
          groupValue: current,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final choice in widget.rule.choices)
                RadioListTile<PrivacyVisibility>(
                  value: choice,
                  title: Text(visibilityLabel(sheetContext, choice)),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || chosen == current) return;

    // Shown as applied right away; the reload below puts back what TDLib kept.
    _visibility.value = chosen;
    await TDLibClient.setUserPrivacySettingRules(
      setting: widget.rule.setting,
      rules: rulesFor(chosen),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PrivacyVisibility?>(
      valueListenable: _visibility,
      builder: (context, visibility, child) => ListTile(
        title: Text(widget.rule.label(context)),
        subtitle: visibility == null
            ? null
            : Text(visibilityLabel(context, visibility)),
        trailing: const Icon(Icons.chevron_right),
        onTap: visibility == null ? null : _choose,
      ),
    );
  }
}
