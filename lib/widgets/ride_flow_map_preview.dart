import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/ride_flow_service.dart';
import '../theme/app_theme.dart';

class RideFlowMapPreview extends StatefulWidget {
  const RideFlowMapPreview({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  State<RideFlowMapPreview> createState() => _RideFlowMapPreviewState();
}

class _RideFlowMapPreviewState extends State<RideFlowMapPreview> {
  final RideFlowService _rideFlowService = RideFlowService();
  static const LatLng _fallbackCenter = LatLng(12.9716, 77.5946);

  RideFlowLocation? _location;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final location = await _rideFlowService.resolveCurrentLocation();
    if (!mounted) return;
    setState(() {
      _location = location;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final point =
        _location?.latitude != null && _location?.longitude != null
            ? LatLng(_location!.latitude!, _location!.longitude!)
            : _fallbackCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        height: widget.compact ? 156 : 188,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: _location == null ? 11 : 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.journeysync.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 54,
                        height: 54,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.primary,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: AppColors.textOnDark,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.54),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _loading ? 'Locating you...' : widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.84),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
