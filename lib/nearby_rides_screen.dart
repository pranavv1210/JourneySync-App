import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_toast.dart';
import 'ride_service.dart';

class NearbyRidesScreen extends StatefulWidget {
  const NearbyRidesScreen({super.key});

  @override
  State<NearbyRidesScreen> createState() => _NearbyRidesScreenState();
}

class _NearbyRidesScreenState extends State<NearbyRidesScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _emptyStateDelay = Duration(seconds: 12);

  final RideService _rideService = RideService();
  late final AnimationController _radarController;

  Timer? _emptyStateTimer;
  DateTime? _scanStartedAt;

  bool searching = true;
  bool joiningByCode = false;
  bool _showNoRidesFallback = false;
  String errorText = '';
  String currentUserId = '';
  String currentUserName = 'You';
  String currentUserAvatarUrl = '';
  String joiningRideId = '';
  List<NearbyRide> nearbyRides = <NearbyRide>[];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadNearbyRides();
  }

  @override
  void dispose() {
    _emptyStateTimer?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyRides() async {
    _emptyStateTimer?.cancel();
    _scanStartedAt = DateTime.now();
    if (!mounted) return;
    setState(() {
      searching = true;
      _showNoRidesFallback = false;
      errorText = '';
      joiningRideId = '';
      nearbyRides = <NearbyRide>[];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = (prefs.getString('userId') ?? '').trim();
      if (userId.isEmpty) {
        throw Exception('Missing user session. Please login again.');
      }

      final userName = (prefs.getString('userName') ?? 'You').trim();
      final userAvatarUrl = (prefs.getString('userAvatarUrl') ?? '').trim();

      final rides = await _rideService.searchNearbyRides(
        userId,
        requestPermissionIfNeeded: true,
      );
      if (!mounted) return;

      if (rides.isNotEmpty) {
        setState(() {
          currentUserId = userId;
          currentUserName = userName.isNotEmpty ? userName : 'You';
          currentUserAvatarUrl = userAvatarUrl;
          nearbyRides = rides;
          searching = false;
          _showNoRidesFallback = false;
        });
        return;
      }

      setState(() {
        currentUserId = userId;
        currentUserName = userName.isNotEmpty ? userName : 'You';
        currentUserAvatarUrl = userAvatarUrl;
        nearbyRides = <NearbyRide>[];
      });
      _startEmptyStateCountdown();
    } catch (error) {
      _emptyStateTimer?.cancel();
      if (!mounted) return;
      setState(() {
        errorText = _nearbyRidesFallbackMessage(error);
        searching = false;
        _showNoRidesFallback = false;
      });
    }
  }

  void _startEmptyStateCountdown() {
    final startedAt = _scanStartedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(startedAt);
    final remaining =
        elapsed >= _emptyStateDelay
            ? Duration.zero
            : _emptyStateDelay - elapsed;

    _emptyStateTimer?.cancel();
    _emptyStateTimer = Timer(remaining, () {
      if (!mounted || nearbyRides.isNotEmpty || errorText.isNotEmpty) return;
      setState(() {
        searching = false;
        _showNoRidesFallback = true;
      });
    });
  }

  String _nearbyRidesFallbackMessage(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('pgrst204') ||
        lower.contains('42703') ||
        (lower.contains('column rides.') && lower.contains('does not exist'))) {
      return 'Nearby rides are not available right now. Please try again in a moment.';
    }
    if (lower.contains('timeout') || lower.contains('socket')) {
      return 'Network issue while loading nearby rides. Please try again.';
    }
    if (lower.contains('permission') || lower.contains('location')) {
      return 'Location is required to find nearby rides. Enable location and try again.';
    }
    return 'Could not search nearby rides right now. Please try again.';
  }

  Future<void> _joinRide(NearbyRide ride) async {
    if (joiningRideId.isNotEmpty) return;
    if (ride.joined) return;

    setState(() {
      joiningRideId = ride.ride.id;
    });

    try {
      final status = await _rideService.requestJoinRide(
        rideId: ride.ride.id,
        userId: currentUserId,
      );

      if (!mounted) return;

      final message = switch (status) {
        JoinByCodeStatus.requested => 'Join request sent.',
        JoinByCodeStatus.joinedDirectly => 'Joined successfully.',
        JoinByCodeStatus.alreadyRequested => 'You already requested to join.',
        JoinByCodeStatus.alreadyJoined => 'You are already part of this ride.',
      };

      if (status == JoinByCodeStatus.joinedDirectly) {
        setState(() {
          nearbyRides =
              nearbyRides.map((existing) {
                if (existing.ride.id != ride.ride.id) return existing;
                return existing.copyWith(
                  joined: true,
                  ride: RideRecord(
                    id: existing.ride.id,
                    creatorId: existing.ride.creatorId,
                    title: existing.ride.title,
                    startLocation: existing.ride.startLocation,
                    endLocation: existing.ride.endLocation,
                    createdAt: existing.ride.createdAt,
                    participantCount: existing.ride.participantCount + 1,
                  ),
                );
              }).toList();
        });
      }

      showAppToast(context, message, type: AppToastType.success);
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not join ride: $error',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          joiningRideId = '';
        });
      }
    }
  }

  Future<String> _resolveCurrentUserId() async {
    if (currentUserId.trim().isNotEmpty) {
      return currentUserId.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('userId') ?? '').trim();
  }

  Future<void> _showJoinByCodeDialog() async {
    final codeController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Join With Access Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the code shared by your ride host (example: JS-0370).',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'JS-0370',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final normalized = value.toUpperCase();
                  if (normalized != value) {
                    codeController.value = TextEditingValue(
                      text: normalized,
                      selection: TextSelection.collapsed(
                        offset: normalized.length,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  joiningByCode ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  joiningByCode
                      ? null
                      : () async {
                        await _joinRideByCode(codeController.text);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
              child:
                  joiningByCode
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Join'),
            ),
          ],
        );
      },
    );
    codeController.dispose();
  }

  Future<void> _joinRideByCode(String rawCode) async {
    if (joiningByCode) return;
    final userId = await _resolveCurrentUserId();
    if (userId.isEmpty) {
      if (!mounted) return;
      showAppToast(
        context,
        'Missing user session. Please login again.',
        type: AppToastType.error,
      );
      return;
    }

    setState(() {
      joiningByCode = true;
      currentUserId = userId;
    });

    try {
      final result = await _rideService.joinRideByAccessCode(
        accessCode: rawCode,
        userId: userId,
      );
      if (!mounted) return;
      final message = switch (result.status) {
        JoinByCodeStatus.requested =>
          'Join request sent for "${result.rideTitle}".',
        JoinByCodeStatus.joinedDirectly =>
          'Joined "${result.rideTitle}" successfully.',
        JoinByCodeStatus.alreadyRequested =>
          'You already requested to join "${result.rideTitle}".',
        JoinByCodeStatus.alreadyJoined =>
          'You are already part of "${result.rideTitle}".',
      };
      showAppToast(context, message, type: AppToastType.success);
      await _loadNearbyRides();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not join via code: $error',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          joiningByCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F7F6);
    const forest = Color(0xFF1E3A2F);
    const primary = Color(0xFFD46211);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Nearby Rides'),
        backgroundColor: background,
        foregroundColor: forest,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: joiningByCode ? null : _showJoinByCodeDialog,
            tooltip: 'Join with access code',
            icon: const Icon(Icons.key_rounded),
          ),
          IconButton(
            onPressed: searching ? null : _loadNearbyRides,
            tooltip: 'Refresh nearby rides',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _content(primary, forest),
    );
  }

  Widget _content(Color primary, Color forest) {
    if (errorText.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: primary, size: 32),
              const SizedBox(height: 8),
              Text(
                errorText,
                textAlign: TextAlign.center,
                style: TextStyle(color: forest, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _loadNearbyRides,
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (searching || nearbyRides.isEmpty) {
      return _radarExperience(
        primary,
        forest,
        showFallback: _showNoRidesFallback,
      );
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        _radarSurface(primary, forest, nearbyRides),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Text(
                '${nearbyRides.length} nearby ride${nearbyRides.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color: forest,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _rideList(primary, forest)),
      ],
    );
  }

  Widget _radarExperience(
    Color primary,
    Color forest, {
    required bool showFallback,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _radarSurface(primary, forest, nearbyRides),
            const SizedBox(height: 18),
            Text(
              showFallback
                  ? 'No nearby rides found'
                  : 'Scanning for nearby rides...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: forest,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showFallback
                  ? 'Ask a host to create a ride and keep it live, then refresh the radar.'
                  : 'Radar keeps scanning for around 10 to 15 seconds before showing an empty result.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: forest.withValues(alpha: 0.68),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showFallback) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNearbyRides,
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: const Text('Scan Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _radarSurface(Color primary, Color forest, List<NearbyRide> rides) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2BB3F3), Color(0xFF1684DE)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final nodes = _buildRadarNodes(rides);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _radarController,
                      builder: (context, _) {
                        final sweepAngle = _radarController.value * 2 * math.pi;
                        return CustomPaint(
                          size: Size.square(size),
                          painter: _RadarPainter(
                            sweepAngle: sweepAngle,
                            primary: Colors.white,
                          ),
                        );
                      },
                    ),
                    for (final node in nodes)
                      _RadarRideMarker(
                        ride: node.ride,
                        xFactor: node.xFactor,
                        yFactor: node.yFactor,
                        visible: rides.isNotEmpty,
                      ),
                    _RadarCenterMarker(
                      name: currentUserName,
                      avatarUrl: currentUserAvatarUrl,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rides.isNotEmpty
                ? 'Nearby riders detected on radar'
                : 'Radar is sweeping around you',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rides.isNotEmpty
                ? 'Tap Join Ride below to connect with one of them.'
                : 'Waiting for nearby rides to appear in range.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<_RadarNode> _buildRadarNodes(List<NearbyRide> rides) {
    if (rides.isEmpty) return const <_RadarNode>[];

    const ringFactors = <double>[0.28, 0.44, 0.6, 0.77];
    final nodes = <_RadarNode>[];
    for (int index = 0; index < rides.length; index++) {
      final ride = rides[index];
      final hash = ride.ride.id.hashCode.abs() + index * 53;
      final angle = ((hash % 360) / 180) * math.pi;
      final ring = ringFactors[hash % ringFactors.length];
      final x = 0.5 + math.cos(angle) * ring * 0.38;
      final y = 0.5 + math.sin(angle) * ring * 0.38;
      nodes.add(
        _RadarNode(
          ride: ride,
          xFactor: x.clamp(0.15, 0.85),
          yFactor: y.clamp(0.15, 0.85),
        ),
      );
    }
    return nodes;
  }

  Widget _rideList(Color primary, Color forest) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: nearbyRides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ride = nearbyRides[index];
        final joining = joiningRideId == ride.ride.id;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ride.ride.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: forest,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${ride.ride.participantCount} joined',
                      style: TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${ride.ride.startLocation} -> ${ride.ride.endLocation}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: forest.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RadarAvatar(
                    avatarUrl: ride.hostAvatarUrl,
                    label: ride.hostName,
                    radius: 16,
                    borderColor: primary.withValues(alpha: 0.22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Host: ${ride.hostName} | ${ride.hostBike}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: forest.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (ride.joined || joining) ? null : () => _joinRide(ride),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        ride.joined ? Colors.grey.shade300 : primary,
                    foregroundColor:
                        ride.joined ? Colors.black54 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      joining
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(
                            ride.joined ? 'Joined Ride' : 'Join Ride',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.sweepAngle, required this.primary});

  final double sweepAngle;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint =
        Paint()
          ..color = primary.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint =
        Paint()
          ..color = primary.withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), ringPaint);
    }

    final sweepRect = Rect.fromCircle(center: center, radius: radius);
    final sweepPaint =
        Paint()
          ..shader = SweepGradient(
            startAngle: sweepAngle - 0.45,
            endAngle: sweepAngle,
            colors: [Colors.transparent, primary.withValues(alpha: 0.42)],
          ).createShader(sweepRect);
    canvas.drawArc(sweepRect, sweepAngle - 0.45, 0.45, true, sweepPaint);

    final pulsePaint =
        Paint()
          ..color = primary.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.16, pulsePaint);

    final dotPaint =
        Paint()
          ..color = primary
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.primary != primary;
  }
}

class _RadarNode {
  const _RadarNode({
    required this.ride,
    required this.xFactor,
    required this.yFactor,
  });

  final NearbyRide ride;
  final double xFactor;
  final double yFactor;
}

class _RadarRideMarker extends StatelessWidget {
  const _RadarRideMarker({
    required this.ride,
    required this.xFactor,
    required this.yFactor,
    required this.visible,
  });

  final NearbyRide ride;
  final double xFactor;
  final double yFactor;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: Align(
        alignment: Alignment(xFactor * 2 - 1, yFactor * 2 - 1),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 320),
          scale: visible ? 1 : 0.7,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 320),
            opacity: visible ? 1 : 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RadarAvatar(
                  avatarUrl: ride.hostAvatarUrl,
                  label: ride.hostName,
                  radius: 23,
                  borderColor: Colors.white,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 88),
                  child: Text(
                    ride.hostName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarCenterMarker extends StatelessWidget {
  const _RadarCenterMarker({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 74,
          height: 74,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
              ),
            ],
          ),
          child: _RadarAvatar(
            avatarUrl: avatarUrl,
            label: name,
            radius: 31,
            borderColor: const Color(0xFF1BA2F4),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            name.trim().isEmpty ? 'You' : name.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarAvatar extends StatelessWidget {
  const _RadarAvatar({
    required this.avatarUrl,
    required this.label,
    required this.radius,
    required this.borderColor,
  });

  final String avatarUrl;
  final String label;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final clean = avatarUrl.trim();
    final initial =
        label.trim().isEmpty ? 'R' : label.trim().substring(0, 1).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: clean.isNotEmpty ? NetworkImage(clean) : null,
        onBackgroundImageError: (_, __) {},
        child:
            clean.isEmpty
                ? Text(
                  initial,
                  style: TextStyle(
                    color: const Color(0xFF0C4A6E),
                    fontSize: radius * 0.75,
                    fontWeight: FontWeight.w800,
                  ),
                )
                : null,
      ),
    );
  }
}
