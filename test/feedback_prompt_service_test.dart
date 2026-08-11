import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journeysync/services/feedback_prompt_service.dart';

void main() {
  late FeedbackPromptService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FeedbackPromptService.instance;
  });

  test('does not prompt immediately for a new user', () async {
    await service.recordHomeSession();

    expect(
      await service.shouldShowAutomaticPrompt(hasActiveRide: false),
      isFalse,
    );
  });

  test('prompts only after enough sessions and feature usage', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('feedbackPromptSessionCount', 3);

    await service.recordFeatureUse('explore');
    await service.recordFeatureUse('radar');
    await service.recordFeatureUse('create_ride');
    await service.recordFeatureUse('my_rides');
    await service.recordFeatureUse('radar');

    expect(
      await service.shouldShowAutomaticPrompt(hasActiveRide: false),
      isTrue,
    );
  });

  test('does not prompt during an active ride', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('feedbackPromptSessionCount', 3);
    await prefs.setInt('feedbackPromptFeatureUseCount', 5);
    await prefs.setStringList('feedbackPromptFeatureSet', ['radar', 'explore']);

    expect(
      await service.shouldShowAutomaticPrompt(hasActiveRide: true),
      isFalse,
    );
  });

  test('dismissal and submission prevent repeated prompts', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('feedbackPromptSessionCount', 3);
    await prefs.setInt('feedbackPromptFeatureUseCount', 5);
    await prefs.setStringList('feedbackPromptFeatureSet', ['radar', 'explore']);

    await service.markDismissed();
    expect(
      await service.shouldShowAutomaticPrompt(hasActiveRide: false),
      isFalse,
    );

    await prefs.remove('feedbackPromptLastDismissedAt');
    await service.markSubmitted();
    expect(
      await service.shouldShowAutomaticPrompt(hasActiveRide: false),
      isFalse,
    );
  });
}
