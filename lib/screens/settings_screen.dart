import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';
import '../widgets/app_dialog.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/journey_screen.dart';
import '../services/app_navigation.dart';
import '../services/app_version.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String userName = 'Rider';
  String userBike = 'No bike added';
  String userPhone = '';
  String localAvatarPath = '';
  String avatarUrl = '';
  List<Map<String, String>> emergencyContacts = const <Map<String, String>>[];
  final SupabaseService _supabaseService = SupabaseService();

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
      localAvatarPath = prefs.getString('localAvatarPath') ?? '';
      avatarUrl = prefs.getString('userAvatarUrl') ?? '';
      emergencyContacts = _decodeEmergencyContacts(
        prefs.getStringList('emergencyContacts') ?? const <String>[],
      );
    });
    final userId = (prefs.getString('userId') ?? '').trim();
    if (userId.isEmpty) return;
    try {
      final remoteContacts = await _supabaseService.fetchEmergencyContacts(
        userId: userId,
      );
      if (remoteContacts != null) {
        await _saveEmergencyContacts(remoteContacts, syncCloud: false);
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Sign Out?',
      message: 'You can always sign back in.',
      confirmLabel: 'Sign Out',
      cancelLabel: 'Cancel',
      destructive: true,
    );

    if (confirmed != true) return;

    try {
      await AuthService().clearSession();
      if (!mounted) return;
      unawaited(replaceAllWithAppRoute(context, const LoginScreen()));
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: const JourneyHeader(
                surface: true,
                leading: JourneyBackButton(),
                eyebrow: 'CONTROL CENTER',
                title: 'Settings',
                subtitle: 'Account, safety, feedback, legal, and app details.',
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
                    _buildProfileHeroCard(),
                    const SizedBox(height: 24),

                    // Settings Sections
                    _buildSection('Account', [
                      _buildSettingTile(
                        icon: Icons.two_wheeler_outlined,
                        title: 'Garage & Achievements',
                        subtitle: 'Manage vehicles, badges, and rider stats',
                        onTap: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                          if (updated == true) {
                            unawaited(_loadProfile());
                          }
                        },
                      ),
                      _buildSettingTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Emergency Contacts',
                        subtitle: 'Manage your emergency contacts',
                        onTap: _showEmergencyContactsSheet,
                      ),
                      _buildSettingTile(
                        icon: Icons.shield_outlined,
                        title: 'Privacy',
                        subtitle: 'Control your data and visibility',
                        onTap: _showPrivacySheet,
                      ),
                      _buildSettingTile(
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        subtitle: 'Customize your experience',
                        onTap:
                            () => _showInfoDialog(
                              'Theme Customization',
                              'JourneySync currently uses the premium light theme. Dark/system theme support will be added after core ride flows are stable.',
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
                        icon: Icons.star_outline_rounded,
                        title: 'Give Feedback',
                        subtitle: 'Rate JourneySync and share one note',
                        onTap: _openFeedback,
                      ),
                      _buildSettingTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Ride alerts and updates',
                        onTap:
                            () => _showInfoDialog(
                              'Notifications',
                              'Ride alerts, SOS messages, and route updates are enabled in-app. Push notifications require Firebase configuration on production builds.',
                            ),
                      ),
                      _buildSettingTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About',
                        subtitle: AppVersion.label,
                        onTap:
                            () => _showInfoDialog(
                              'About JourneySync',
                              '${AppVersion.label}\nBuilt for group rides, live tracking, SOS alerts, and ride coordination.',
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

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (updated == true) {
      unawaited(_loadProfile());
    }
  }

  Future<void> _openFeedback() {
    return showJourneySyncFeedbackSheet(context);
  }

  Widget _buildProfileHeroCard() {
    final image = _settingsHeroImage();
    final bikeText =
        userBike.trim().isEmpty || userBike == 'No bike added'
            ? 'JourneySync Rider'
            : userBike.trim();

    return Semantics(
      button: true,
      label: 'Edit profile',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: _openEditProfile,
        child: Container(
          height: 330,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.forestDark,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.lg,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image(
                  image: image,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.24),
                  filterQuality: FilterQuality.medium,
                )
              else
                _buildSettingsHeroFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.forestDark.withValues(alpha: 0.24),
                      AppColors.forestDark.withValues(alpha: 0.82),
                      AppColors.forestDark.withValues(alpha: 0.96),
                    ],
                    stops: const [0.12, 0.46, 0.76, 1],
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.textOnDark,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                bottom: AppSpacing.xl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        'PROFILE',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
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
                            bikeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textOnDark.withValues(
                                alpha: 0.88,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        'Edit photo, rider details, and account profile',
                        textAlign: TextAlign.center,
                        style: AppTypography.buttonMedium.copyWith(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

  ImageProvider? _settingsHeroImage() {
    if (localAvatarPath.isNotEmpty) {
      final file = File(localAvatarPath);
      if (file.existsSync()) return FileImage(file);
    }
    if (avatarUrl.startsWith('http')) {
      return NetworkImage(avatarUrl);
    }
    return null;
  }

  Widget _buildSettingsHeroFallback() {
    final initial = userName.trim().isNotEmpty ? userName.trim()[0] : 'R';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5EEE7), Color(0xFF1E3A2F), Color(0xFF0F1F19)],
        ),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: AppTypography.displayLarge.copyWith(
            color: AppColors.primaryLight.withValues(alpha: 0.72),
            fontSize: 92,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<Map<String, String>> _decodeEmergencyContacts(List<String> rows) {
    return rows
        .map((row) {
          final parts = row.split('|');
          return {
            'name': parts.isNotEmpty ? parts[0] : '',
            'phone': parts.length > 1 ? parts[1] : '',
            'relation': parts.length > 2 ? parts[2] : '',
          };
        })
        .where((contact) => (contact['phone'] ?? '').trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _saveEmergencyContacts(
    List<Map<String, String>> contacts, {
    bool syncCloud = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String clean(String value) => value.replaceAll('|', ' ').trim();
    await prefs.setStringList(
      'emergencyContacts',
      contacts
          .map(
            (contact) =>
                '${clean(contact['name'] ?? '')}|${clean(contact['phone'] ?? '')}|${clean(contact['relation'] ?? '')}',
          )
          .toList(),
    );
    if (syncCloud) {
      final userId = (prefs.getString('userId') ?? '').trim();
      if (userId.isNotEmpty) {
        try {
          await _supabaseService.saveEmergencyContacts(
            userId: userId,
            contacts: contacts,
          );
        } catch (_) {
          if (mounted) {
            showPremiumToast(
              context,
              'Could not sync emergency contacts.',
              type: PremiumToastType.error,
            );
          }
        }
      }
    }
    if (!mounted) return;
    setState(() => emergencyContacts = contacts);
  }

  Future<void> _showEmergencyContactsSheet() async {
    final contacts = emergencyContacts.map((item) => Map.of(item)).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> addContact() async {
              final result = await _showEmergencyContactForm(context);
              if (result == null) return;
              contacts.add(result);
              await _saveEmergencyContacts(contacts);
              setSheetState(() {});
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.48,
              maxChildSize: 0.92,
              builder: (context, controller) {
                return Material(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Emergency Contacts',
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: addContact,
                            icon: const Icon(Icons.add_circle_rounded),
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'These contacts stay on this phone and are shown first when SOS is triggered during a ride.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (contacts.isEmpty)
                        GlassCard(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              Icon(
                                Icons.health_and_safety_outlined,
                                color: AppColors.primary,
                                size: 42,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No contacts added',
                                style: AppTypography.titleLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Add family, friends, or your ride marshal so help is one tap away.',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              ElevatedButton.icon(
                                onPressed: addContact,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Contact'),
                              ),
                            ],
                          ),
                        )
                      else
                        ...contacts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final contact = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    child: Text(
                                      (contact['name'] ?? 'E')
                                          .trim()
                                          .characters
                                          .first
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          contact['name'] ??
                                              'Emergency contact',
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        Text(
                                          '${contact['relation'] ?? 'Contact'}  ${contact['phone'] ?? ''}',
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Call',
                                    onPressed:
                                        () =>
                                            _callPhone(contact['phone'] ?? ''),
                                    icon: const Icon(Icons.call_rounded),
                                    color: AppColors.forest,
                                  ),
                                  IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () async {
                                      contacts.removeAt(index);
                                      await _saveEmergencyContacts(contacts);
                                      setSheetState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    color: AppColors.error,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>?> _showEmergencyContactForm(
    BuildContext parentContext,
  ) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationController = TextEditingController();
    return showModalBottomSheet<Map<String, String>>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add emergency contact',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _settingsTextField(nameController, 'Name', Icons.person),
                  const SizedBox(height: 12),
                  _settingsTextField(
                    phoneController,
                    'Phone number',
                    Icons.call,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _settingsTextField(
                    relationController,
                    'Relation',
                    Icons.badge_outlined,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final phone = phoneController.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              showPremiumToast(
                                context,
                                'Add a name and phone number.',
                                type: PremiumToastType.error,
                              );
                              return;
                            }
                            Navigator.pop(context, {
                              'name': name,
                              'phone': phone,
                              'relation':
                                  relationController.text.trim().isEmpty
                                      ? 'Emergency'
                                      : relationController.text.trim(),
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
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
      relationController.dispose();
    });
  }

  Widget _settingsTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: normalized);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Could not open phone dialer.',
        type: PremiumToastType.error,
      );
    }
  }

  void _showPrivacySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.58,
          minChildSize: 0.42,
          maxChildSize: 0.86,
          builder: (context, controller) {
            return Material(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                children: [
                  Text(
                    'Privacy Settings',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'JourneySync keeps ride safety data intentional and visible.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _privacyPoint(
                    Icons.location_on_outlined,
                    'Live location',
                    'Shared only while Ride Mode or ride radar is active.',
                  ),
                  _privacyPoint(
                    Icons.account_circle_outlined,
                    'Profile photos',
                    'Stored locally on this phone and not uploaded.',
                  ),
                  _privacyPoint(
                    Icons.security_rounded,
                    'Sensitive areas',
                    'Authentication, sessions, Supabase RLS, GPS, SOS, and media access are treated as security-sensitive surfaces.',
                  ),
                  _privacyPoint(
                    Icons.report_gmailerrorred_rounded,
                    'Report issues',
                    'Send private security reports to journeysync.app@gmail.com with reproduction steps and impact.',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _privacyPoint(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
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

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            title: Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTypography.buttonMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete Account',
      message:
          'Are you sure you want to delete your account? This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      destructive: true,
    );

    if (confirmed == true) {
      if (mounted) {
        showPremiumToast(
          context,
          'Account deletion request submitted.',
          type: PremiumToastType.info,
        );
      }
    }
  }
}
