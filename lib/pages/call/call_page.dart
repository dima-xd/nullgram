import 'package:flutter/material.dart';

import '../../services/call_models.dart';
import '../../services/call_service.dart';
import '../../tdlib/tdlib_client.dart';

/// Full-screen call UI driven by [CallService]. Adapts to ringing / active.
class CallPage extends StatelessWidget {
  const CallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: callService,
          builder: (context, _) {
            final call = callService.current;
            if (call == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: TDLibClient.getUser(userId: call.userId),
                    builder: (context, snap) {
                      final name = snap.data?['firstName'] as String? ?? '';
                      final last = snap.data?['lastName'] as String? ?? '';
                      return Text(
                        '$name $last'.trim(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 28),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusLabel(call),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (call.emojis.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      call.emojis.join(' '),
                      style: const TextStyle(fontSize: 30),
                    ),
                  ],
                  const Spacer(),
                  _Controls(call: call),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _statusLabel(CurrentCall call) => switch (call.uiState) {
        CallUiState.ringingOut => 'Calling…',
        CallUiState.ringingIn => 'Incoming call',
        CallUiState.exchangingKeys => 'Exchanging keys…',
        CallUiState.active => 'Connected',
        CallUiState.ending => 'Ending…',
        CallUiState.ended => 'Call ended',
        CallUiState.error => call.errorMessage ?? 'Call failed',
      };
}

class _Controls extends StatelessWidget {
  const _Controls({required this.call});
  final CurrentCall call;

  @override
  Widget build(BuildContext context) {
    if (call.uiState == CallUiState.ringingIn) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            color: Colors.red,
            icon: Icons.call_end,
            onTap: callService.hangUp,
          ),
          _RoundButton(
            color: Colors.green,
            icon: Icons.call,
            onTap: callService.accept,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          color: call.isMuted ? Colors.white30 : Colors.white12,
          icon: call.isMuted ? Icons.mic_off : Icons.mic,
          onTap: callService.toggleMute,
        ),
        _RoundButton(
          color: Colors.red,
          icon: Icons.call_end,
          onTap: callService.hangUp,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: CircleAvatar(
        radius: 32,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
