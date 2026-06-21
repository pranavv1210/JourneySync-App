import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../coordinators/notification_coordinator.dart';
import '../models/app_notification.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/ride_loading_indicator.dart';
import '../theme/app_theme.dart';

/// Premium notification center with glassmorphism design.
///
/// Features:
/// - Unread badge counter
/// - Notification cards with icons, timestamps, categories
/// - Read/unread state
/// - Clear all / Mark all read
/// - Glassmorphism cards with smooth animations
/// - Category-based visual styling
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationCoordinator _coordinator = NotificationCoordinator.instance;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = (prefs.getString('userId') ?? '').trim();
    if (profileId.isNotEmpty) {
      await _coordinator.start(profileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFEA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          AnimatedBuilder(
            animation: _coordinator,
            builder: (context, _) {
              if (_coordinator.notifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  if (value == 'read') _coordinator.markAllRead();
                  if (value == 'clear') _coordinator.clearAll();
                },
                itemBuilder:
                    (context) => const [
                      PopupMenuItem(
                        value: 'read',
                        child: Text('Mark all read'),
                      ),
                      PopupMenuItem(value: 'clear', child: Text('Clear all')),
                    ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _coordinator,
          builder: (context, _) {
            if (_coordinator.loading && _coordinator.notifications.isEmpty) {
              return const Center(
                child: RideLoadingIndicator(label: 'Syncing alerts'),
              );
            }
            if (_coordinator.notifications.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: _coordinator.refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: _coordinator.notifications.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _NotificationSummary(
                      unreadCount: _coordinator.unreadCount,
                      totalCount: _coordinator.notifications.length,
                    );
                  }
                  final item = _coordinator.notifications[index - 1];
                  return _NotificationCard(notification: item);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium illustration container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFFF4EFEA), const Color(0xFFE8E0D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                size: 48,
                color: const Color(0xFF1E3A2F).withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All clear',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E3A2F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No notifications yet.\nRide invites, SOS alerts, route changes, and weather updates will land here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E3A2F).withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Refresh',
              expand: false,
              size: AppButtonSize.small,
              onPressed: _coordinator.refresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.unreadCount,
    required this.totalCount,
  });

  final int unreadCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Premium glass icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E3A2F), const Color(0xFF2D5A4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A2F).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ride signal center',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF1E3A2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unreadCount unread of $totalCount total',
                  style: TextStyle(
                    color: const Color(0xFF1E3A2F).withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            label: 'Read',
            size: AppButtonSize.small,
            expand: false,
            variant: AppButtonVariant.glass,
            onPressed: NotificationCoordinator.instance.markAllRead,
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final spec = _NotificationSpec.fromCategory(notification.category);
    final isUnread = !notification.read;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isUnread
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isUnread
                  ? spec.color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: isUnread ? 0.06 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category icon with glass background
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  spec.color.withValues(alpha: 0.15),
                  spec.color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: spec.color.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(spec.icon, color: spec.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: const Color(0xFF1E3A2F),
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: spec.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: spec.color.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notification.body,
                  style: TextStyle(
                    color: const Color(0xFF1E3A2F).withValues(alpha: 0.62),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      _relativeTime(notification.createdAt),
                      style: TextStyle(
                        color: const Color(0xFF1E3A2F).withValues(alpha: 0.42),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    // Category label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: spec.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _categoryLabel(notification.category),
                        style: TextStyle(
                          color: spec.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
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
    );
  }

  String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String _categoryLabel(AppNotificationCategory category) {
    return switch (category) {
      AppNotificationCategory.sos => 'SOS',
      AppNotificationCategory.rideStarted => 'Started',
      AppNotificationCategory.rideEnded => 'Ended',
      AppNotificationCategory.routeChanged => 'Route',
      AppNotificationCategory.memberJoined => 'Joined',
      AppNotificationCategory.memberLeft => 'Left',
      AppNotificationCategory.invitation => 'Invite',
      AppNotificationCategory.nearbyRide => 'Nearby',
      AppNotificationCategory.weather => 'Weather',
      AppNotificationCategory.system => 'System',
    };
  }
}

class _NotificationSpec {
  const _NotificationSpec({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  factory _NotificationSpec.fromCategory(AppNotificationCategory category) {
    return switch (category) {
      AppNotificationCategory.sos => const _NotificationSpec(
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFE11D48),
      ),
      AppNotificationCategory.rideStarted => const _NotificationSpec(
        icon: Icons.play_circle_rounded,
        color: Color(0xFF16A34A),
      ),
      AppNotificationCategory.rideEnded => const _NotificationSpec(
        icon: Icons.flag_rounded,
        color: Color(0xFF6B7280),
      ),
      AppNotificationCategory.routeChanged => const _NotificationSpec(
        icon: Icons.route_rounded,
        color: Color(0xFF2563EB),
      ),
      AppNotificationCategory.memberJoined ||
      AppNotificationCategory.memberLeft => const _NotificationSpec(
        icon: Icons.groups_rounded,
        color: Color(0xFF16A34A),
      ),
      AppNotificationCategory.invitation => const _NotificationSpec(
        icon: Icons.mail_rounded,
        color: Color(0xFF8B5CF6),
      ),
      AppNotificationCategory.nearbyRide => const _NotificationSpec(
        icon: Icons.radar_rounded,
        color: Color(0xFFFF6A00),
      ),
      AppNotificationCategory.weather => const _NotificationSpec(
        icon: Icons.thunderstorm_rounded,
        color: Color(0xFF0EA5E9),
      ),
      AppNotificationCategory.system => const _NotificationSpec(
        icon: Icons.settings_rounded,
        color: Color(0xFF111111),
      ),
    };
  }
}
