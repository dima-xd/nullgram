class MessageFormatter {
  static String formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
