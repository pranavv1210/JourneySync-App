import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/rider_location.dart';
import '../models/ride_route.dart';
import '../services/group_ride_intelligence.dart';
import 'haptic_button.dart';

class RealtimeRideHUD extends StatefulWidget {
  const RealtimeRideHUD({
    super.key,
    required this.riderLocations,
    required this.groupSnapshot,
    required this.currentUserId,
    required this.leaderId,
    required this.secondsElapsed,
    required this.distanceTravelled,
    required this.currentSpeed,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.altitude,
    required this.gpsQuality,
    required this.isOffline,
    required this.followingLeader,
    required this.onFollowLeaderToggled,
    required this.onEndRide,
    required this.canEndRide,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.pitStops,
    required this.onAddPitStop,
  });

  final List<RiderLocation> riderLocations;
  final GroupRideSnapshot groupSnapshot;
  final String currentUserId;
  final String? leaderId;
  final int secondsElapsed;
  final double distanceTravelled;
  final double currentSpeed;
  final double avgSpeed;
  final double maxSpeed;
  final double altitude;
  final String gpsQuality;
  final bool isOffline;
  final bool followingLeader;
  final ValueChanged<bool> onFollowLeaderToggled;
  final VoidCallback onEndRide;
  final bool canEndRide;
  final double? currentLatitude;
  final double? currentLongitude;
  final List<RouteStop> pitStops;
  final Function(String type, String name, double lat, double lng) onAddPitStop;

  @override
  State<RealtimeRideHUD> createState() => _RealtimeRideHUDState();
}

class _RealtimeRideHUDState extends State<RealtimeRideHUD> {
  bool _isExpanded = false;
  int _selectedTab = 0; // 0 = Dashboard, 1 = Pack, 2 = Stops

  String _formatDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Color _getConnectionColor(String quality) {
    switch (quality) {
      case 'Excellent':
        return const Color(0xFF10B981);
      case 'Good':
        return const Color(0xFF3B82F6);
      case 'Weak':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  Color _getBatteryColor(String batteryStr) {
    try {
      final value = int.parse(batteryStr.replaceAll('%', '').trim());
      if (value > 60) return const Color(0xFF10B981);
      if (value > 20) return const Color(0xFFF59E0B);
      return const Color(0xFFEF4444);
    } catch (_) {
      return AppColors.textSecondary;
    }
  }

  bool _isCurrentUserHost() {
    return widget.leaderId != null && widget.leaderId == widget.currentUserId;
  }

  void _showAddStopDialog() {
    final nameCtrl = TextEditingController();
    String selectedType = 'Tea';

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Create Pit Stop',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select stop category:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    items:
                        <String>['Tea', 'Food', 'Rest'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text('$value Stop'),
                          );
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Stop Name / Description',
                      hintText: 'e.g. Starbucks, Highway Shell',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isNotEmpty &&
                        widget.currentLatitude != null &&
                        widget.currentLongitude != null) {
                      widget.onAddPitStop(
                        selectedType,
                        name,
                        widget.currentLatitude!,
                        widget.currentLongitude!,
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Add & Sync'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => nameCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final double panelHeight = _isExpanded ? 500.0 : 96.0;
    final String connectionLabel =
        widget.isOffline
            ? 'Offline'
            : widget.groupSnapshot.totalRiders == 0
            ? 'Connecting'
            : GroupRideIntelligence.healthLabel(
              widget.groupSnapshot.healthRating,
            );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      height: panelHeight,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniStat(
                              icon: Icons.speed_rounded,
                              value:
                                  '${widget.currentSpeed.toStringAsFixed(0)} km/h',
                              label: 'Speed',
                              color: AppColors.primary,
                            ),
                            _buildMiniStat(
                              icon: Icons.route_outlined,
                              value:
                                  '${widget.distanceTravelled.toStringAsFixed(1)} km',
                              label: 'Distance',
                              color: const Color(0xFF2563EB),
                            ),
                            _buildMiniStat(
                              icon: Icons.timer_outlined,
                              value: _formatDuration(widget.secondsElapsed),
                              label: 'Duration',
                              color: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                if (_isExpanded) ...[
                  const Divider(height: 1, thickness: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: _buildTabs(),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildDashboardTab(connectionLabel),
                        _buildPackTab(),
                        _buildStopsTab(),
                      ],
                    ),
                  ),
                  if (widget.canEndRide)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: HapticButton(
                        label: 'End Ride Session',
                        icon: Icons.cancel_rounded,
                        variant: HapticButtonVariant.danger,
                        onPressed: widget.onEndRide,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Text(
                        'Only the host can end the ride session.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ["Dashboard", "Pack", "Stops"];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedTab == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = idx;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? AppShadows.sm : null,
                ),
                child: Text(
                  tabs[idx],
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall.copyWith(
                    color:
                        isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDashboardTab(String connectionLabel) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'GARMIN HUD LIVE',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.0,
              ),
            ),
            if (widget.leaderId != null &&
                widget.leaderId != widget.currentUserId)
              Row(
                children: [
                  Text(
                    'Follow Leader',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 24,
                    width: 40,
                    child: Switch(
                      value: widget.followingLeader,
                      onChanged: widget.onFollowLeaderToggled,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            _buildHUDCard(
              'Avg Speed',
              '${widget.groupSnapshot.averageSpeedKmh.toStringAsFixed(1)} km/h',
              Icons.analytics_rounded,
            ),
            _buildHUDCard(
              'Group Spread',
              GroupRideIntelligence.formatDistance(
                widget.groupSnapshot.groupSpreadMeters,
              ),
              Icons.open_in_full_rounded,
            ),
            _buildHUDCard(
              'Slowest',
              widget.groupSnapshot.slowestRider?.location.userName ?? '--',
              Icons.trending_down_rounded,
            ),
            _buildHUDCard(
              'Fastest',
              widget.groupSnapshot.fastestRider?.location.userName ?? '--',
              Icons.bolt_rounded,
            ),
            _buildHUDCard(
              'Health',
              connectionLabel,
              Icons.signal_cellular_alt_rounded,
            ),
            _buildHUDCard(
              'Tracking',
              '${widget.groupSnapshot.trackingRiders}/${widget.groupSnapshot.totalRiders}',
              Icons.group_work_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPackTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'RIDER PACK LIST',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            Text(
              '${widget.groupSnapshot.trackingRiders} Tracking',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...widget.groupSnapshot.riders.map((snapshot) {
          final rider = snapshot.location;
          final isLeader = rider.userId == widget.leaderId || rider.isLeader;
          final isMe = rider.userId == widget.currentUserId;
          final connQuality = GroupRideIntelligence.qualityLabel(
            snapshot.connectionQuality,
          );
          final distance = snapshot.distanceFromLeaderMeters;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isLeader
                      ? const Color(0xFFFFF7ED).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isLeader
                        ? const Color(0xFFFFD6A5)
                        : Colors.white.withValues(alpha: 0.7),
                width: isLeader ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          isLeader
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFEFF6FF),
                      backgroundImage:
                          rider.avatarUrl?.trim().isNotEmpty == true
                              ? NetworkImage(rider.avatarUrl!.trim())
                              : null,
                      child:
                          rider.avatarUrl?.trim().isNotEmpty == true
                              ? null
                              : Text(
                                rider.userName.isNotEmpty
                                    ? rider.userName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isLeader
                                          ? AppColors.primary
                                          : Colors.blue.shade700,
                                ),
                              ),
                    ),
                    if (isLeader)
                      Positioned(
                        top: -10,
                        left: -4,
                        child: Transform.rotate(
                          angle: -0.2,
                          child: const Text(
                            '👑',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            rider.userName,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isLeader) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'LEADER',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'YOU',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rider.bikeName,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLeader
                            ? 'Leading pack'
                            : '${snapshot.leaderRelation} • ETA ${GroupRideIntelligence.formatDuration(snapshot.etaToLeader)}',
                        style: AppTypography.caption.copyWith(
                          color:
                              snapshot.leaderRelation == 'off-route'
                                  ? Colors.red.shade700
                                  : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        if (rider.battery != null) ...[
                          Icon(
                            Icons.battery_4_bar_rounded,
                            size: 14,
                            color: _getBatteryColor(rider.battery!),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rider.battery!,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          Icons.circle_rounded,
                          size: 10,
                          color: _getConnectionColor(connQuality),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          connQuality,
                          style: AppTypography.labelSmall.copyWith(
                            color: _getConnectionColor(connQuality),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${rider.speedKmh?.toStringAsFixed(0) ?? '0'} km/h',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isLeader && distance > 0.0) ...[
                          const SizedBox(width: 8),
                          Text(
                            GroupRideIntelligence.formatDistance(distance),
                            style: AppTypography.labelSmall.copyWith(
                              color:
                                  snapshot.leaderRelation == 'ahead'
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStopsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE PIT STOPS',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.0,
              ),
            ),
            if (_isCurrentUserHost())
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _showAddStopDialog,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Add Pit Stop',
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.pitStops.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No pit stops created yet.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          ...widget.pitStops.map((stop) {
            IconData icon = Icons.local_cafe_rounded;
            Color color = Colors.brown;
            String cleanName = stop.label;

            if (stop.label.contains(':')) {
              final parts = stop.label.split(':');
              final type = parts[0].trim().toLowerCase();
              cleanName = parts.sublist(1).join(':').trim();
              if (type == 'tea') {
                icon = Icons.local_cafe_rounded;
                color = Colors.brown;
              } else if (type == 'food') {
                icon = Icons.restaurant_rounded;
                color = Colors.red;
              } else if (type == 'rest') {
                icon = Icons.airline_seat_flat_rounded;
                color = Colors.blue;
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  cleanName,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Stop #${stop.order}',
                  style: AppTypography.caption,
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.navigation_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed:
                      stop.latitude != null && stop.longitude != null
                          ? () => _openMap(stop.latitude!, stop.longitude!)
                          : null,
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHUDCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
