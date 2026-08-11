import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_version.dart';
import '../services/feedback_prompt_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';

Future<bool?> showJourneySyncFeedbackSheet(BuildContext context) {
  return showAppBottomSheet<bool>(
    context,
    builder: (_) => const _FeedbackSheet(),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _feedbackController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  int _rating = 0;
  bool _submitting = false;
  bool _submitted = false;
  String _error = '';

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await FeedbackPromptService.instance.markDismissed();
    if (!mounted) return;
    Navigator.pop(context, false);
  }

  Future<void> _submit() async {
    if (_rating == 0 || _submitting || _submitted) return;

    setState(() {
      _submitting = true;
      _error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = (prefs.getString('userId') ?? '').trim();
      final authUserId =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      final userId = authUserId.isNotEmpty ? authUserId : cachedUserId;

      await _supabaseService.submitFeedback(
        userId: userId,
        rating: _rating,
        improvementFeedback: _feedbackController.text,
        appVersion: AppVersion.label,
        platform: Platform.operatingSystem,
      );
      await FeedbackPromptService.instance.markSubmitted();

      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
      });

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) Navigator.pop(context, true);
        }),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not send feedback. Try again in a moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget withKeyboardInset(Widget child) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: child,
      );
    }

    if (_submitted) {
      return withKeyboardInset(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Thanks for riding with us ❤️',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.forest,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your feedback helps us build JourneySync better.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      );
    }

    return withKeyboardInset(
      PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && !_submitted) {
            unawaited(FeedbackPromptService.instance.markDismissed());
          }
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'How are you liking JourneySync?',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _submitting ? null : _dismiss,
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your feedback helps us make it better.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Semantics(
                  label: 'Star rating',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      final selected = value <= _rating;
                      return IconButton(
                        tooltip: '$value star${value == 1 ? '' : 's'}',
                        onPressed:
                            _submitting
                                ? null
                                : () => setState(() => _rating = value),
                        icon: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color:
                              selected
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _feedbackController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'What can we improve?',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Submit',
                icon: Icons.arrow_forward_rounded,
                loading: _submitting,
                disabled: _rating == 0,
                onPressed: _rating == 0 ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _submitting ? null : _dismiss,
                  child: Text(
                    'Maybe later',
                    style: AppTypography.buttonMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
