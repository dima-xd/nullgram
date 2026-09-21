import 'package:nullgram/tdlib/constants.dart';

/// One TDLib notification inside a group.
class NotificationEntry {
  const NotificationEntry({
    required this.id,
    required this.date,
    required this.isSilent,
    required this.type,
  });

  /// TDLib's id, unique inside its group and needed to remove it again.
  final int id;

  /// Unix seconds, as TDLib reports them.
  final int date;

  final bool isSilent;

  /// The raw `notificationType*` object, rendered by `notification_text.dart`.
  final Map<String, dynamic> type;

  static NotificationEntry? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    if (id == null) return null;
    return NotificationEntry(
      id: id,
      date: (json['date'] as num?)?.toInt() ?? 0,
      isSilent: json['isSilent'] as bool? ?? false,
      type: (json['type'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// One notification group of one account, which becomes one Android
/// notification.
class NotificationGroup {
  const NotificationGroup({
    required this.accountId,
    required this.groupId,
    required this.chatId,
    required this.totalCount,
    required this.notifications,
  });

  final int accountId;
  final int groupId;
  final int chatId;
  final int totalCount;
  final List<NotificationEntry> notifications;
}

/// A group that no longer exists and whose notification must be cancelled.
typedef RemovedGroup = ({int accountId, int groupId});

/// What one update changed.
class NotificationChange {
  const NotificationChange({required this.updated, required this.removed});

  const NotificationChange.none() : updated = const [], removed = const [];

  final List<NotificationGroup> updated;
  final List<RemovedGroup> removed;
}

/// The notification groups of every account, mirroring what TDLib reports.
class NotificationGroups {
  final Map<String, NotificationGroup> _groups = {};

  /// Every known group, of every account.
  List<NotificationGroup> get groups => List.unmodifiable(_groups.values);

  /// The group [groupId] of [accountId], or null when it is not shown.
  NotificationGroup? group(int accountId, int groupId) =>
      _groups[_key(accountId, groupId)];

  /// Folds [update] in and reports what changed.
  NotificationChange apply(Map<String, dynamic> update, int accountId) {
    switch (update['@type']) {
      case updateActiveNotificationsConst:
        return _applyActive(update, accountId);
      case updateNotificationGroupConst:
        return _applyGroup(update, accountId);
      default:
        return const NotificationChange.none();
    }
  }

  /// Drops every group of [accountId], for a sign-out.
  List<RemovedGroup> clearAccount(int accountId) {
    final removed = [
      for (final group in _groups.values)
        if (group.accountId == accountId)
          (accountId: group.accountId, groupId: group.groupId),
    ];
    for (final entry in removed) {
      _groups.remove(_key(entry.accountId, entry.groupId));
    }
    return removed;
  }

  /// The startup snapshot: anything it does not name is stale and gets
  /// cancelled.
  NotificationChange _applyActive(Map<String, dynamic> update, int accountId) {
    final previous = {
      for (final group in _groups.values)
        if (group.accountId == accountId) group.groupId,
    };

    final updated = <NotificationGroup>[];
    for (final raw in (update['groups'] as List? ?? const [])) {
      final json = (raw as Map).cast<String, dynamic>();
      final groupId = (json['id'] as num?)?.toInt();
      if (groupId == null) continue;

      final notifications = _sorted([
        for (final entry in (json['notifications'] as List? ?? const []))
          if (NotificationEntry.fromJson((entry as Map).cast()) case final e?)
            e,
      ]);
      // An empty group is an absent one, so it is left for the sweep below to
      // remove: a stored group always holds at least one notification.
      if (notifications.isEmpty) continue;

      final group = NotificationGroup(
        accountId: accountId,
        groupId: groupId,
        chatId: (json['chatId'] as num?)?.toInt() ?? 0,
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        notifications: notifications,
      );
      _groups[_key(accountId, groupId)] = group;
      previous.remove(groupId);
      updated.add(group);
    }

    for (final groupId in previous) {
      _groups.remove(_key(accountId, groupId));
    }

    return NotificationChange(
      updated: updated,
      removed: [
        for (final groupId in previous)
          (accountId: accountId, groupId: groupId),
      ],
    );
  }

  NotificationChange _applyGroup(Map<String, dynamic> update, int accountId) {
    final groupId = (update['notificationGroupId'] as num?)?.toInt();
    if (groupId == null) return const NotificationChange.none();

    final key = _key(accountId, groupId);
    final existing = _groups[key];

    final removedIds = {
      for (final id
          in (update['removedNotificationIds'] as List? ?? const []))
        if (id is num) id.toInt(),
    };
    final added = [
      for (final entry in (update['addedNotifications'] as List? ?? const []))
        if (NotificationEntry.fromJson((entry as Map).cast()) case final e?) e,
    ];

    final notifications = _sorted([
      for (final entry in existing?.notifications ?? const [])
        if (!removedIds.contains(entry.id)) entry,
      ...added,
    ]);

    if (notifications.isEmpty) {
      _groups.remove(key);
      return NotificationChange(
        updated: const [],
        removed: [(accountId: accountId, groupId: groupId)],
      );
    }

    final group = NotificationGroup(
      accountId: accountId,
      groupId: groupId,
      chatId: (update['chatId'] as num?)?.toInt() ?? existing?.chatId ?? 0,
      totalCount:
          (update['totalCount'] as num?)?.toInt() ?? notifications.length,
      notifications: notifications,
    );
    _groups[key] = group;
    return NotificationChange(updated: [group], removed: const []);
  }

  /// Oldest first, which is the order `MessagingStyle` expects.
  List<NotificationEntry> _sorted(List<NotificationEntry> entries) {
    final sorted = [...entries]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    return List.unmodifiable(sorted);
  }

  String _key(int accountId, int groupId) => '$accountId:$groupId';
}
