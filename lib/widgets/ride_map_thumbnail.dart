import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/ride_record.dart';
import '../services/ride_geometry_service.dart';
import '../theme/app_theme.dart';

/// A small real map of a ride: OpenStreetMap tiles, the road route, and pins on
/// the start and the destination.
///
/// Replaces the hand-painted fake map that used to sit on ride cards. That
/// drawing took no ride data at all, so every card looked identical; this shows
/// where the ride actually goes.
///
/// The geometry is resolved asynchronously through [RideGeometryService], which
/// caches per ride, so a card that has been shown once renders its map
/// immediately. Until the coordinates are known - and on a ride whose locations
/// cannot be resolved at all - a neutral placeholder is shown rather than a
/// map of the wrong place.
class RideMapThumbnail extends StatefulWidget {
  const RideMapThumbnail({
    super.key,
    required this.ride,
    this.size = 68,
    this.radius = AppRadius.lg,
  });

  final RideRecord ride;

  /// Side length of the square tile.
  final double size;

  /// Corner rounding, matched to the card it sits on.
  final double radius;

  @override
  State<RideMapThumbnail> createState() => _RideMapThumbnailState();
}

class _RideMapThumbnailState extends State<RideMapThumbnail> {
  final RideGeometryService _geometryService = RideGeometryService();

  RideGeometry? _geometry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RideMapThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.id != widget.ride.id) {
      _geometry = null;
      _load();
    }
  }

  void _load() {
    // A ride resolved earlier this session renders on the first frame, with no
    // placeholder flash and no network work.
    final cached = _geometryService.cached(widget.ride.id);
    if (cached != null) {
      _geometry = cached;
      return;
    }
    _geometryService.resolve(widget.ride).then((geometry) {
      if (!mounted) return;
      setState(() => _geometry = geometry);
    });
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _geometry;
    final hasMap = geometry != null && geometry.hasAnyPoint;

    return RepaintBoundary(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: hasMap ? _buildMap(geometry) : const _ThumbnailPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildMap(RideGeometry geometry) {
    final start = geometry.start;
    final destination = geometry.destination;
    final framing = geometry.framingPoints;

    // Fitting needs two points that are actually apart - a round trip whose
    // start and destination coincide has nothing to frame.
    final canFit =
        framing.length >= 2 && framing.any((point) => point != framing.first);

    // The map is built only once the geometry is known, so the camera is right
    // on the first layout and no tiles are fetched for the wrong place.
    // initialCenter/initialZoom cover the single-point case and stand in if the
    // fit cannot be satisfied, so the map never opens on the null island.
    final camera = _fallbackCamera(framing);

    return IgnorePointer(
      // The tile sits inside a tappable card, so every touch must reach the card
      // rather than being swallowed by the map's own gesture handling.
      child: FlutterMap(
        options: MapOptions(
          initialCenter: camera.center,
          initialZoom: camera.zoom,
          initialCameraFit:
              canFit
                  ? CameraFit.coordinates(
                    coordinates: framing,
                    padding: const EdgeInsets.all(6),
                    maxZoom: 15,
                  )
                  : null,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.journeysync.app',
          ),
          if (geometry.hasRoute)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: geometry.points,
                  strokeWidth: 3.5,
                  color: AppColors.routeBlue,
                  borderColor: Colors.white.withValues(alpha: 0.8),
                  borderStrokeWidth: 1,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (start != null) _endpointMarker(start, AppColors.forest),
              if (destination != null)
                _endpointMarker(destination, AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  /// Centre and zoom that show all of [points] in a tile [widget.size] wide.
  ///
  /// A whole world spans 360 degrees across one 256 px tile at zoom 0, and each
  /// level halves that, so this inverts the relation for the span in hand. The
  /// 1.15 factor keeps the route clear of the edges.
  ({LatLng center, double zoom}) _fallbackCamera(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final span = math.max(maxLat - minLat, maxLng - minLng) * 1.15;
    if (span <= 0) return (center: center, zoom: 12.5);

    final degreesAcrossTile = 360 * widget.size / 256;
    final zoom = math.log(degreesAcrossTile / span) / math.ln2;
    return (center: center, zoom: zoom.clamp(2.0, 15.0));
  }

  Marker _endpointMarker(LatLng point, Color color) {
    return Marker(
      point: point,
      width: 12,
      height: 12,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

/// Shown while a ride's coordinates are being resolved, and for rides whose
/// locations cannot be resolved. Deliberately reads as "no map yet" instead of
/// imitating one.
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9F1EA), Color(0xFFFFF1E4)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.route_rounded,
          size: 22,
          color: AppColors.forest.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
