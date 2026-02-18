import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String errorText = "";
  List<_RidePin> ridePins = [];
  _RidePin? selectedPin;
  StreamSubscription<List<Map<String, dynamic>>>? _ridesSubscription;

  static const LatLng fallbackCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _startRideStream();
  }

  @override
  void dispose() {
    _ridesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRideStream() async {
    await _ridesSubscription?.cancel();
    setState(() {
      loading = true;
      errorText = "";
    });

    _ridesSubscription = supabase
        .from('rides')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            final pins = _buildRidePinsFromRows(rows);
            if (!mounted) return;
            setState(() {
              ridePins = pins;
              selectedPin = _resolveSelectedPin(pins);
              errorText = "";
              loading = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              errorText = "Could not load rides for map.";
              loading = false;
            });
          },
        );
  }

  List<_RidePin> _buildRidePinsFromRows(List<Map<String, dynamic>> rows) {
    final pins = <_RidePin>[];
    for (final row in rows) {
      final status = (row['status'] ?? '').toString();
      if (status != 'waiting' && status != 'active') continue;

      final lat = _pickCoordinate(row, const [
        'alert_lat',
        'destination_lat',
        'current_lat',
        'start_lat',
        'lat',
      ]);
      final lng = _pickCoordinate(row, const [
        'alert_lng',
        'destination_lng',
        'current_lng',
        'start_lng',
        'lng',
      ]);
      if (lat == null || lng == null) continue;
      pins.add(
        _RidePin(
          id: (row['id'] ?? '').toString(),
          name: (row['name'] ?? 'Ride').toString(),
          destination: (row['destination'] ?? 'Destination').toString(),
          status: status,
          point: LatLng(lat, lng),
        ),
      );
    }
    return pins;
  }

  _RidePin? _resolveSelectedPin(List<_RidePin> pins) {
    if (selectedPin == null) return null;
    for (final pin in pins) {
      if (pin.id == selectedPin!.id) return pin;
    }
    return null;
  }

  double? _pickCoordinate(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  LatLng get _initialCenter {
    if (ridePins.isNotEmpty) return ridePins.first.point;
    return fallbackCenter;
  }

  double get _initialZoom {
    if (ridePins.isNotEmpty) return 12;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F7F6);
    const forest = Color(0xFF1E3A2F);
    const primary = Color(0xFFD46211);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text("Ride Map"),
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: forest,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loading ? null : _startRideStream,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _initialZoom,
                minZoom: 3,
                maxZoom: 18,
                onTap: (_, __) {
                  if (selectedPin == null) return;
                  setState(() {
                    selectedPin = null;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.journeysync',
                ),
                MarkerLayer(markers: _buildRideMarkers(primary, forest)),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _statusBanner(primary, forest),
          ),
          if (selectedPin != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _rideInfoCard(selectedPin!, forest, primary),
            ),
          if (loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  List<Marker> _buildRideMarkers(Color primary, Color forest) {
    return ridePins.map((pin) {
      final waiting = pin.status == 'waiting';
      final markerColor = waiting ? const Color(0xFFAA8A66) : primary;
      return Marker(
        point: pin.point,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () {
            setState(() {
              selectedPin = pin;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              waiting ? Icons.schedule : Icons.directions_bike,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _statusBanner(Color primary, Color forest) {
    final message =
        errorText.isNotEmpty
            ? errorText
            : ridePins.isEmpty
            ? "No ride coordinates available yet."
            : "${ridePins.length} ride(s) on map";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: forest.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(
            errorText.isNotEmpty ? Icons.error_outline : Icons.map_outlined,
            color: errorText.isNotEmpty ? Colors.red : primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: forest.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideInfoCard(_RidePin pin, Color forest, Color primary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: forest.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pin.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: forest,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pin.destination,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: forest.withValues(alpha: 0.68),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pin.status.toUpperCase(),
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${pin.point.latitude.toStringAsFixed(5)}, ${pin.point.longitude.toStringAsFixed(5)}",
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: forest.withValues(alpha: 0.66),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RidePin {
  const _RidePin({
    required this.id,
    required this.name,
    required this.destination,
    required this.status,
    required this.point,
  });

  final String id;
  final String name;
  final String destination;
  final String status;
  final LatLng point;
}
