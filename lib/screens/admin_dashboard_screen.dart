import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_navigation.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/journey_screen.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_button.dart';
import 'login_screen.dart';

const String journeySyncAdminEmail = 'journeysync.app@gmail.com';

bool isJourneySyncAdminEmail(String email) {
  return email.trim().toLowerCase() == journeySyncAdminEmail;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _loading = true;
  String _error = '';
  int _profiles = 0;
  int _rides = 0;
  int _feedbackCount = 0;
  int _deletionRequestCount = 0;
  List<Map<String, dynamic>> _feedback = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _deletionRequests = const <Map<String, dynamic>>[];
  String _busyRequestId = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadDashboard());
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final feedback = await _supabaseService.fetchAdminFeedback(limit: 30);
      final deletionRequests = await _supabaseService
          .fetchAccountDeletionRequests(limit: 30);
      final profiles = await _countBestEffort('profiles');
      final rides = await _countBestEffort('rides');
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _rides = rides;
        _feedbackCount = feedback.length;
        _deletionRequestCount = deletionRequests.length;
        _feedback = feedback;
        _deletionRequests = deletionRequests;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'Dashboard data is blocked. Apply the admin feedback RLS migration.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int> _countBestEffort(String table) async {
    try {
      return await _supabaseService.countRows(table);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _signOut() async {
    await AuthService().clearSession();
    if (!mounted) return;
    unawaited(replaceAllWithAppRoute(context, const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              JourneyHeader(
                surface: true,
                eyebrow: 'OWNER DASHBOARD',
                title: 'JourneySync',
                subtitle: journeySyncAdminEmail,
                trailing: IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_loading)
                const LinearProgressIndicator(color: AppColors.primary)
              else ...[
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.45,
                  children: [
                    _MetricCard(
                      label: 'Riders',
                      value: _profiles.toString(),
                      icon: Icons.groups_rounded,
                    ),
                    _MetricCard(
                      label: 'Rides',
                      value: _rides.toString(),
                      icon: Icons.route_rounded,
                    ),
                    _MetricCard(
                      label: 'Deletion requests',
                      value: _deletionRequestCount.toString(),
                      icon: Icons.person_remove_rounded,
                    ),
                    _MetricCard(
                      label: 'Feedback',
                      value: _feedbackCount.toString(),
                      icon: Icons.rate_review_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _DashboardSectionTitle(
                  title: 'Account deletion requests',
                  onRefresh: _loadDashboard,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_deletionRequests.isEmpty)
                  const GlassCard(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text('No pending deletion requests.'),
                  )
                else
                  ..._deletionRequests.map(
                    (row) => _DeletionRequestCard(
                      row: row,
                      busy: _busyRequestId == (row['id'] ?? '').toString(),
                      onApprove: () => _approveDeletionRequest(row),
                      onReject: () => _rejectDeletionRequest(row),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Latest feedback',
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadDashboard,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error.isNotEmpty)
                  GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      _error,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (_feedback.isEmpty)
                  const GlassCard(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text('No feedback received yet.'),
                  )
                else
                  ..._feedback.map((row) => _FeedbackCard(row: row)),
                const SizedBox(height: AppSpacing.xl),
                PremiumButton(
                  label: 'Refresh dashboard',
                  icon: Icons.refresh_rounded,
                  onPressed: _loadDashboard,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveDeletionRequest(Map<String, dynamic> row) async {
    final id = (row['id'] ?? '').toString().trim();
    if (id.isEmpty || _busyRequestId.isNotEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Permanently delete account?'),
            content: const Text(
              'Approval erases the rider profile, linked ride data, stored photos, auth user, and the deletion request record. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete permanently'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    setState(() => _busyRequestId = id);
    try {
      await _supabaseService.approveAccountDeletionRequest(id);
      await _loadDashboard();
    } finally {
      if (mounted) setState(() => _busyRequestId = '');
    }
  }

  Future<void> _rejectDeletionRequest(Map<String, dynamic> row) async {
    final id = (row['id'] ?? '').toString().trim();
    if (id.isEmpty || _busyRequestId.isNotEmpty) return;
    setState(() => _busyRequestId = id);
    try {
      await _supabaseService.rejectAccountDeletionRequest(id);
      await _loadDashboard();
    } finally {
      if (mounted) setState(() => _busyRequestId = '');
    }
  }
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({required this.title, required this.onRefresh});

  final String title;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _DeletionRequestCard extends StatelessWidget {
  const _DeletionRequestCard({
    required this.row,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final name = (row['rider_name'] ?? 'Rider').toString();
    final email = (row['email'] ?? '').toString();
    final requestedAt = (row['requested_at'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              email.isEmpty ? 'No email recorded' : email,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (requestedAt.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                requestedAt.length > 16
                    ? requestedAt.substring(0, 16)
                    : requestedAt,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Approval permanently deletes this account and removes its stored profile data from JourneySync.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onApprove,
                    child: Text(busy ? 'Working...' : 'Approve delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final rating = (row['rating'] ?? '-').toString();
    final note = (row['improvement_feedback'] ?? '').toString().trim();
    final created = (row['created_at'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$rating / 5',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  created.length > 10 ? created.substring(0, 10) : created,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              note.isEmpty ? 'No written note.' : note,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
