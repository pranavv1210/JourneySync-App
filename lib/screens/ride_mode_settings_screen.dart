import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/bike_mode_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialog.dart';
import '../widgets/journey_screen.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_toast.dart';

class RideModeSettingsScreen extends StatefulWidget {
  const RideModeSettingsScreen({super.key});

  @override
  State<RideModeSettingsScreen> createState() => _RideModeSettingsScreenState();
}

class _RideModeSettingsScreenState extends State<RideModeSettingsScreen> {
  BikeModeService get service => BikeModeService.instance;

  @override
  void initState() {
    super.initState();
    service.addListener(_refresh);
    unawaited(service.refreshCapability());
  }

  @override
  void dispose() {
    service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _requestAccess() async {
    final capability = await service.prepareAccess();
    if (!mounted) return;
    showPremiumToast(
      context,
      capability.callScreeningGranted
          ? 'Call rejection access is ready.'
          : 'JourneySync was not selected for call-screening access.',
      type:
          capability.callScreeningGranted
              ? PremiumToastType.success
              : PremiumToastType.warning,
    );
  }

  Future<void> _addReply() async {
    final message = await showAppInputDialog(
      context,
      title: 'Add riding reply',
      message: 'This message is sent only when automatic replies are enabled.',
      hintText: 'I’m riding right now. I’ll call you soon.',
      confirmLabel: 'Add',
      textCapitalization: TextCapitalization.sentences,
    );
    if (message == null || message.trim().isEmpty) return;
    await service.addMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final capability = service.capability;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: JourneyHeader(
                surface: true,
                leading: JourneyBackButton(),
                eyebrow: 'SAFETY & FOCUS',
                title: 'Ride Mode',
                subtitle: 'Choose how calls are handled while you ride.',
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _statusCard(),
                  const SizedBox(height: 20),
                  _sectionTitle('Permission status'),
                  PremiumCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _statusRow(
                          Icons.phone_disabled_rounded,
                          'Call rejection',
                          capability.callScreeningGranted,
                          unavailable: !capability.callScreeningAvailable,
                        ),
                        _divider(),
                        _statusRow(
                          Icons.contacts_rounded,
                          'Saved contacts',
                          capability.contactsGranted,
                        ),
                        _divider(),
                        _statusRow(
                          Icons.sms_rounded,
                          'Automatic reply',
                          capability.directSmsSupported &&
                              capability.smsGranted,
                          unavailable: !capability.directSmsSupported,
                        ),
                      ],
                    ),
                  ),
                  if (Platform.isAndroid && !capability.fullyReady) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: service.busy ? null : _requestAccess,
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label: const Text('Review Android access'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _sectionTitle('Call handling'),
                  PremiumCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _switchRow(
                          Icons.sms_outlined,
                          'Send automatic reply',
                          'Uses your selected reply after a rejected call',
                          service.sendSms,
                          capability.directSmsSupported,
                          (value) => service.updatePreferences(sendSms: value),
                        ),
                        _divider(),
                        _switchRow(
                          Icons.health_and_safety_outlined,
                          'Emergency contacts',
                          'Let your saved emergency contacts ring',
                          service.allowEmergencyContacts,
                          true,
                          (value) => service.updatePreferences(
                            allowEmergencyContacts: value,
                          ),
                        ),
                        _divider(),
                        _switchRow(
                          Icons.star_outline_rounded,
                          'Favorite contacts',
                          'Let starred Android contacts ring',
                          service.allowFavorites,
                          capability.contactsGranted,
                          (value) =>
                              service.updatePreferences(allowFavorites: value),
                        ),
                        _divider(),
                        _switchRow(
                          Icons.phone_callback_outlined,
                          'Repeat callers',
                          'Allow a second call within 3 minutes',
                          service.allowRepeatCallers,
                          true,
                          (value) => service.updatePreferences(
                            allowRepeatCallers: value,
                          ),
                        ),
                        _divider(),
                        _switchRow(
                          Icons.groups_outlined,
                          'Current ride members',
                          'Let synced group-ride members ring',
                          service.allowRideMembers,
                          true,
                          (value) => service.updatePreferences(
                            allowRideMembers: value,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Selected reply'),
                  PremiumCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...service.messages.map(
                          (message) => RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            title: Text(
                              message,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            value: message,
                            groupValue: service.selectedMessage,
                            onChanged:
                                (value) =>
                                    value == null
                                        ? null
                                        : service.selectMessage(value),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addReply,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add custom reply'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('After you stop'),
                  PremiumCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _switchRow(
                          Icons.notifications_active_outlined,
                          'Stopped reminder',
                          'Remind you after staying still',
                          service.remindWhenStopped,
                          true,
                          (value) => service.updatePreferences(
                            remindWhenStopped: value,
                          ),
                        ),
                        _divider(),
                        _switchRow(
                          Icons.timer_off_outlined,
                          'Automatic shutoff',
                          'Turn off locally and notify you after staying still',
                          service.autoTurnOff,
                          true,
                          (value) =>
                              service.updatePreferences(autoTurnOff: value),
                        ),
                        _divider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: AppColors.forest,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Stationary time',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              DropdownButton<int>(
                                value: service.stationaryMinutes,
                                underline: const SizedBox.shrink(),
                                items:
                                    const [5, 10, 15, 30]
                                        .map(
                                          (minutes) => DropdownMenuItem(
                                            value: minutes,
                                            child: Text('$minutes min'),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (value) =>
                                        value == null
                                            ? null
                                            : service.updatePreferences(
                                              stationaryMinutes: value,
                                            ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'JourneySync never uploads caller numbers. Android must approve call-screening, Contacts, and SMS access separately.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
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

  Widget _statusCard() {
    final active = service.enabled && service.capability.callScreeningGranted;
    return PremiumCard(
      color:
          active ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
      borderColor:
          active ? AppColors.primary.withValues(alpha: 0.4) : AppColors.divider,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  active
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.two_wheeler_rounded,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Ride Mode active' : 'Ride Mode is off',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.forest,
                  ),
                ),
                Text(
                  active
                      ? 'Incoming calls are being handled.'
                      : 'Calls will ring normally.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: active,
            activeColor: AppColors.primary,
            onChanged:
                service.busy ? null : (value) => service.setEnabled(value),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
    ),
  );

  Widget _divider() => const Divider(height: 1, indent: 52);

  Widget _statusRow(
    IconData icon,
    String title,
    bool ready, {
    bool unavailable = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Icon(icon, color: AppColors.forest, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Icon(
          ready ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color:
              ready
                  ? AppColors.success
                  : unavailable
                  ? AppColors.textTertiary
                  : AppColors.warning,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          ready
              ? 'Ready'
              : unavailable
              ? 'Unavailable'
              : 'Needs access',
          style: AppTypography.labelSmall.copyWith(
            color:
                ready
                    ? AppColors.success
                    : unavailable
                    ? AppColors.textTertiary
                    : AppColors.warning,
          ),
        ),
      ],
    ),
  );

  Widget _switchRow(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    bool enabled,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    child: Row(
      children: [
        Icon(icon, color: enabled ? AppColors.forest : AppColors.textTertiary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  color:
                      enabled ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: enabled && value,
          activeColor: AppColors.primary,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    ),
  );
}
