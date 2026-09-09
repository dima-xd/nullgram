/// Delivery options for an outgoing message.
///
/// Covers the two things Telegram offers behind a long press on the send
/// button: sending without making the recipient's device ring, and scheduling
/// the message instead of sending it now.
class SendOptions {
  const SendOptions({
    this.silent = false,
    this.sendAtDate,
    this.sendWhenOnline = false,
  });

  /// Send now, with a notification — what a plain tap on send does.
  static const SendOptions normal = SendOptions();

  /// Send now, but don't notify the recipients.
  static const SendOptions silentNow = SendOptions(silent: true);

  /// Deliver as soon as the recipient comes online.
  static const SendOptions whenOnline = SendOptions(sendWhenOnline: true);

  /// Whether to suppress the recipient's notification.
  final bool silent;

  /// When to send, or null for "now" / [sendWhenOnline].
  final DateTime? sendAtDate;

  /// Whether to hold the message until the recipient is online. Ignored when
  /// [sendAtDate] is set, which TDLib treats as the more specific request.
  final bool sendWhenOnline;

  /// Whether the message goes to the chat's scheduled list rather than its
  /// history.
  bool get isScheduled => sendAtDate != null || sendWhenOnline;

  /// The TDLib `messageSendOptions` object, or null when nothing needs
  /// overriding — TDLib's defaults are what a plain send wants.
  Map<String, dynamic>? toJson() {
    if (!silent && !isScheduled) return null;
    return {
      "@type": "messageSendOptions",
      "disableNotification": silent,
      if (sendAtDate != null)
        "schedulingState": {
          "@type": "messageSchedulingStateSendAtDate",
          "sendDate": sendAtDate!.millisecondsSinceEpoch ~/ 1000,
        }
      else if (sendWhenOnline)
        "schedulingState": {
          "@type": "messageSchedulingStateSendWhenOnline",
        },
    };
  }
}
