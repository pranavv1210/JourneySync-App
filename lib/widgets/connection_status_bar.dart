import 'package:flutter/material.dart';

import '../coordinators/realtime_coordinator.dart';

class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({
    super.key,
    required this.state,
    this.compact = false,
  });

  final RealtimeConnectionState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(state);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 20,
        vertical: compact ? 0 : 6,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: spec.color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: spec.color, active: spec.pulsing),
          const SizedBox(width: 8),
          Text(
            spec.label,
            style: TextStyle(
              color: spec.color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _ConnectionSpec _specFor(RealtimeConnectionState state) {
    return switch (state) {
      RealtimeConnectionState.connected => const _ConnectionSpec(
        label: 'Realtime active',
        color: Color(0xFF16A34A),
        pulsing: true,
      ),
      RealtimeConnectionState.syncing => const _ConnectionSpec(
        label: 'Syncing',
        color: Color(0xFF2563EB),
        pulsing: true,
      ),
      RealtimeConnectionState.offline => const _ConnectionSpec(
        label: 'Offline',
        color: Color(0xFF6B7280),
        pulsing: false,
      ),
      RealtimeConnectionState.reconnecting => const _ConnectionSpec(
        label: 'Reconnecting',
        color: Color(0xFFF97316),
        pulsing: true,
      ),
      RealtimeConnectionState.connecting => const _ConnectionSpec(
        label: 'Connecting',
        color: Color(0xFF2563EB),
        pulsing: true,
      ),
      RealtimeConnectionState.disconnected => const _ConnectionSpec(
        label: 'Disconnected',
        color: Color(0xFF6B7280),
        pulsing: false,
      ),
    };
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.active ? 0.75 + (_controller.value * 0.35) : 0.8;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(
                    alpha: widget.active ? 0.45 : 0,
                  ),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionSpec {
  const _ConnectionSpec({
    required this.label,
    required this.color,
    required this.pulsing,
  });

  final String label;
  final Color color;
  final bool pulsing;
}
