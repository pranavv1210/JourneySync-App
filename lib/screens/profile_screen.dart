import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/ride_analytics_engine.dart';
import '../services/supabase_service.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_toast.dart';
import '../widgets/app_dialog.dart';
import '../widgets/journey_screen.dart';
import '../widgets/ride_loading_indicator.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabaseService = SupabaseService();

  // Profile data
  String userName = 'Rider';
  String bio = 'Ready for the first synced ride.';
  String experienceLevel = 'New Rider';
  String avatarUrl = '';
  ImageProvider? profileHeroImage;

  // Stats
  int totalRides = 0;
  double totalDistance = 0; // in km
  double longestRide = 0; // in km
  double hoursRidden = 0;
  String favoriteRoute = 'No favorite route yet';
  double fastestRide = 0;
  double averageRideScore = 0;
  int groupRidesCompleted = 0;
  String frequentRidingDay = '--';
  List<String> unlockedAchievements = <String>[];

  // Garage
  List<Map<String, String>> bikes = [];
  String activeBikeId = '';
  final Map<String, ImageProvider> _bikeImageCache = {};

  // Loading state
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();

    var loadedBikes = _decodeGaragePrefs(
      prefs.getStringList('garageBikes') ?? const <String>[],
    );
    var activeBike = prefs.getString('userActiveBikeId') ?? '';
    final cachedAvatarPath = prefs.getString('localAvatarPath') ?? '';
    var resolvedAvatar = cachedAvatarPath;
    if (resolvedAvatar.isEmpty || !File(resolvedAvatar).existsSync()) {
      resolvedAvatar = prefs.getString('userAvatarUrl') ?? '';
    }

    if (mounted) {
      _refreshBikeImageCache(loadedBikes);
      setState(() {
        userName = prefs.getString('userName') ?? 'Rider';
        bio = prefs.getString('userBio') ?? 'Ready for the first synced ride.';
        experienceLevel = prefs.getString('userExperienceLevel') ?? 'New Rider';
        avatarUrl = resolvedAvatar;
        profileHeroImage = _imageProviderFor(resolvedAvatar);
        totalRides = prefs.getInt('statTotalRides') ?? 0;
        totalDistance = prefs.getDouble('statTotalDistance') ?? 0;
        longestRide = prefs.getDouble('statLongestRide') ?? 0;
        hoursRidden = prefs.getDouble('statHoursRidden') ?? 0;
        favoriteRoute =
            prefs.getString('statFavoriteRoute') ?? 'No favorite route yet';
        fastestRide = prefs.getDouble('statFastestRide') ?? 0;
        averageRideScore = prefs.getDouble('statAverageRideScore') ?? 0;
        groupRidesCompleted = prefs.getInt('statGroupRidesCompleted') ?? 0;
        frequentRidingDay = prefs.getString('statFrequentRidingDay') ?? '--';
        bikes = List<Map<String, String>>.from(loadedBikes);
        activeBikeId =
            loadedBikes.any((bike) => bike['id'] == activeBike)
                ? activeBike
                : loadedBikes.isNotEmpty
                ? loadedBikes.first['id']!
                : '';
        _loading = false;
      });
    }

    final userId = (prefs.getString('userId') ?? '').trim();
    if (userId.isNotEmpty) {
      try {
        final remoteGarage = await _supabaseService.fetchGarage(userId: userId);
        if (remoteGarage != null && remoteGarage.bikes.isNotEmpty) {
          loadedBikes = remoteGarage.bikes;
          activeBike = remoteGarage.activeBikeId;
          await _saveBikesToPrefs(loadedBikes);
          await prefs.setString('userActiveBikeId', activeBike);
        }
      } catch (_) {}
    }
    final analyticsStats = await RideAnalyticsEngine.aggregateProfileStats();
    final achievements = await RideAnalyticsEngine.unlockedAchievements();

    setState(() {
      _refreshBikeImageCache(loadedBikes);
      userName = prefs.getString('userName') ?? 'Rider';
      bio = prefs.getString('userBio') ?? 'Ready for the first synced ride.';
      experienceLevel = prefs.getString('userExperienceLevel') ?? 'New Rider';
      avatarUrl = resolvedAvatar;
      profileHeroImage = _imageProviderFor(resolvedAvatar);

      totalRides =
          analyticsStats.totalRides > 0
              ? analyticsStats.totalRides
              : prefs.getInt('statTotalRides') ?? 0;
      totalDistance =
          analyticsStats.totalDistanceKm > 0
              ? analyticsStats.totalDistanceKm
              : prefs.getDouble('statTotalDistance') ?? 0;
      longestRide =
          analyticsStats.longestRideKm > 0
              ? analyticsStats.longestRideKm
              : prefs.getDouble('statLongestRide') ?? 0;
      hoursRidden =
          analyticsStats.totalRidingHours > 0
              ? analyticsStats.totalRidingHours
              : prefs.getDouble('statHoursRidden') ?? 0;
      favoriteRoute =
          analyticsStats.favoriteDestination != 'No favorite route yet'
              ? analyticsStats.favoriteDestination
              : prefs.getString('statFavoriteRoute') ?? 'No favorite route yet';
      fastestRide =
          analyticsStats.fastestRideKmh > 0
              ? analyticsStats.fastestRideKmh
              : prefs.getDouble('statFastestRide') ?? 0;
      averageRideScore =
          analyticsStats.averageRideScore > 0
              ? analyticsStats.averageRideScore
              : prefs.getDouble('statAverageRideScore') ?? 0;
      groupRidesCompleted =
          analyticsStats.groupRidesCompleted > 0
              ? analyticsStats.groupRidesCompleted
              : prefs.getInt('statGroupRidesCompleted') ?? 0;
      frequentRidingDay = analyticsStats.frequentDay;
      unlockedAchievements = achievements;

      bikes = List<Map<String, String>>.from(loadedBikes);
      activeBikeId =
          loadedBikes.any((bike) => bike['id'] == activeBike)
              ? activeBike
              : loadedBikes.isNotEmpty
              ? loadedBikes.first['id']!
              : '';
      _loading = false;
    });
  }

  Future<void> _saveBikesToPrefs(List<Map<String, String>> list) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList =
        list.map((b) {
          String clean(String? value) => (value ?? '').replaceAll('|', ' ');
          return '${clean(b['id'])}|${clean(b['brand'])}|${clean(b['model'])}|${clean(b['cc'])}|${clean(b['nickname'])}|${clean(b['fuelType'])}|${clean(b['imagePath'])}';
        }).toList();
    await prefs.setStringList('garageBikes', stringList);
  }

  List<Map<String, String>> _decodeGaragePrefs(List<String> rows) {
    return rows.map((b) {
      final parts = b.split('|');
      return {
        'id': parts.isNotEmpty ? parts[0] : '',
        'brand': parts.length > 1 ? parts[1] : '',
        'model': parts.length > 2 ? parts[2] : '',
        'cc': parts.length > 3 ? parts[3] : '',
        'nickname': parts.length > 4 ? parts[4] : 'Motorcycle',
        'fuelType': parts.length > 5 ? parts[5] : 'Petrol',
        'imagePath': parts.length > 6 ? parts[6] : '',
      };
    }).toList();
  }

  Future<bool> _persistGarage() async {
    await _saveBikesToPrefs(bikes);
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString('userId') ?? '').trim();
    if (userId.isEmpty) return true;
    try {
      await _supabaseService.saveGarage(
        userId: userId,
        bikes: bikes,
        activeBikeId: activeBikeId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _addBike() async {
    final newBike = await _showVehicleForm();
    if (newBike == null) return;

    final shouldSetActive = bikes.isEmpty || activeBikeId.isEmpty;

    setState(() {
      bikes.add(newBike);
      if (shouldSetActive) activeBikeId = newBike['id']!;
    });
    final synced = await _persistGarage();
    if (shouldSetActive) {
      await _selectActiveBike(newBike['id']!, showToast: false);
    }

    if (mounted) {
      showPremiumToast(
        context,
        synced
            ? '${newBike['nickname']} added to your garage!'
            : '${newBike['nickname']} saved on this device. Cloud sync will retry later.',
        type: synced ? PremiumToastType.success : PremiumToastType.info,
      );
    }
  }

  Future<void> _editBike(Map<String, String> bike) async {
    final updatedBike = await _showVehicleForm(initialBike: bike);
    if (updatedBike == null) return;

    setState(() {
      final index = bikes.indexWhere((item) => item['id'] == bike['id']);
      if (index != -1) {
        bikes[index] = updatedBike;
      }
      _refreshBikeImageCache(bikes);
    });
    final synced = await _persistGarage();
    if (activeBikeId == updatedBike['id']) {
      await _selectActiveBike(updatedBike['id']!, showToast: false);
    }

    if (mounted) {
      showPremiumToast(
        context,
        synced
            ? '${updatedBike['nickname']} updated.'
            : '${updatedBike['nickname']} updated on this device. Cloud sync will retry later.',
        type: synced ? PremiumToastType.success : PremiumToastType.info,
      );
    }
  }

  Future<Map<String, String>?> _showVehicleForm({
    Map<String, String>? initialBike,
  }) async {
    final isEditing = initialBike != null;
    final brandController = TextEditingController(
      text: initialBike?['brand'] ?? '',
    );
    final modelController = TextEditingController(
      text: initialBike?['model'] ?? '',
    );
    final ccController = TextEditingController(text: initialBike?['cc'] ?? '');
    final nicknameController = TextEditingController(
      text: initialBike?['nickname'] ?? '',
    );
    var imagePath = initialBike?['imagePath'] ?? '';

    Future<String> saveBikeImage(XFile picked) async {
      final directory = await getApplicationDocumentsDirectory();
      final garageDir = Directory('${directory.path}/garage');
      if (!garageDir.existsSync()) {
        await garageDir.create(recursive: true);
      }
      final extension =
          picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final target =
          '${garageDir.path}/bike_${DateTime.now().millisecondsSinceEpoch}.$extension';
      return File(picked.path).copy(target).then((file) => file.path);
    }

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: FractionallySizedBox(
                heightFactor: 0.82,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl + keyboardInset,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit vehicle' : 'Add vehicle',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          isEditing
                              ? 'Update the motorcycle details used across rides.'
                              : 'Save the motorcycle you use for group rides.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 82,
                            );
                            if (picked == null) return;
                            final saved = await saveBikeImage(picked);
                            imagePath = saved;
                            setSheetState(() {});
                          },
                          child: Container(
                            height: 132,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.divider),
                              image:
                                  imagePath.isNotEmpty &&
                                          File(imagePath).existsSync()
                                      ? DecorationImage(
                                        image: FileImage(File(imagePath)),
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            child:
                                imagePath.isNotEmpty &&
                                        File(imagePath).existsSync()
                                    ? Align(
                                      alignment: Alignment.bottomRight,
                                      child: Container(
                                        margin: const EdgeInsets.all(10),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          'Change photo',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: AppColors.primary,
                                          size: 34,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add bike photo',
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _VehicleField(
                          controller: brandController,
                          label: 'Brand',
                          hint: 'Royal Enfield',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _VehicleField(
                          controller: modelController,
                          label: 'Model',
                          hint: 'Continental GT 650',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _VehicleField(
                          controller: ccController,
                          label: 'Engine CC',
                          hint: '650',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _VehicleField(
                          controller: nicknameController,
                          label: 'Nickname',
                          hint: 'Weekend machine',
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final brand = brandController.text.trim();
                                  final model = modelController.text.trim();
                                  final cc = ccController.text.trim();
                                  final nickname =
                                      nicknameController.text.trim().isEmpty
                                          ? model
                                          : nicknameController.text.trim();
                                  if (brand.isEmpty ||
                                      model.isEmpty ||
                                      cc.isEmpty) {
                                    showPremiumToast(
                                      context,
                                      'Add brand, model, and CC.',
                                      type: PremiumToastType.error,
                                    );
                                    return;
                                  }
                                  Navigator.pop(context, {
                                    'id':
                                        initialBike?['id'] ??
                                        'bike_${DateTime.now().millisecondsSinceEpoch}',
                                    'brand': brand,
                                    'model': model,
                                    'cc': cc,
                                    'nickname': nickname,
                                    'fuelType': 'Petrol',
                                    'imagePath': imagePath,
                                  });
                                },
                                child: Text(isEditing ? 'Update' : 'Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    brandController.dispose();
    modelController.dispose();
    ccController.dispose();
    nicknameController.dispose();
    return result;
  }

  Future<void> _selectActiveBike(String id, {bool showToast = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedBike = bikes.firstWhere((b) => b['id'] == id);
    final bikeNameString = '${selectedBike['brand']} ${selectedBike['model']}';

    await prefs.setString('userActiveBikeId', id);
    await prefs.setString('userBike', bikeNameString);

    final userId = prefs.getString('userId') ?? '';
    if (userId.isNotEmpty) {
      try {
        await _supabaseService.updateUserProfile(
          userId: userId,
          name: userName,
          bike: bikeNameString,
        );
        await _supabaseService.saveGarage(
          userId: userId,
          bikes: bikes,
          activeBikeId: id,
        );
      } catch (_) {}
    }

    setState(() {
      activeBikeId = id;
    });

    if (mounted && showToast) {
      showPremiumToast(
        context,
        'Active ride vehicle set to: $bikeNameString',
        type: PremiumToastType.success,
      );
    }
  }

  Future<void> _deleteBike(String id) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove Vehicle?',
      message:
          'Are you sure you want to remove this motorcycle from your garage?',
      confirmLabel: 'Remove',
      destructive: true,
    );

    if (confirmed != true) return;

    setState(() {
      bikes.removeWhere((b) => b['id'] == id);
      if (activeBikeId == id) {
        activeBikeId = bikes.isNotEmpty ? bikes.first['id']! : '';
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userActiveBikeId', activeBikeId);
    if (activeBikeId.isEmpty) {
      await prefs.setString('userBike', 'No bike added');
    } else {
      final selectedBike = bikes.firstWhere((b) => b['id'] == activeBikeId);
      final bikeNameString =
          '${selectedBike['brand']} ${selectedBike['model']}';
      await prefs.setString('userBike', bikeNameString);
    }
    await _persistGarage();
  }

  Widget _buildProfileHero(BuildContext context) {
    final image = profileHeroImage;
    final motorcycle = _activeMotorcycleLabel();
    final riderLocation = _riderLocationLabel();

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight =
            (constraints.maxWidth * 0.98).clamp(320.0, 410.0).toDouble();
        return Container(
          height: heroHeight,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  Image(
                    image: image,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.28),
                    filterQuality: FilterQuality.medium,
                  )
                else
                  _buildHeroFallback(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.forestDark.withValues(alpha: 0.18),
                        AppColors.forestDark.withValues(alpha: 0.72),
                        AppColors.background.withValues(alpha: 0.98),
                      ],
                      stops: const [0.22, 0.52, 0.82, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.background.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  bottom: AppSpacing.huge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildHeroChip(
                            experienceLevel.toUpperCase(),
                            AppColors.primary,
                          ),
                          _buildHeroChip(
                            riderLocation,
                            AppColors.forest,
                            icon: Icons.location_on_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        userName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.displayMedium.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w700,
                          height: 1.02,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.34),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        bio.trim().isEmpty
                            ? 'Ready for the first synced ride.'
                            : bio.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.9),
                          height: 1.38,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.two_wheeler_rounded,
                            color: AppColors.primaryLight,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              motorcycle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.textOnDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroFallback() {
    final initial = userName.trim().isNotEmpty ? userName.trim()[0] : 'R';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6EFE7), Color(0xFFEAF0E9), Color(0xFF211C17)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 56,
            right: -48,
            child: Icon(
              Icons.route_rounded,
              size: 220,
              color: AppColors.forest.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            left: -32,
            bottom: 72,
            child: Icon(
              Icons.two_wheeler_rounded,
              size: 180,
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
          ),
          Center(
            child: Text(
              initial.toUpperCase(),
              style: AppTypography.displayLarge.copyWith(
                color: AppColors.primary.withValues(alpha: 0.62),
                fontSize: 96,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label, Color color, {IconData? icon}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 14),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: RideLoadingIndicator(label: 'Loading profile')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: JourneyHeader(
                surface: true,
                leading: JourneyBackButton(
                  onPressed: () => Navigator.pop(context, true),
                ),
                eyebrow: 'RIDER IDENTITY',
                title: 'Profile',
                subtitle: 'Garage, stats, badges, and rider details.',
                trailing: IconButton(
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                    if (updated == true) {
                      _loadProfileData();
                    }
                  },
                  icon: const Icon(Icons.edit_rounded),
                  color: AppColors.primary,
                ),
              ),
            ),

            _buildProfileHero(context),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              labelStyle: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'BIO & STATS'),
                Tab(text: 'GARAGE'),
                Tab(text: 'BADGES'),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBioStatsTab(),
                  _buildGarageTab(),
                  _buildAchievementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          'GARMIN RIDE TELEMETRY',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard(
              'Total Rides',
              '$totalRides',
              Icons.directions_bike_rounded,
              const Color(0xFF2563EB),
            ),
            _buildStatCard(
              'Total Distance',
              '${totalDistance.toStringAsFixed(0)} km',
              Icons.route_outlined,
              const Color(0xFF10B981),
            ),
            _buildStatCard(
              'Longest Ride',
              '${longestRide.toStringAsFixed(0)} km',
              Icons.landscape_rounded,
              const Color(0xFFD97706),
            ),
            _buildStatCard(
              'Hours Ridden',
              '${hoursRidden.toStringAsFixed(1)} h',
              Icons.timer_outlined,
              const Color(0xFF8B5CF6),
            ),
            _buildStatCard(
              'Fastest Ride',
              '${fastestRide.toStringAsFixed(0)} km/h',
              Icons.bolt_rounded,
              const Color(0xFFEF4444),
            ),
            _buildStatCard(
              'Avg Score',
              averageRideScore > 0 ? averageRideScore.toStringAsFixed(0) : '--',
              Icons.auto_graph_rounded,
              const Color(0xFF00A8B0),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'PREFERENCES',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildPreferenceRow(
                'Favorite Route',
                favoriteRoute,
                Icons.star_rounded,
              ),
              const Divider(height: 20),
              _buildPreferenceRow(
                'Frequent Day',
                frequentRidingDay,
                Icons.calendar_month_rounded,
              ),
              const Divider(height: 20),
              _buildPreferenceRow(
                'Group Rides',
                '$groupRidesCompleted',
                Icons.groups_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarageTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MY GARAGE',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.0,
              ),
            ),
            IconButton(
              onPressed: _addBike,
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (bikes.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.two_wheeler_outlined,
                  color: AppColors.primary,
                  size: 42,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No vehicle added',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add your motorcycle to make it available for rides.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ...bikes.map((bike) {
          final isSelected = bike['id'] == activeBikeId;
          final bikeImage = _bikeImageCache[bike['id'] ?? ''];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              customBorder: Border.all(
                color:
                    isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1.0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      image:
                          bikeImage != null
                              ? DecorationImage(
                                image: bikeImage,
                                fit: BoxFit.cover,
                              )
                              : null,
                    ),
                    child:
                        bikeImage != null
                            ? null
                            : Icon(
                              Icons.motorcycle_rounded,
                              color:
                                  isSelected ? AppColors.primary : Colors.grey,
                              size: 32,
                            ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                bike['nickname']!,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${bike['brand']} ${bike['model']}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bike['cc']} CC • ${bike['fuelType']}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        tooltip: 'Edit vehicle',
                        onPressed: () => _editBike(bike),
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      if (!isSelected)
                        IconButton(
                          onPressed: () => _selectActiveBike(bike['id']!),
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.green,
                          ),
                        ),
                      IconButton(
                        onPressed: () => _deleteBike(bike['id']!),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAchievementsTab() {
    // Achievements List (Locked / Unlocked)
    final achievements = [
      {
        'title': 'First Ride',
        'desc': 'Complete your first Sync journey',
        'icon': '🏆',
        'unlocked': _hasAchievement('First Ride') || totalRides > 0,
      },
      {
        'title': '100 km Club',
        'desc': 'Ride a total of 100 kilometers',
        'icon': '⚡',
        'unlocked': _hasAchievement('100 km Ride') || totalDistance >= 100,
      },
      {
        'title': '500 km Club',
        'desc': 'Ride a total of 500 kilometers',
        'icon': '🔥',
        'unlocked': totalDistance >= 500,
      },
      {
        'title': 'Night Rider',
        'desc': 'Complete a ride session after 8 PM',
        'icon': '🌙',
        'unlocked': _hasAchievement('Night Rider'),
      },
      {
        'title': 'Weekend Warrior',
        'desc': 'Complete a ride on a weekend',
        'icon': '⚔️',
        'unlocked': _hasAchievement('Weekend Explorer'),
      },
      {
        'title': 'Mountain Explorer',
        'desc': 'Ride at altitudes above 2000m',
        'icon': '⛰️',
        'unlocked': _hasAchievement('Mountain Rider') || longestRide > 150,
      },
      {
        'title': 'Leader',
        'desc': 'Host a ride session with members',
        'icon': '👑',
        'unlocked': _hasAchievement('Group Leader') || groupRidesCompleted > 0,
      },
      {
        'title': 'SOS Hero',
        'desc': 'Acknowledge another rider\'s SOS',
        'icon': '❤️',
        'unlocked': _hasAchievement('SOS Helper'),
      },
      {
        'title': '10 Rides',
        'desc': 'Complete 10 journey sessions',
        'icon': '🏍️',
        'unlocked': totalRides >= 10,
      },
      {
        'title': '50 Rides',
        'desc': 'Complete 50 journey sessions',
        'icon': '🌟',
        'unlocked': totalRides >= 50,
      },
      {
        'title': '100 Rides',
        'desc': 'Complete 100 journey sessions',
        'icon': '🔮',
        'unlocked': totalRides >= 100,
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.95,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final ach = achievements[index];
        final isUnlocked = ach['unlocked'] as bool;
        return GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ach['icon'] as String,
                style: TextStyle(
                  fontSize: 32,
                  color:
                      isUnlocked
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                ach['title'] as String,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isUnlocked
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                ach['desc'] as String,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isUnlocked
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUnlocked ? 'UNLOCKED' : 'LOCKED',
                  style: TextStyle(
                    color: isUnlocked ? Colors.green : Colors.grey,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasAchievement(String name) => unlockedAchievements.contains(name);

  ImageProvider? _imageProviderFor(String source) {
    if (source.isEmpty) return null;
    if (source.startsWith('http')) return NetworkImage(source);
    final file = File(source);
    if (file.existsSync()) return FileImage(file);
    return null;
  }

  void _refreshBikeImageCache(List<Map<String, String>> bikeList) {
    _bikeImageCache.clear();
    for (final bike in bikeList) {
      final id = bike['id'] ?? '';
      final imagePath = bike['imagePath'] ?? '';
      final provider = _imageProviderFor(imagePath);
      if (id.isNotEmpty && provider != null) {
        _bikeImageCache[id] = provider;
      }
    }
  }

  String _activeMotorcycleLabel() {
    if (activeBikeId.isNotEmpty) {
      for (final bike in bikes) {
        if (bike['id'] == activeBikeId) {
          final brand = (bike['brand'] ?? '').trim();
          final model = (bike['model'] ?? '').trim();
          final nickname = (bike['nickname'] ?? '').trim();
          final name = '$brand $model'.trim();
          if (name.isNotEmpty && nickname.isNotEmpty) {
            return '$nickname • $name';
          }
          if (name.isNotEmpty) return name;
          if (nickname.isNotEmpty) return nickname;
        }
      }
    }
    if (bikes.isNotEmpty) {
      final bike = bikes.first;
      final brand = (bike['brand'] ?? '').trim();
      final model = (bike['model'] ?? '').trim();
      final name = '$brand $model'.trim();
      if (name.isNotEmpty) return name;
    }
    return 'JourneySync Rider';
  }

  String _riderLocationLabel() {
    return 'Bengaluru, India';
  }
}

class _VehicleField extends StatelessWidget {
  const _VehicleField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTypography.bodyLarge.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.surfaceAlt.withValues(alpha: 0.45),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}
