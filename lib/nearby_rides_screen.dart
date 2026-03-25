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
  final RideService _rideService = RideService();
  late final AnimationController _radarController;

  bool searching = true;
  bool joiningByCode = false;
  String errorText = '';
  String currentUserId = '';
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
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyRides() async {
    if (!mounted) return;
    setState(() {
      searching = true;
      errorText = '';
      joiningRideId = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = (prefs.getString('userId') ?? '').trim();
      if (userId.isEmpty) {
        throw Exception('Missing user session. Please login again.');
      }

      final rides = await _rideService.searchNearbyRides(
        userId,
        requestPermissionIfNeeded: true,
      );
      if (!mounted) return;
      setState(() {
        currentUserId = userId;
        nearbyRides = rides;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = _nearbyRidesFallbackMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          searching = false;
        });
      }
    }
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
          nearbyRides = nearbyRides.map((existing) {
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

      showAppToast(
        context,
        message,
        type: AppToastType.success,
      );
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
      if (!searching && errorText.isEmpty) {
        await _loadNearbyRides();
      }
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
        title: const Text('Nearby Active Rides'),
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
      body:
          searching
              ? _radarLoading(primary, forest)
              : _content(primary, forest),
    );
  }

  Widget _radarLoading(Color primary, Color forest) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, _) {
                final sweepAngle = _radarController.value * 2 * math.pi;
                return CustomPaint(
                  painter: _RadarPainter(
                    sweepAngle: sweepAngle,
                    primary: primary,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Scanning for nearby riders...',
            style: TextStyle(
              color: forest,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please wait',
            style: TextStyle(
              color: forest.withValues(alpha: 0.65),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

    if (nearbyRides.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radar, color: primary, size: 34),
              const SizedBox(height: 10),
              Text(
                'No nearby rides found',
                style: TextStyle(
                  color: forest,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ask a friend to create a ride and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: forest.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
              Text(
                'Host: ${ride.hostName} | ${ride.hostBike}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: forest.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
          ..color = primary.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), ringPaint);
    }

    final sweepRect = Rect.fromCircle(center: center, radius: radius);
    final sweepPaint =
        Paint()
          ..shader = SweepGradient(
            startAngle: sweepAngle - 0.35,
            endAngle: sweepAngle,
            colors: [Colors.transparent, primary.withValues(alpha: 0.45)],
          ).createShader(sweepRect);
    canvas.drawArc(sweepRect, sweepAngle - 0.35, 0.35, true, sweepPaint);

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
