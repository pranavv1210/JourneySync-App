import 'dart:async';
import 'package:flutter/material.dart';

import '../services/app_navigation.dart';
import '../services/ride_flow_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';
import '../widgets/journey_screen.dart';
import '../widgets/ride_flow_map_preview.dart';
import 'ride_lobby_screen.dart';

class PlanTogetherScreen extends StatefulWidget {
  const PlanTogetherScreen({super.key});

  @override
  State<PlanTogetherScreen> createState() => _PlanTogetherScreenState();
}

class _PlanTogetherScreenState extends State<PlanTogetherScreen> {
  final RideFlowService _rideFlowService = RideFlowService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _meetingController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _stopsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  double _riderLimit = 12;
  bool _publicRide = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _meetingController.dispose();
    _destinationController.dispose();
    _stopsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime get _scheduledAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _savePlan() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final meeting = _meetingController.text.trim();
    final destination = _destinationController.text.trim();
    if (name.isEmpty || meeting.isEmpty || destination.isEmpty) {
      showPremiumToast(
        context,
        'Add ride name, meeting point, and destination.',
        type: PremiumToastType.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ride = await _rideFlowService.createRide(
        title: name,
        startLocation: meeting,
        endLocation: destination,
        rideVisibility: _publicRide ? 'public' : 'private',
        rideMode: 'group',
        status: 'scheduled',
        scheduledStartTime: _scheduledAt,
        maxRiders: _riderLimit.round(),
      );
      await _rideFlowService.saveSimpleRoute(
        ride: ride,
        startLabel: meeting,
        endLabel: destination,
      );
      if (!mounted) return;
      showPremiumToast(
        context,
        'Ride plan created. Invite your crew from the lobby.',
        type: PremiumToastType.success,
      );
      unawaited(
        replaceWithAppRoute(
          context,
          RideLobbyScreen(
            rideId: ride.id,
            initialMaxRiders: _riderLimit.round(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Could not save plan: $error',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return JourneyScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JourneyHeader(
            surface: true,
            leading: JourneyBackButton(),
            eyebrow: 'GROUP PLANNER',
            title: 'Plan Together',
            subtitle:
                'Schedule a future group ride, invite riders, and keep details editable until it starts.',
          ),
          const SizedBox(height: AppSpacing.xl),
          JourneyHeroBand(
            icon: Icons.groups_rounded,
            color: AppColors.forest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build the ride before the crew arrives.',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Set the meeting point, route, schedule, visibility, and rider capacity in one plan.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const RideFlowMapPreview(
            title: 'Plan from the map',
            subtitle:
                'Use the map context while choosing meeting and destination points.',
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            elevated: true,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                _field(_nameController, 'Ride name', Icons.badge_rounded),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _pickerTile(
                        'Date',
                        '${_date.day}/${_date.month}/${_date.year}',
                        Icons.event_rounded,
                        _pickDate,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _pickerTile(
                        'Time',
                        _time.format(context),
                        Icons.schedule_rounded,
                        _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  _meetingController,
                  'Meeting point',
                  Icons.location_on_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  _destinationController,
                  'Destination',
                  Icons.flag_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  _stopsController,
                  'Optional stops',
                  Icons.alt_route_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  _descriptionController,
                  'Ride description',
                  Icons.notes_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                _plannerControls(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PremiumButton(
            label: _saving ? 'Creating plan...' : 'Create Ride Plan',
            icon: Icons.calendar_month_rounded,
            loading: _saving,
            disabled: _saving,
            onPressed: _savePlan,
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      cursorColor: AppColors.primary,
      style: AppTypography.bodyLarge.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
    );
  }

  Widget _pickerTile(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.caption),
                  Text(
                    value,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textPrimary,
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

  Widget _plannerControls() {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _publicRide,
          thumbColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.textTertiary,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary.withValues(alpha: 0.32)
                    : AppColors.divider,
          ),
          onChanged: (value) => setState(() => _publicRide = value),
          title: Text(
            _publicRide ? 'Community ride' : 'Invite-only ride',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            _publicRide
                ? 'Visible to riders when it goes live.'
                : 'Only invited riders can join.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Text('Rider limit', style: AppTypography.titleMedium),
            const Spacer(),
            Text(
              _riderLimit.round().toString(),
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        Slider(
          min: 2,
          max: 25,
          divisions: 23,
          value: _riderLimit,
          activeColor: AppColors.primary,
          onChanged: (value) => setState(() => _riderLimit = value),
        ),
      ],
    );
  }
}
