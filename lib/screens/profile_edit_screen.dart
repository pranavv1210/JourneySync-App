import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameController = TextEditingController();
  final _bikeNameController = TextEditingController();
  final _bikeNumberController = TextEditingController();
  final _phoneController = TextEditingController();

  String _userId = '';
  String _avatarUrl = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bikeNameController.dispose();
    _bikeNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userId = prefs.getString('userId') ?? '';
      _nameController.text = prefs.getString('userName') ?? '';
      _bikeNameController.text = prefs.getString('userBike') ?? '';
      _bikeNumberController.text = prefs.getString('userBikeNumber') ?? '';
      _phoneController.text = prefs.getString('userPhone') ?? '';
      _avatarUrl = prefs.getString('userAvatarUrl') ?? '';
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final bike = _bikeNameController.text.trim();
    final bikeNumber = _bikeNumberController.text.trim();

    if (name.isEmpty) {
      showPremiumToast(context, 'Name cannot be empty', type: PremiumToastType.error);
      return;
    }

    setState(() => _saving = true);

    try {
      if (_userId.isNotEmpty) {
        await SupabaseService().updateUserProfile(
          userId: _userId,
          name: name,
          bike: bike.isEmpty ? 'No bike added' : bike,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', name);
      await prefs.setString('userBike', bike.isEmpty ? 'No bike added' : bike);
      await prefs.setString('userBikeNumber', bikeNumber);

      if (!mounted) return;
      showPremiumToast(context, 'Profile saved!', type: PremiumToastType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showPremiumToast(context, 'Failed to save: $e', type: PremiumToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.forest,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: _avatarUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      _avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
                                    ),
                                  )
                                : _buildInitialsAvatar(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Profile Photo',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Fields
                    _buildFieldCard([
                      _buildField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'Your display name',
                        icon: Icons.person_outline_rounded,
                      ),
                      _divider(),
                      _buildField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: '+91 9876543210',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        readOnly: true, // Phone from auth, not editable
                        helperText: 'Set during sign-in',
                      ),
                    ]),

                    const SizedBox(height: 20),

                    _buildSectionLabel('VEHICLE DETAILS'),
                    const SizedBox(height: 10),
                    _buildFieldCard([
                      _buildField(
                        controller: _bikeNameController,
                        label: 'Vehicle Name',
                        hint: 'e.g. Royal Enfield GT 650',
                        icon: Icons.two_wheeler_rounded,
                      ),
                      _divider(),
                      _buildField(
                        controller: _bikeNumberController,
                        label: 'Vehicle Number',
                        hint: 'e.g. KA 01 AB 1234',
                        icon: Icons.pin_outlined,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ]),

                    const SizedBox(height: 32),
                    PremiumButton(
                      label: _saving ? 'Saving...' : 'Save Changes',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : _saveProfile,
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

  Widget _buildInitialsAvatar() {
    final name = _nameController.text.trim();
    return Center(
      child: Text(
        _initials(name),
        style: AppTypography.headlineLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
      ),
    );
  }

  Widget _buildFieldCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.sm,
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: AppColors.divider, indent: 56);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
    bool readOnly = false,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  style: AppTypography.bodyMedium.copyWith(
                    color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                    helperText: helperText,
                    helperStyle: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
