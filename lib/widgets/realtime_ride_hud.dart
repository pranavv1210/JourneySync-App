import 'package:flutter/material.dart';

import '../coordinators/active_ride_coordinator.dart';
import '../coordinators/realtime_coordinator.dart';
import '../models/presence_info.dart';

/// Premium real-time ride heads-up display with glassmorphism cards.
///
/// Shows:
/// - Current Riders count
/// - Leader name
/// - Ride Duration
/// - Connection quality
/// - Tracking active status
/// - GPS quality
/// - Presence indicators
class RealtimeRideHUD extends StatelessWidget {
  const RealtimeRideHUD({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ActiveRideCoordinator.instance,
        RealtimeCoordinator.instance,
      ]),
      builder: (context, _) {
        final snapshot = ActiveRideCoordinator.instance.snapshot;
        final realtimeState = RealtimeCoordinator.instance.connectionState;
        final presenceList = RealtimeCoordinator.instance.presenceList;

        if (!snapshot.hasActiveRide) return const SizedBox.shrink();

        final onlineCount =
            presenceList
                .where((p) => p.status == RiderPresenceStatus.online)
                .length;
        final trackingCount =
            presenceList
                .where((p) => p.status == RiderPresenceStatus.tracking)
                .length;
        final leaderName =
            snapshot.members.where((m) => m.isHost).firstOrNull?.name ??
            'Leader';
        final totalMembers = snapshot.members.length;

        if (compact) {
          return _buildCompactHUD(
            onlineCount: onlineCount,
            trackingCount: trackingCount,
            totalMembers: totalMembers,
            leaderName: leaderName,
            connectionState: realtimeState,
          );
        }

        return _buildFullHUD(
          onlineCount: onlineCount,
          trackingCount: trackingCount,
          totalMembers: totalMembers,
          leaderName: leaderName,
          connectionState: realtimeState,
          snapshot: snapshot,
        );
      },
    );
  }

  Widget _buildCompactHUD({
    required int onlineCount,
    required int trackingCount,
    required int totalMembers,
    required String leaderName,
    required RealtimeConnectionState connectionState,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(
            color: _connectionColor(connectionState),
            label: _connectionLabel(connectionState),
          ),
          const SizedBox(width: 12),
          _StatItem(
            icon: Icons.people_rounded,
            value: '$totalMembers',
            label: 'riders',
          ),
          const SizedBox(width: 12),
          _StatItem(
            icon: Icons.track_changes_rounded,
            value: '$trackingCount',
            label: 'live',
          ),
        ],
      ),
    );
  }

  Widget _buildFullHUD({
    required int onlineCount,
    required int trackingCount,
    required int totalMembers,
    required String leaderName,
    required RealtimeConnectionState connectionState,
    required ActiveRideSnapshot snapshot,
  }) {
    final durationText = _formatDuration(snapshot);
    final isTracking = trackingCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row: connection + leader
          Row(
            children: [
              _StatusDot(
                color: _connectionColor(connectionState),
                label: _connectionLabel(connectionState),
              ),
              const Spacer(),
              _GlassChip(
                icon: Icons.star_rounded,
                label: leaderName,
                color: const Color(0xFF1E3A2F),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Middle row: rider metrics
          Row(
            children: [
              _MetricTile(
                icon: Icons.people_rounded,
                value: '$totalMembers',
                label: 'Riders',
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 12),
              _MetricTile(
                icon: Icons.track_changes_rounded,
                value: '$trackingCount',
                label: 'Tracking',
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 12),
              _MetricTile(
                icon: Icons.wifi_rounded,
                value: durationText,
                label: 'Duration',
                color: const Color(0xFFD46211),
              ),
            ],
          ),
          if (isTracking) ...[
            const SizedBox(height: 12),
            // Bottom row: GPS quality + online
            Row(
              children: [
                _GlassChip(
                  icon: Icons.gps_fixed_rounded,
                  label: 'GPS Active',
                  color: const Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                _GlassChip(
                  icon: Icons.circle_rounded,
                  label: '$onlineCount online',
                  color: const Color(0xFF16A34A),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(ActiveRideSnapshot snapshot) {
    // If we don't have a start time, show a placeholder
    if (snapshot.status == ActiveRideStatus.active) {
      return 'LIVE';
    }
    return '--:--';
  }

  Color _connectionColor(RealtimeConnectionState state) {
    return switch (state) {
      RealtimeConnectionState.connected => const Color(0xFF16A34A),
      RealtimeConnectionState.syncing => const Color(0xFF2563EB),
      RealtimeConnectionState.offline => const Color(0xFF6B7280),
      RealtimeConnectionState.reconnecting => const Color(0xFFF97316),
      RealtimeConnectionState.connecting => const Color(0xFF2563EB),
      RealtimeConnectionState.disconnected => const Color(0xFF6B7280),
    };
  }

  String _connectionLabel(RealtimeConnectionState state) {
    return switch (state) {
      RealtimeConnectionState.connected => 'Live',
      RealtimeConnectionState.syncing => 'Syncing',
      RealtimeConnectionState.offline => 'Offline',
      RealtimeConnectionState.reconnecting => 'Reconnecting',
      RealtimeConnectionState.connecting => 'Connecting',
      RealtimeConnectionState.disconnected => 'Offline',
    };
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: const Color(0xFF1E3A2F).withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Color(0xFF1E3A2F),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: const Color(0xFF1E3A2F).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: const Color(0xFF1E3A2F),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: const Color(0xFF1E3A2F).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
