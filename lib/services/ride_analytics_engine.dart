import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_route.dart';
import 'group_ride_intelligence.dart';
import 'weather_service.dart';

enum RideScoreLabel { excellent, great, good, needsImprovement }

enum RideHealthState { excellent, stable, warning, needsAttention }

class RideAnalyticsSnapshot {
  const RideAnalyticsSnapshot({
    required this.rideId,
    required this.startedAt,
    required this.updatedAt,
    required this.durationSeconds,
    required this.movingSeconds,
    required this.stoppedSeconds,
    required this.distanceKm,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
    required this.averagePaceMinPerKm,
    required this.elevationGainM,
    required this.elevationLossM,
    required this.numberOfStops,
    required this.fuelStops,
    required this.sosEvents,
    required this.membersJoined,
    required this.membersLeft,
    required this.connectionQualityScore,
    required this.trackingQualityScore,
    required this.groupCohesionScore,
    required this.rideScore,
    required this.scoreLabel,
    required this.healthState,
    required this.insights,
    required this.achievements,
    this.weatherSummary,
    this.completedAt,
    this.leaderName,
    this.memberCount = 1,
  });

  final String rideId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final int movingSeconds;
  final int stoppedSeconds;
  final double distanceKm;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final double averagePaceMinPerKm;
  final double elevationGainM;
  final double elevationLossM;
  final int numberOfStops;
  final int fuelStops;
  final int sosEvents;
  final int membersJoined;
  final int membersLeft;
  final int connectionQualityScore;
  final int trackingQualityScore;
  final int groupCohesionScore;
  final int rideScore;
  final RideScoreLabel scoreLabel;
  final RideHealthState healthState;
  final List<String> insights;
  final List<String> achievements;
  final String? weatherSummary;
  final String? leaderName;
  final int memberCount;

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'startedAt': startedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'movingSeconds': movingSeconds,
      'stoppedSeconds': stoppedSeconds,
      'distanceKm': distanceKm,
      'averageSpeedKmh': averageSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'averagePaceMinPerKm': averagePaceMinPerKm,
      'elevationGainM': elevationGainM,
      'elevationLossM': elevationLossM,
      'numberOfStops': numberOfStops,
      'fuelStops': fuelStops,
      'sosEvents': sosEvents,
      'membersJoined': membersJoined,
      'membersLeft': membersLeft,
      'connectionQualityScore': connectionQualityScore,
      'trackingQualityScore': trackingQualityScore,
      'groupCohesionScore': groupCohesionScore,
      'rideScore': rideScore,
      'scoreLabel': scoreLabel.name,
      'healthState': healthState.name,
      'insights': insights,
      'achievements': achievements,
      'weatherSummary': weatherSummary,
      'leaderName': leaderName,
      'memberCount': memberCount,
    };
  }

  factory RideAnalyticsSnapshot.fromMap(Map<String, dynamic> map) {
    final score = (map['rideScore'] as num?)?.toInt() ?? 0;
    return RideAnalyticsSnapshot(
      rideId: (map['rideId'] ?? '').toString(),
      startedAt:
          DateTime.tryParse((map['startedAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((map['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      completedAt: DateTime.tryParse((map['completedAt'] ?? '').toString()),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      movingSeconds: (map['movingSeconds'] as num?)?.toInt() ?? 0,
      stoppedSeconds: (map['stoppedSeconds'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      averageSpeedKmh: (map['averageSpeedKmh'] as num?)?.toDouble() ?? 0,
      maxSpeedKmh: (map['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
      averagePaceMinPerKm:
          (map['averagePaceMinPerKm'] as num?)?.toDouble() ?? 0,
      elevationGainM: (map['elevationGainM'] as num?)?.toDouble() ?? 0,
      elevationLossM: (map['elevationLossM'] as num?)?.toDouble() ?? 0,
      numberOfStops: (map['numberOfStops'] as num?)?.toInt() ?? 0,
      fuelStops: (map['fuelStops'] as num?)?.toInt() ?? 0,
      sosEvents: (map['sosEvents'] as num?)?.toInt() ?? 0,
      membersJoined: (map['membersJoined'] as num?)?.toInt() ?? 0,
      membersLeft: (map['membersLeft'] as num?)?.toInt() ?? 0,
      connectionQualityScore:
          (map['connectionQualityScore'] as num?)?.toInt() ?? score,
      trackingQualityScore:
          (map['trackingQualityScore'] as num?)?.toInt() ?? score,
      groupCohesionScore: (map['groupCohesionScore'] as num?)?.toInt() ?? score,
      rideScore: score,
      scoreLabel: _scoreLabelFromString((map['scoreLabel'] ?? '').toString()),
      healthState: _healthFromString((map['healthState'] ?? '').toString()),
      insights:
          (map['insights'] as List?)?.map((item) => item.toString()).toList() ??
          const <String>[],
      achievements:
          (map['achievements'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const <String>[],
      weatherSummary:
          (map['weatherSummary'] ?? '').toString().trim().isEmpty
              ? null
              : map['weatherSummary'].toString(),
      leaderName:
          (map['leaderName'] ?? '').toString().trim().isEmpty
              ? null
              : map['leaderName'].toString(),
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 1,
    );
  }
}

class RideProfileStats {
  const RideProfileStats({
    required this.totalRides,
    required this.totalDistanceKm,
    required this.totalRidingHours,
    required this.longestRideKm,
    required this.fastestRideKmh,
    required this.averageRideScore,
    required this.groupRidesCompleted,
    required this.favoriteDestination,
    required this.frequentDay,
  });

  final int totalRides;
  final double totalDistanceKm;
  final double totalRidingHours;
  final double longestRideKm;
  final double fastestRideKmh;
  final double averageRideScore;
  final int groupRidesCompleted;
  final String favoriteDestination;
  final String frequentDay;
}

class RideAnalyticsEngine {
  RideAnalyticsEngine({required this.rideId});

  static const String _indexKey = 'rideAnalyticsIndex';
  static const String _achievementKey = 'unlockedRideAchievements';
  static const String _destinationPrefix = 'rideDestination:';

  final String rideId;
  DateTime _startedAt = DateTime.now();
  Position? _lastPosition;
  double _distanceKm = 0;
  double _maxSpeedKmh = 0;
  double _elevationGainM = 0;
  double _elevationLossM = 0;
  int _movingSeconds = 0;
  int _stoppedSeconds = 0;
  int _numberOfStops = 0;
  int _fuelStops = 0;
  int _sosEvents = 0;
  int _membersJoined = 0;
  int _membersLeft = 0;
  int _lastMemberCount = 0;
  int _badConnectionSamples = 0;
  int _totalSamples = 0;
  int _spreadSamples = 0;
  int _wideSpreadSamples = 0;
  WeatherSnapshot? _weather;
  String? _leaderName;
  int _memberCount = 1;
  final Set<String> _seenStopKeys = <String>{};

  Future<void> start({WeatherSnapshot? weather}) async {
    _weather = weather;
    _startedAt = DateTime.now();
    await _persist(live: true);
  }

  void recordPosition(Position position) {
    _totalSamples++;
    final speedKmh = position.speed >= 0 ? position.speed * 3.6 : 0.0;
    _maxSpeedKmh = math.max(_maxSpeedKmh, speedKmh);
    if (speedKmh >= 3) {
      _movingSeconds++;
    } else {
      _stoppedSeconds++;
    }

    final previous = _lastPosition;
    if (previous != null) {
      final meters = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      if (meters > 1 && meters < 250) {
        _distanceKm += meters / 1000.0;
      }
      final altitudeDelta = position.altitude - previous.altitude;
      if (altitudeDelta > 1) {
        _elevationGainM += altitudeDelta;
      } else if (altitudeDelta < -1) {
        _elevationLossM += altitudeDelta.abs();
      }
    }
    _lastPosition = position;
  }

  void recordGroupSnapshot(GroupRideSnapshot snapshot) {
    _memberCount = math.max(1, snapshot.totalRiders);
    _leaderName = snapshot.leader?.location.userName ?? _leaderName;
    _totalSamples++;
    if (snapshot.healthRating == GroupHealthRating.poor ||
        snapshot.healthRating == GroupHealthRating.needsAttention) {
      _badConnectionSamples++;
    }
    if (snapshot.groupSpreadMeters > 0) {
      _spreadSamples++;
      if (snapshot.groupSpreadMeters > 1500) {
        _wideSpreadSamples++;
      }
    }
    if (_lastMemberCount > 0) {
      if (snapshot.totalRiders > _lastMemberCount) {
        _membersJoined += snapshot.totalRiders - _lastMemberCount;
      } else if (snapshot.totalRiders < _lastMemberCount) {
        _membersLeft += _lastMemberCount - snapshot.totalRiders;
      }
    }
    _lastMemberCount = snapshot.totalRiders;
  }

  void recordRouteStops(List<RouteStop> stops) {
    for (final stop in stops) {
      final key =
          '${stop.order}:${stop.label}:${stop.latitude}:${stop.longitude}';
      if (!_seenStopKeys.add(key)) continue;
      _numberOfStops++;
      if (stop.label.toLowerCase().contains('fuel')) {
        _fuelStops++;
      }
    }
  }

  void recordSos() {
    _sosEvents++;
  }

  Future<RideAnalyticsSnapshot> complete({
    required String destination,
    bool completed = true,
  }) async {
    final snapshot = _buildSnapshot(completed: completed);
    await saveSnapshot(snapshot);
    await _updateDestination(destination);
    await _updateProfileStats();
    return snapshot;
  }

  RideAnalyticsSnapshot currentSnapshot() => _buildSnapshot(completed: false);

  RideAnalyticsSnapshot _buildSnapshot({required bool completed}) {
    final now = DateTime.now();
    final duration = now.difference(_startedAt).inSeconds;
    final movingHours = math.max(_movingSeconds / 3600.0, 0.001);
    final avgSpeed = _distanceKm <= 0 ? 0.0 : _distanceKm / movingHours;
    final pace = _distanceKm <= 0 ? 0.0 : (_movingSeconds / 60.0) / _distanceKm;
    final trackingQuality = _trackingQualityScore();
    final connectionQuality = _connectionQualityScore();
    final cohesion = _cohesionScore();
    final weatherScore = _weatherScore();
    final safetyScore = _sosEvents == 0 ? 100 : 70;
    final completionScore = completed ? 100 : 75;
    final score = (trackingQuality * 0.22 +
            connectionQuality * 0.18 +
            cohesion * 0.18 +
            weatherScore * 0.12 +
            safetyScore * 0.15 +
            completionScore * 0.15)
        .round()
        .clamp(0, 100);
    final health = _healthState(score, connectionQuality, cohesion);
    final achievements = _achievementCandidates(score, completed);
    return RideAnalyticsSnapshot(
      rideId: rideId,
      startedAt: _startedAt,
      updatedAt: now,
      completedAt: completed ? now : null,
      durationSeconds: duration,
      movingSeconds: _movingSeconds,
      stoppedSeconds: math.max(_stoppedSeconds, duration - _movingSeconds),
      distanceKm: _distanceKm,
      averageSpeedKmh: avgSpeed,
      maxSpeedKmh: _maxSpeedKmh,
      averagePaceMinPerKm: pace,
      elevationGainM: _elevationGainM,
      elevationLossM: _elevationLossM,
      numberOfStops: _numberOfStops,
      fuelStops: _fuelStops,
      sosEvents: _sosEvents,
      membersJoined: _membersJoined,
      membersLeft: _membersLeft,
      connectionQualityScore: connectionQuality,
      trackingQualityScore: trackingQuality,
      groupCohesionScore: cohesion,
      rideScore: score,
      scoreLabel: _scoreLabel(score),
      healthState: health,
      insights: _insights(score, cohesion, connectionQuality, completed),
      achievements: achievements,
      weatherSummary: _weather?.displayText,
      leaderName: _leaderName,
      memberCount: _memberCount,
    );
  }

  int _trackingQualityScore() {
    if (_totalSamples == 0) return 80;
    final movingRatio =
        _movingSeconds / math.max(_movingSeconds + _stoppedSeconds, 1);
    return (70 + movingRatio * 30).round().clamp(0, 100);
  }

  int _connectionQualityScore() {
    if (_totalSamples == 0) return 85;
    final badRatio = _badConnectionSamples / _totalSamples;
    return (100 - badRatio * 55).round().clamp(0, 100);
  }

  int _cohesionScore() {
    if (_spreadSamples == 0) return 90;
    final wideRatio = _wideSpreadSamples / _spreadSamples;
    return (100 - wideRatio * 45).round().clamp(0, 100);
  }

  int _weatherScore() {
    final weather = _weather;
    if (weather == null) return 85;
    var score = 100;
    if (weather.rainChance > 50) score -= 16;
    if (weather.windSpeed > 20) score -= 14;
    if (weather.visibility < 5) score -= 12;
    if (weather.temperature > 35 || weather.temperature < 5) score -= 10;
    return score.clamp(40, 100);
  }

  RideHealthState _healthState(int score, int connection, int cohesion) {
    if (score >= 86 && connection >= 80 && cohesion >= 80) {
      return RideHealthState.excellent;
    }
    if (score >= 70) return RideHealthState.stable;
    if (score >= 50) return RideHealthState.warning;
    return RideHealthState.needsAttention;
  }

  RideScoreLabel _scoreLabel(int score) {
    if (score >= 90) return RideScoreLabel.excellent;
    if (score >= 80) return RideScoreLabel.great;
    if (score >= 65) return RideScoreLabel.good;
    return RideScoreLabel.needsImprovement;
  }

  List<String> _insights(
    int score,
    int cohesion,
    int connection,
    bool completed,
  ) {
    final insights = <String>[];
    if (cohesion >= 88 && _memberCount > 1) {
      insights.add('Excellent group coordination.');
    } else if (_wideSpreadSamples > 0) {
      insights.add('The group spread exceeded 1.5 km.');
    }
    if (_distanceKm > 0 &&
        _maxSpeedKmh > 0 &&
        _maxSpeedKmh - (_distanceKm / math.max(_movingSeconds / 3600, 0.001)) <
            18) {
      insights.add('You maintained a consistent pace.');
    }
    if (connection >= 88) {
      insights.add('Connection remained excellent.');
    }
    if (_sosEvents == 0) {
      insights.add('No emergency events occurred.');
    }
    if (_numberOfStops >= 3) {
      insights.add('Multiple stops shaped this ride.');
    }
    if (_weather != null && _weather!.alerts.isNotEmpty) {
      insights.add('Weather required extra attention during the ride.');
    }
    if (completed) {
      insights.add('Ride completed without tracking interruption.');
    }
    if (insights.isEmpty) {
      insights.add(
        score >= 75 ? 'Ride quality stayed stable.' : 'Ride needs review.',
      );
    }
    return insights.take(5).toList();
  }

  List<String> _achievementCandidates(int score, bool completed) {
    if (!completed) return const <String>[];
    final achievements = <String>['First Ride'];
    if (_distanceKm >= 100) achievements.add('100 km Ride');
    if (_distanceKm >= 150) achievements.add('Long Distance Rider');
    if (_elevationGainM >= 1000) achievements.add('Mountain Rider');
    final hour = _startedAt.hour;
    if (hour >= 20 || hour <= 5) achievements.add('Night Rider');
    if (_startedAt.weekday == DateTime.saturday ||
        _startedAt.weekday == DateTime.sunday) {
      achievements.add('Weekend Explorer');
    }
    if ((_weather?.rainChance ?? 0) > 50) achievements.add('Rain Rider');
    if (_memberCount > 1 && _leaderName != null) {
      achievements.add('Group Leader');
    }
    if (_sosEvents == 0 && score >= 80) achievements.add('Safe Rider');
    return achievements;
  }

  Future<void> _persist({required bool live}) async {
    await saveSnapshot(_buildSnapshot(completed: !live));
  }

  static Future<void> saveSnapshot(RideAnalyticsSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(snapshot.rideId), jsonEncode(snapshot.toMap()));
    final index = prefs.getStringList(_indexKey) ?? <String>[];
    if (!index.contains(snapshot.rideId)) {
      index.add(snapshot.rideId);
      await prefs.setStringList(_indexKey, index);
    }
    await _persistAchievements(snapshot.achievements);
  }

  static Future<RideAnalyticsSnapshot?> load(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(rideId));
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return RideAnalyticsSnapshot.fromMap(decoded);
  }

  static Future<List<RideAnalyticsSnapshot>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_indexKey) ?? <String>[];
    final snapshots = <RideAnalyticsSnapshot>[];
    for (final id in ids) {
      final snapshot = await load(id);
      if (snapshot != null) snapshots.add(snapshot);
    }
    snapshots.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return snapshots;
  }

  Future<void> _updateProfileStats() async {
    final stats = await aggregateProfileStats();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('statTotalRides', stats.totalRides);
    await prefs.setDouble('statTotalDistance', stats.totalDistanceKm);
    await prefs.setDouble('statLongestRide', stats.longestRideKm);
    await prefs.setDouble('statHoursRidden', stats.totalRidingHours);
    await prefs.setDouble('statFastestRide', stats.fastestRideKmh);
    await prefs.setDouble('statAverageRideScore', stats.averageRideScore);
    await prefs.setInt('statGroupRidesCompleted', stats.groupRidesCompleted);
    await prefs.setString('statFavoriteRoute', stats.favoriteDestination);
    await prefs.setString('statFrequentDay', stats.frequentDay);
  }

  Future<void> _updateDestination(String destination) async {
    if (destination.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_destinationPrefix$rideId', destination.trim());
  }

  static Future<RideProfileStats> aggregateProfileStats() async {
    final snapshots = await loadAll();
    if (snapshots.isEmpty) {
      return const RideProfileStats(
        totalRides: 0,
        totalDistanceKm: 0,
        totalRidingHours: 0,
        longestRideKm: 0,
        fastestRideKmh: 0,
        averageRideScore: 0,
        groupRidesCompleted: 0,
        favoriteDestination: 'No favorite route yet',
        frequentDay: '--',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final destinationCounts = <String, int>{};
    final dayCounts = <String, int>{};
    var totalDistance = 0.0;
    var totalSeconds = 0;
    var longest = 0.0;
    var fastest = 0.0;
    var scoreTotal = 0;
    var groupRides = 0;
    for (final snapshot in snapshots) {
      totalDistance += snapshot.distanceKm;
      totalSeconds += snapshot.durationSeconds;
      longest = math.max(longest, snapshot.distanceKm);
      fastest = math.max(fastest, snapshot.maxSpeedKmh);
      scoreTotal += snapshot.rideScore;
      if (snapshot.memberCount > 1) groupRides++;
      final day = _weekday(snapshot.startedAt.weekday);
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      final destination = prefs.getString(
        '$_destinationPrefix${snapshot.rideId}',
      );
      if (destination != null && destination.trim().isNotEmpty) {
        destinationCounts[destination] =
            (destinationCounts[destination] ?? 0) + 1;
      }
    }
    return RideProfileStats(
      totalRides: snapshots.length,
      totalDistanceKm: totalDistance,
      totalRidingHours: totalSeconds / 3600.0,
      longestRideKm: longest,
      fastestRideKmh: fastest,
      averageRideScore: scoreTotal / snapshots.length,
      groupRidesCompleted: groupRides,
      favoriteDestination:
          _topKey(destinationCounts) ?? 'No favorite route yet',
      frequentDay: _topKey(dayCounts) ?? '--',
    );
  }

  static Future<void> _persistAchievements(List<String> achievements) async {
    if (achievements.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_achievementKey) ?? <String>[];
    final merged = <String>{...current, ...achievements}.toList()..sort();
    await prefs.setStringList(_achievementKey, merged);
  }

  static Future<List<String>> unlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_achievementKey) ?? <String>[];
  }

  static String scoreLabelText(RideScoreLabel label) {
    return switch (label) {
      RideScoreLabel.excellent => 'Excellent',
      RideScoreLabel.great => 'Great',
      RideScoreLabel.good => 'Good',
      RideScoreLabel.needsImprovement => 'Needs Improvement',
    };
  }

  static String healthLabelText(RideHealthState state) {
    return switch (state) {
      RideHealthState.excellent => 'Excellent',
      RideHealthState.stable => 'Stable',
      RideHealthState.warning => 'Warning',
      RideHealthState.needsAttention => 'Needs Attention',
    };
  }

  static String durationText(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  static String _key(String rideId) => 'rideAnalytics:$rideId';

  static String? _topKey(Map<String, int> values) {
    if (values.isEmpty) return null;
    final entries =
        values.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  static String _weekday(int weekday) {
    const days = <int, String>{
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return days[weekday] ?? '--';
  }
}

RideScoreLabel _scoreLabelFromString(String value) {
  return RideScoreLabel.values.firstWhere(
    (label) => label.name == value,
    orElse: () => RideScoreLabel.good,
  );
}

RideHealthState _healthFromString(String value) {
  return RideHealthState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => RideHealthState.stable,
  );
}
