import 'package:flutter/material.dart';

/// Premium empty state widget with illustrations, taglines, and subtle animations.
///
/// Provides beautiful empty states for:
/// - No Nearby Rides
/// - No Notifications
/// - No Members
/// - No Active Ride
/// - No Alerts
/// - No Routes
class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.tagline,
    this.subtitle,
    this.action,
    this.foregroundColor = const Color(0xFF1E3A2F),
    this.backgroundColor,
    this.iconSize = 80,
  });

  /// The icon to display (wrapped in a premium glass container).
  final IconData icon;

  /// The main title text.
  final String title;

  /// A short, catchy tagline.
  final String tagline;

  /// Optional secondary text.
  final String? subtitle;

  /// Optional action button.
  final Widget? action;

  /// Primary color for the state.
  final Color foregroundColor;

  /// Background color override.
  final Color? backgroundColor;

  /// Size of the icon container.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium glass icon container
            Container(
              width: iconSize + 40,
              height: iconSize + 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    foregroundColor.withValues(alpha: 0.08),
                    foregroundColor.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: foregroundColor.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: foregroundColor.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: iconSize * 0.55,
                color: foregroundColor.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            // Tagline
            Text(
              tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: foregroundColor.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            // Optional subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: foregroundColor.withValues(alpha: 0.4),
                  height: 1.3,
                ),
              ),
            ],
            // Optional action button
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }

  // ── Factory constructors for common empty states ──────────────────────────

  /// Empty state for when there are no nearby rides.
  factory PremiumEmptyState.noNearbyRides({VoidCallback? onCreateRide}) {
    return PremiumEmptyState(
      icon: Icons.radar_rounded,
      title: 'No rides nearby',
      tagline:
          'No active rides in your area right now.\nCreate one and invite '
          'riders to join you.',
      action:
          onCreateRide != null
              ? _EmptyStateAction(
                label: 'Create Ride',
                icon: Icons.add_rounded,
                onPressed: onCreateRide,
              )
              : null,
    );
  }

  /// Empty state for when there are no notifications.
  factory PremiumEmptyState.noNotifications({VoidCallback? onRefresh}) {
    return PremiumEmptyState(
      icon: Icons.notifications_active_outlined,
      title: 'All clear',
      tagline:
          'No notifications yet.\nRide invites, SOS alerts, and route '
          'changes will land here.',
      action:
          onRefresh != null
              ? _EmptyStateAction(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
              )
              : null,
    );
  }

  /// Empty state for when there are no members in a ride.
  factory PremiumEmptyState.noMembers({VoidCallback? onInvite}) {
    return PremiumEmptyState(
      icon: Icons.groups_rounded,
      title: 'No riders yet',
      tagline:
          'Your ride is empty.\nShare the access code or invite friends '
          'to join.',
      action:
          onInvite != null
              ? _EmptyStateAction(
                label: 'Invite Riders',
                icon: Icons.share_rounded,
                onPressed: onInvite,
              )
              : null,
    );
  }

  /// Empty state for when there is no active ride.
  factory PremiumEmptyState.noActiveRide({VoidCallback? onStartRide}) {
    return PremiumEmptyState(
      icon: Icons.navigation_rounded,
      title: 'No active ride',
      tagline:
          'You\'re not in a ride right now.\nStart or join a ride to '
          'begin tracking.',
      action:
          onStartRide != null
              ? _EmptyStateAction(
                label: 'Start Riding',
                icon: Icons.play_arrow_rounded,
                onPressed: onStartRide,
              )
              : null,
    );
  }

  /// Empty state for when there are no alerts.
  factory PremiumEmptyState.noAlerts() {
    return PremiumEmptyState(
      icon: Icons.shield_rounded,
      title: 'No alerts',
      tagline: 'All clear. No SOS alerts or warnings.\nYour ride is safe.',
    );
  }

  /// Empty state for when there is no route set.
  factory PremiumEmptyState.noRoute({VoidCallback? onSetRoute}) {
    return PremiumEmptyState(
      icon: Icons.route_rounded,
      title: 'No route set',
      tagline:
          'This ride doesn\'t have a route yet.\nSet a destination to '
          'guide your group.',
      action:
          onSetRoute != null
              ? _EmptyStateAction(
                label: 'Set Route',
                icon: Icons.map_rounded,
                onPressed: onSetRoute,
              )
              : null,
    );
  }
}

/// Internal action button widget for empty states.
class _EmptyStateAction extends StatelessWidget {
  const _EmptyStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A2F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
