class MessageFormatter {
  static String formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Whether two unix-second timestamps fall on the same calendar day.
  static bool isSameDay(int a, int b) {
    final da = DateTime.fromMillisecondsSinceEpoch(a * 1000);
    final db = DateTime.fromMillisecondsSinceEpoch(b * 1000);
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  /// A human label for a date chip: 'Today', 'Yesterday', '12 March', or
  /// '12 March 2024' for dates in earlier years.
  static String formatDateSeparator(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(date.year, date.month, date.day);
    final dayDiff = today.difference(thatDay).inDays;

    if (dayDiff == 0) return 'Today';
    if (dayDiff == 1) return 'Yesterday';

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final monthName = months[date.month - 1];
    if (date.year == now.year) return '${date.day} $monthName';
    return '${date.day} $monthName ${date.year}';
  }

  static String formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  static String getUserStatus(Map<dynamic, dynamic> user) {
    final status = user['status'];
    if (status == null) return 'last seen recently';

    final statusType = status['@type'];

    if (statusType == 'UserStatusOnline') {
      return 'online';
    } else if (statusType == 'UserStatusOffline') {
      final wasOnline = status['wasOnline'];
      if (wasOnline != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(wasOnline * 1000);
        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inMinutes < 1) {
          return 'last seen just now';
        } else if (difference.inHours < 1) {
          return 'last seen ${difference.inMinutes} minutes ago';
        } else if (difference.inDays < 1) {
          return 'last seen ${difference.inHours} hours ago';
        } else {
          return 'last seen ${date.day}.${date.month}.${date.year}';
        }
      }
    }

    return 'last seen recently';
  }
}
