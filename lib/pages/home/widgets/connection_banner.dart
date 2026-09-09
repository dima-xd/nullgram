import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// An app-bar title that turns into a connection status while TDLib is not
/// ready.
///
/// Telegram replaces the title with "Connecting…" / "Updating…" instead of
/// showing a separate banner, because a silent lack of new messages is
/// otherwise indistinguishable from a quiet chat list.
class ConnectionTitle extends StatelessWidget {
  const ConnectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: TDLibClient.connectionStateUpdates,
      builder: (context, snapshot) {
        final status = _describe(snapshot.data);
        if (status == null) return Text(title);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(status),
          ],
        );
      },
    );
  }

  /// A user-facing label for a non-ready connection state, or null once TDLib
  /// is connected and up to date.
  static String? _describe(String? state) => switch (state) {
        'ConnectionStateWaitingForNetwork' => 'Waiting for network…',
        'ConnectionStateConnectingToProxy' => 'Connecting to proxy…',
        'ConnectionStateConnecting' => 'Connecting…',
        'ConnectionStateUpdating' => 'Updating…',
        _ => null,
      };
}
