import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';
import '../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bikeController = TextEditingController();
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
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString('userName') ?? '';
      _bikeController.text = prefs.getString('userBike') ?? '';
      _phoneController.text = prefs.getString('userPhone') ?? '';
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

      await prefs.setString('userName', name);
      await prefs.setString('userBike', bike);
      await prefs.setString('userPhone', phone);

      final userId = prefs.getString('userId') ?? '';
      if (userId.isNotEmpty) {
        try {
          final updated = await _supabaseService.updateUserProfile(
            userId: userId,
            name: name,
            bike: bike,
            phone: phone,
          );
          await prefs.setString(
            'userName',
            (updated['name'] ?? name).toString(),
          );
          await prefs.setString(
            'userBike',
            (updated['bike'] ?? bike).toString(),
          );
          await prefs.setString(
            'userPhone',
            (updated['phone'] ?? phone).toString(),
          );
          await _syncAvatarToSupabase(userId, prefs);
        } catch (e) {
          debugPrint('Error updating profile in Supabase: $e');
          // Non-blocking if offline
        }
      }

      if (!mounted) return;
      showPremiumToast(
        context,
        'Profile updated successfully',
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
                    'Edit Profile',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
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
                                  Center(
                                    child: GestureDetector(
                                      onTap: _pickProfilePhoto,
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          CircleAvatar(
                                            radius: 46,
                                            backgroundColor: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            backgroundImage:
                                                _localAvatarPath.isNotEmpty &&
                                                        File(
                                                          _localAvatarPath,
                                                        ).existsSync()
                                                    ? FileImage(
                                                      File(_localAvatarPath),
                                                    )
                                                    : null,
                                            child:
                                                _localAvatarPath.isNotEmpty &&
                                                        File(
                                                          _localAvatarPath,
                                                        ).existsSync()
                                                    ? null
                                                    : Icon(
                                                      Icons.person_rounded,
                                                      color: AppColors.primary,
                                                      size: 38,
                                                    ),
                                          ),
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.surface,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
                                    'Mobile Number',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: _inputTextStyle(),
                                    decoration: _inputDecoration(
                                      'Enter your mobile number',
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

  InputDecoration _inputDecoration(String hint) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
