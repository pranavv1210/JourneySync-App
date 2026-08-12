import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';
import '../widgets/journey_screen.dart';
import '../widgets/ride_loading_indicator.dart';
import '../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bikeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();

  bool _loading = true;
  bool _saving = false;
  String _localAvatarPath = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final authUser = Supabase.instance.client.auth.currentUser;
    final authEmail =
        (authUser?.email ?? authUser?.userMetadata?['email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final cachedPhone = prefs.getString('userPhone') ?? '';
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString('userName') ?? '';
      _bikeController.text = prefs.getString('userBike') ?? '';
      _emailController.text =
          authEmail.isNotEmpty
              ? authEmail
              : (prefs.getString('userEmail') ?? '').trim().toLowerCase();
      _phoneController.text = cachedPhone.contains('@') ? '' : cachedPhone;
      _localAvatarPath = prefs.getString('localAvatarPath') ?? '';
      _loading = false;
    });
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${directory.path}/profile');
      if (!profileDir.existsSync()) {
        profileDir.createSync(recursive: true);
      }
      final extension = image.path.split('.').last;
      final savedPath =
          '${profileDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await File(image.path).copy(savedPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('localAvatarPath', savedPath);
      await prefs.setString('userAvatarUrl', '');

      if (!mounted) return;
      setState(() => _localAvatarPath = savedPath);
    } catch (error) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Could not select photo.',
        type: PremiumToastType.error,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      showPremiumToast(
        context,
        'Name cannot be empty',
        type: PremiumToastType.error,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final name = _nameController.text.trim();
      final bike = _bikeController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim().toLowerCase();

      await prefs.setString('userName', name);
      await prefs.setString('userBike', bike);
      if (email.isNotEmpty) {
        await prefs.setString('userEmail', email);
      }
      await prefs.setString('userPhone', phone);

      final userId = prefs.getString('userId') ?? '';
      if (userId.isNotEmpty) {
        try {
          final updated = await _supabaseService.updateUserProfile(
            userId: userId,
            name: name,
            bike: bike,
          );
          await prefs.setString(
            'userName',
            (updated['name'] ?? name).toString(),
          );
          await prefs.setString(
            'userBike',
            (updated['bike'] ?? bike).toString(),
          );
          await prefs.setString('userPhone', phone);
          await _syncAvatarToSupabase(userId, prefs);
        } catch (e) {
          debugPrint('Error updating profile in Supabase: $e');
          // Non-blocking if offline
        }
      }

      if (!mounted) return;
      showPremiumToast(
        context,
        phone.isEmpty
            ? 'Profile updated successfully'
            : 'Profile saved. Mobile OTP verification will be available soon.',
        type: PremiumToastType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Error saving profile',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _syncAvatarToSupabase(
    String userId,
    SharedPreferences prefs,
  ) async {
    if (_localAvatarPath.isEmpty || !File(_localAvatarPath).existsSync()) {
      return;
    }
    try {
      final bytes = await File(_localAvatarPath).readAsBytes();
      final avatarUrl = await _supabaseService.uploadAvatar(
        userId: userId,
        bytes: bytes,
      );
      await _supabaseService.updateUserAvatar(
        userId: userId,
        avatarUrl: avatarUrl,
      );
      await prefs.setString('userAvatarUrl', avatarUrl);
    } catch (error) {
      debugPrint('Avatar upload skipped: $error');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bikeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
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
                eyebrow: 'RIDER DETAILS',
                title: 'Edit Profile',
                subtitle:
                    'Update your public identity, bike, and contact details.',
              ),
            ),

            Expanded(
              child:
                  _loading
                      ? const Center(
                        child: RideLoadingIndicator(label: 'Loading profile'),
                      )
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassCard(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              elevated: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildEditablePhotoHero(),
                                  const SizedBox(height: AppSpacing.xl),
                                  Text(
                                    'Name',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _nameController,
                                    style: _inputTextStyle(),
                                    decoration: _inputDecoration(
                                      'Enter your name',
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  Text(
                                    'Vehicle Name',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _bikeController,
                                    style: _inputTextStyle(),
                                    decoration: _inputDecoration(
                                      'E.g. Royal Enfield Classic 350',
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  Text(
                                    'Email ID',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _emailController,
                                    readOnly: true,
                                    style: _inputTextStyle(),
                                    decoration: _inputDecoration(
                                      'Signed in with Google',
                                      suffixIcon: Icons.lock_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This comes from Google sign-in and cannot be changed here.',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  Text(
                                    'Mobile Number Optional',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: _inputTextStyle(),
                                    onTap: () {
                                      showPremiumToast(
                                        context,
                                        'OTP verification will be available soon.',
                                        type: PremiumToastType.info,
                                      );
                                    },
                                    decoration: _inputDecoration(
                                      'Add mobile number',
                                      suffixIcon: Icons.sms_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            PremiumButton(
                              label: _saving ? 'Saving...' : 'Save Changes',
                              onPressed: _saving ? null : _saveProfile,
                              variant: PremiumButtonVariant.primary,
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

  TextStyle _inputTextStyle() {
    return AppTypography.bodyLarge.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textTertiary,
      ),
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      suffixIcon:
          suffixIcon == null
              ? null
              : Icon(suffixIcon, color: AppColors.textTertiary, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildEditablePhotoHero() {
    final imageProvider =
        _localAvatarPath.isNotEmpty && File(_localAvatarPath).existsSync()
            ? FileImage(File(_localAvatarPath))
            : null;
    final initial =
        _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()[0]
            : 'R';

    return GestureDetector(
      onTap: _pickProfilePhoto,
      child: Container(
        height: 220,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.forestDark,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageProvider != null)
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.22),
                filterQuality: FilterQuality.medium,
              )
            else
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF5EEE7),
                      AppColors.forest,
                      AppColors.forestDark,
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    initial.toUpperCase(),
                    style: AppTypography.displayLarge.copyWith(
                      color: AppColors.primaryLight.withValues(alpha: 0.72),
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.forestDark.withValues(alpha: 0.24),
                    AppColors.forestDark.withValues(alpha: 0.82),
                  ],
                  stops: const [0.18, 0.56, 1],
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.md,
              top: AppSpacing.md,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.textOnDark,
                  size: 20,
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Text(
                'Profile photo',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
