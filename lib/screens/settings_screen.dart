import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';
import '../services/app_navigation.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String userName = 'Rider';
  String userBike = 'No bike added';
  String userPhone = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('userName') ?? 'Rider';
      userBike = prefs.getString('userBike') ?? 'No bike added';
      userPhone = prefs.getString('userPhone') ?? '';
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Sign Out?', style: AppTypography.headlineSmall),
            content: const Text('You can always sign back in.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: AppTypography.buttonMedium),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await AuthService().clearSession();
      if (!mounted) return;
      replaceWithAppRoute(context, const LoginScreen());
    } catch (e) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Error signing out.',
        type: PremiumToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                        if (updated == true) {
                          _loadProfile();
                        }
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        elevated: true,
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.forest.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: AppColors.forest,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: AppTypography.headlineSmall.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userBike,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.edit_rounded,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Settings Sections
                    _buildSection('Account', [
                      _buildSettingTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Emergency Contacts',
                        subtitle: 'Manage your emergency contacts',
                        onTap:
                            () => _showComingSoonDialog(
                              'Emergency Contacts',
                              'You will be able to add up to 3 emergency contacts who will be notified if a crash is detected.',
                            ),
                      ),
                      _buildSettingTile(
                        icon: Icons.shield_outlined,
                        title: 'Privacy',
                        subtitle: 'Control your data and visibility',
                        onTap:
                            () => _showComingSoonDialog(
                              'Privacy Settings',
                              'Manage who can see your live location and ride history.',
                            ),
                      ),
                      _buildSettingTile(
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        subtitle: 'Customize your experience',
                        onTap:
                            () => _showComingSoonDialog(
                              'Theme Customization',
                              'Switch between Light, Dark, and System Default themes.',
                            ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _buildSection('Data', [
                      _buildSettingTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Delete Account',
                        subtitle: 'Permanently remove your data',
                        isDestructive: true,
                        onTap: () => _showDeleteAccountDialog(),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _buildSection('Support', [
                      _buildSettingTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Ride alerts and updates',
                        onTap:
                            () => _showComingSoonDialog(
                              'Notifications',
                              'Configure push notifications for nearby rides and group messages.',
                            ),
                      ),
                      _buildSettingTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About',
                        subtitle: 'JourneySync v1.1.0',
                        onTap:
                            () => _showComingSoonDialog(
                              'About JourneySync',
                              'JourneySync is designed for riders to sync their journeys securely. Version 1.1.0.',
                            ),
                      ),
                    ]),

                    const SizedBox(height: 32),

                    // Logout
                    PremiumButton(
                      label: 'Sign Out',
                      variant: PremiumButtonVariant.secondary,
                      icon: Icons.logout_rounded,
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.md),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          elevated: false,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap:
          onTap ??
          () {
            showPremiumToast(
              context,
              '$title coming soon',
              type: PremiumToastType.info,
            );
          },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    isDestructive
                        ? AppColors.error.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.error : AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color:
                          isDestructive
                              ? AppColors.error
                              : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title, style: AppTypography.headlineSmall),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: AppTypography.buttonMedium),
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Account', style: AppTypography.headlineSmall),
            content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: AppTypography.buttonMedium),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  showPremiumToast(
                    context,
                    'Account deletion request submitted.',
                    type: PremiumToastType.info,
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
