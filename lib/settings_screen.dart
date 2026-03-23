import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_toast.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final primary = const Color(0xFFD46211);
  final forest = const Color(0xFF1E3A2F);
  final background = const Color(0xFFF8F7F6);
  final sandBorder = const Color(0xFFE8E4DE);
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  bool loading = true;
  bool isLoggingOut = false;

  String userId = '';
  String userName = 'Rider';
  String userEmail = '';
  String userBike = 'No bike added';
  String userAvatarUrl = '';
  bool isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userId = prefs.getString('userId') ?? '';
      userName = prefs.getString('userName') ?? 'Rider';
      userEmail = prefs.getString('userPhone') ?? '';
      userBike = prefs.getString('userBike') ?? 'No bike added';
      userAvatarUrl = prefs.getString('userAvatarUrl') ?? '';
      loading = false;
    });

    if (userId.trim().isNotEmpty) {
      try {
        final row = await _supabaseService.fetchUserById(userId);
        final serverAvatar = (row?['avatar_url'] ?? '').toString().trim();
        if (serverAvatar.isNotEmpty) {
          await _saveString('userAvatarUrl', serverAvatar);
          if (!mounted) return;
          setState(() {
            userAvatarUrl = serverAvatar;
          });
        }
      } catch (_) {
        // Keep cached avatar if remote fetch fails.
      }
    }
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileCard(),
                        const SizedBox(height: 14),
                        _supportCard(),
                        const SizedBox(height: 14),
                        _accountCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: forest),
          ),
          const SizedBox(width: 4),
          Text(
            "Settings",
            style: TextStyle(
              color: forest,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return _settingsCard(
      title: 'Profile',
      icon: Icons.person_outline,
      child: Column(
        children: [
          Row(
            children: [
              _profileAvatar(size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: isUploadingAvatar ? null : _pickAndUploadAvatar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon:
                        isUploadingAvatar
                            ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(
                      isUploadingAvatar ? 'Uploading...' : 'Change Photo',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Name', userName),
          const SizedBox(height: 8),
          _infoRow(
            'Email',
            userEmail.trim().isNotEmpty ? userEmail : 'Not available',
          ),
          const SizedBox(height: 8),
          _infoRow('Bike', userBike),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _editProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileAvatar({double size = 56}) {
    final hasNetworkAvatar = userAvatarUrl.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: sandBorder, width: 2),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          hasNetworkAvatar
              ? Image.network(
                userAvatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(size),
              )
              : _avatarFallback(size),
    );
  }

  Widget _avatarFallback(double size) {
    final trimmed = userName.trim();
    final first = trimmed.isNotEmpty ? trimmed.substring(0, 1) : 'R';
    return Container(
      color: primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        first.toUpperCase(),
        style: TextStyle(
          color: primary,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _supportCard() {
    return _settingsCard(
      title: 'Support & Legal',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _tapRow(
            title: 'Help Center',
            subtitle: 'App usage guide and troubleshooting.',
            onTap: _showHelpCenterModal,
          ),
          const Divider(height: 18),
          _tapRow(
            title: 'Privacy Policy',
            subtitle: 'How JourneySync handles your data.',
            onTap: _showPrivacyPolicyModal,
          ),
          const Divider(height: 18),
          _tapRow(
            title: 'Terms of Service',
            subtitle: 'Usage rules and responsibilities.',
            onTap: _showTermsModal,
          ),
          const Divider(height: 18),
          _tapRow(
            title: 'About JourneySync',
            subtitle:
                'Group ride planning, live coordination, and rider safety.',
            onTap: _showAboutModal,
          ),
        ],
      ),
    );
  }

  Widget _accountCard() {
    return _settingsCard(
      title: 'Account',
      icon: Icons.manage_accounts_outlined,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoggingOut ? null : _confirmLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon:
                  isLoggingOut
                      ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.logout_rounded, color: Colors.white),
              label: Text(
                isLoggingOut ? "Logging Out..." : "Logout",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sandBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: forest,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: forest.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: forest,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tapRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: forest,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: forest.withValues(alpha: 0.65),
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, color: forest.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: userName);
    final bikeController = TextEditingController(text: userBike);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bikeController,
                decoration: const InputDecoration(labelText: 'Bike'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Save',
                style: TextStyle(color: primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (saved != true) return;
    final updatedName = nameController.text.trim();
    final updatedBike = bikeController.text.trim();
    if (updatedName.isEmpty || updatedBike.isEmpty) {
      _showInfo('Profile', 'Name and bike cannot be empty.');
      return;
    }

    await _saveString('userName', updatedName);
    await _saveString('userBike', updatedBike);

    if (userId.trim().isNotEmpty) {
      try {
        await _supabaseService.updateUserProfile(
          userId: userId,
          name: updatedName,
          bike: updatedBike,
        );
      } catch (_) {
        // Local profile still updates even if network fails.
      }
    }

    if (!mounted) return;
    setState(() {
      userName = updatedName;
      userBike = updatedBike;
    });
    _showInfo('Profile', 'Profile updated.');
  }

  Future<void> _pickAndUploadAvatar() async {
    if (userId.trim().isEmpty) {
      _showInfo('Profile', 'Login again to upload profile picture.');
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (file == null) return;

      CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          compressQuality: 88,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Profile Photo',
              toolbarColor: forest,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              hideBottomControls: true,
              cropFrameStrokeWidth: 2,
            ),
            IOSUiSettings(
              title: 'Crop Profile Photo',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              rotateButtonsHidden: false,
              aspectRatioPickerButtonHidden: true,
            ),
          ],
        );
      } on PlatformException catch (error) {
        _showInfo(
          'Profile',
          'Cropper issue on this device (${error.code}). Uploading selected image instead.',
        );
      } catch (_) {
        _showInfo(
          'Profile',
          'Could not open cropper. Uploading selected image instead.',
        );
      }

      setState(() {
        isUploadingAvatar = true;
      });

      final selectedPath = croppedFile?.path ?? file.path;
      final bytes =
          croppedFile != null
              ? await croppedFile.readAsBytes()
              : await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Selected image file is empty.');
      }
      final contentType = _contentTypeForFile(selectedPath);
      final url = await _supabaseService.uploadAvatar(
        userId: userId,
        bytes: Uint8List.fromList(bytes),
        contentType: contentType,
      );
      await _supabaseService.updateUserAvatar(userId: userId, avatarUrl: url);
      await _saveString('userAvatarUrl', url);

      if (!mounted) return;
      setState(() {
        userAvatarUrl = url;
      });
      _showInfo('Profile', 'Profile photo updated.');
    } catch (error) {
      _showInfo('Profile', _avatarUploadErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          isUploadingAvatar = false;
        });
      }
    }
  }

  String _contentTypeForFile(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _avatarUploadErrorMessage(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('bucket not found')) {
      return 'Photo upload is not configured on the server yet. Please contact support/admin to create the storage bucket.';
    }
    if (lower.contains('missing users.avatar_url column') ||
        (lower.contains('avatar_url') && lower.contains('pgrst204'))) {
      return 'Server DB issue: users.avatar_url column is missing in Supabase schema cache. Add the column and refresh schema cache, then retry.';
    }
    return 'Could not upload photo: $text';
  }

  void _showInfo(String title, String message) {
    showAppToast(context, '$title: $message', type: AppToastType.info);
  }

  Future<void> _showHelpCenterModal() {
    return _showContentModal(
      title: 'Help Center',
      content:
          'Welcome to JourneySync.\n\n'
          '1. Getting Started\n'
          '- Verify your phone number using OTP.\n'
          '- For new users, add your name and bike.\n'
          '- Continue to Home to create or discover rides.\n\n'
          '2. Creating a Ride\n'
          '- Tap Create Ride.\n'
          '- Enter title, start location, and destination.\n'
          '- Submit to publish your ride to nearby riders.\n\n'
          '3. Nearby Active Rides\n'
          '- Tap Nearby Active Rides to search.\n'
          '- Select a ride and join to enter the lobby.\n\n'
          '4. Live Ride & SOS\n'
          '- During ride sessions, location and rider context may be shared.\n'
          '- SOS sends emergency ride context to support quick response.\n\n'
          'Need help?\n'
          'Contact: journeysync.app@gmail.com',
    );
  }

  Future<void> _showPrivacyPolicyModal() {
    return _showContentModal(
      title: 'Privacy Policy',
      content:
          'Effective date: February 24, 2026\n\n'
          'JourneySync collects only the data needed to run the app safely:\n'
          '- Phone number (for account verification)\n'
          '- Profile details (name, bike)\n'
          '- Ride data (title, start, destination, participants)\n'
          '- Optional location data during map/live ride use\n\n'
          'How we use data:\n'
          '- Account authentication and profile retrieval\n'
          '- Ride creation, discovery, and coordination\n'
          '- Safety workflows like SOS context sharing\n\n'
          'Data sharing:\n'
          '- We do not sell user data.\n'
          '- Ride-related information is shared only with app participants as required by features.\n\n'
          'Data control:\n'
          '- You can update profile fields in Settings.\n'
          '- You can logout from this device anytime.\n\n'
          'Questions about privacy:\n'
          'journeysync.app@gmail.com',
    );
  }

  Future<void> _showTermsModal() {
    return _showContentModal(
      title: 'Terms of Service',
      content:
          'By using JourneySync, you agree to:\n\n'
          '- Provide accurate account and ride details.\n'
          '- Use the app responsibly and lawfully.\n'
          '- Avoid posting harmful, abusive, or misleading content.\n'
          '- Respect local traffic laws and ride safely at all times.\n\n'
          'Safety notice:\n'
          'JourneySync is a coordination platform and does not guarantee rider behavior, route safety, or emergency outcomes.\n\n'
          'Account rules:\n'
          '- You are responsible for activity performed through your verified number.\n'
          '- We may restrict access for misuse, fraud, or safety violations.\n\n'
          'Service updates:\n'
          '- Features may be updated to improve reliability and safety.\n\n'
          'Support contact:\n'
          'journeysync.app@gmail.com',
    );
  }

  Future<void> _showAboutModal() {
    return _showContentModal(
      title: 'About JourneySync',
      content:
          'JourneySync is a motorcycle ride planning and coordination app.\n\n'
          'Core purpose:\n'
          '- Help riders create, discover, and join group rides.\n'
          '- Improve coordination with live ride context.\n'
          '- Keep safety-first workflows like SOS available.\n\n'
          'What you can do:\n'
          '- OTP login\n'
          '- Profile and bike setup\n'
          '- Create rides and find nearby active rides\n'
          '- View map context for ride activity\n\n'
          'Built for riders who value smooth planning and safer group journeys.\n\n'
          'Contact:\n'
          'journeysync.app@gmail.com',
    );
  }

  Future<void> _showContentModal({
    required String title,
    required String content,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                content,
                style: TextStyle(
                  color: forest.withValues(alpha: 0.85),
                  height: 1.5,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Do you want to logout from JourneySync?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                "Logout",
                style: TextStyle(color: primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;
    await _logout();
  }

  Future<void> _logout() async {
    setState(() {
      isLoggingOut = true;
    });

    try {
      await _authService.logoutAuth0();
    } catch (_) {
      // If browser-based logout fails, continue local logout to avoid blocking user.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isLoggedIn", false);
    await prefs.remove("userName");
    await prefs.remove("userBike");
    await prefs.remove("userAvatarUrl");
    await prefs.remove("userPhone");
    await prefs.remove("userId");
    await prefs.remove("phoneEmailAccessToken");
    await prefs.remove("phoneEmailJwtToken");

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
