import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_toast.dart';
import '../widgets/app_dialog.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Profile data
  String userName = 'Rider';
  String bio = 'Ready for the first synced ride.';
  String experienceLevel = 'New Rider';
  String avatarUrl = '';

  // Stats
  int totalRides = 0;
  double totalDistance = 0; // in km
  double longestRide = 0; // in km
  double hoursRidden = 0;
  String favoriteRoute = 'No favorite route yet';

  // Garage
  List<Map<String, String>> bikes = [];
  String activeBikeId = '';

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

    final savedBikesRaw = prefs.getStringList('garageBikes');
    List<Map<String, String>> loadedBikes = [];
    if (savedBikesRaw != null && savedBikesRaw.isNotEmpty) {
      loadedBikes =
          savedBikesRaw.map((b) {
            final parts = b.split('|');
            return {
              'id': parts[0],
              'brand': parts[1],
              'model': parts[2],
              'cc': parts[3],
              'nickname': parts[4],
              'fuelType': parts[5],
            };
          }).toList();
    }

    final activeBike = prefs.getString('userActiveBikeId') ?? '';

    setState(() {
      userName = prefs.getString('userName') ?? 'Rider';
      bio = prefs.getString('userBio') ?? 'Ready for the first synced ride.';
      experienceLevel = prefs.getString('userExperienceLevel') ?? 'New Rider';
      avatarUrl = prefs.getString('localAvatarPath') ?? '';

      totalRides = prefs.getInt('statTotalRides') ?? 0;
      totalDistance = prefs.getDouble('statTotalDistance') ?? 0;
      longestRide = prefs.getDouble('statLongestRide') ?? 0;
      hoursRidden = prefs.getDouble('statHoursRidden') ?? 0;
      favoriteRoute =
          prefs.getString('statFavoriteRoute') ?? 'No favorite route yet';

      bikes = loadedBikes;
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
          return '${b['id']}|${b['brand']}|${b['model']}|${b['cc']}|${b['nickname']}|${b['fuelType']}';
        }).toList();
    await prefs.setStringList('garageBikes', stringList);
  }

  Future<void> _addBike() async {
    final newBike = await _showVehicleForm();
    if (newBike == null) return;

    final shouldSetActive = bikes.isEmpty || activeBikeId.isEmpty;

    setState(() {
      bikes.add(newBike);
      if (shouldSetActive) activeBikeId = newBike['id']!;
    });
    await _saveBikesToPrefs(bikes);
    if (shouldSetActive) {
      await _selectActiveBike(newBike['id']!, showToast: false);
    }

    if (mounted) {
      showPremiumToast(
        context,
        '${newBike['nickname']} added to your garage!',
        type: PremiumToastType.success,
      );
    }
  }

  Future<Map<String, String>?> _showVehicleForm() async {
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final ccController = TextEditingController();
    final nicknameController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add vehicle',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Save the motorcycle you use for group rides.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
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
                            if (brand.isEmpty || model.isEmpty || cc.isEmpty) {
                              showPremiumToast(
                                context,
                                'Add brand, model, and CC.',
                                type: PremiumToastType.error,
                              );
                              return;
                            }
                            Navigator.pop(context, {
                              'id':
                                  'bike_${DateTime.now().millisecondsSinceEpoch}',
                              'brand': brand,
                              'model': model,
                              'cc': cc,
                              'nickname': nickname,
                              'fuelType': 'Petrol',
                            });
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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

    // Also update in Supabase
    final userId = prefs.getString('userId') ?? '';
    if (userId.isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'bike': bikeNameString})
            .eq('auth_user_id', userId);
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

    await _saveBikesToPrefs(bikes);

    // Update active bike name in prefs
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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rider Profile',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
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
                ],
              ),
            ),

            // Profile Info Header Card
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: GlassCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                elevated: true,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      backgroundImage:
                          avatarUrl.isNotEmpty && File(avatarUrl).existsSync()
                              ? FileImage(File(avatarUrl))
                              : null,
                      child:
                          avatarUrl.isNotEmpty && File(avatarUrl).existsSync()
                              ? null
                              : Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'R',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                userName,
                                style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6A00),
                                      Color(0xFFFF8C42),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  experienceLevel.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bio,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                    fontWeight: FontWeight.w800,
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.motorcycle_rounded,
                      color: isSelected ? AppColors.primary : Colors.grey,
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
                            Text(
                              bike['nickname']!,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
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
        'unlocked': totalRides > 0,
      },
      {
        'title': '100 km Club',
        'desc': 'Ride a total of 100 kilometers',
        'icon': '⚡',
        'unlocked': totalDistance >= 100,
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
        'unlocked': false,
      },
      {
        'title': 'Weekend Warrior',
        'desc': 'Complete a ride on a weekend',
        'icon': '⚔️',
        'unlocked': false,
      },
      {
        'title': 'Mountain Explorer',
        'desc': 'Ride at altitudes above 2000m',
        'icon': '⛰️',
        'unlocked': longestRide > 150,
      },
      {
        'title': 'Leader',
        'desc': 'Host a ride session with members',
        'icon': '👑',
        'unlocked': totalRides >= 10,
      },
      {
        'title': 'SOS Hero',
        'desc': 'Acknowledge another rider\'s SOS',
        'icon': '❤️',
        'unlocked': false,
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
