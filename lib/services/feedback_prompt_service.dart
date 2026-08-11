import 'package:shared_preferences/shared_preferences.dart';

class FeedbackPromptService {
  FeedbackPromptService._();

  static final FeedbackPromptService instance = FeedbackPromptService._();

  static const _sessionCountKey = 'feedbackPromptSessionCount';
  static const _lastSessionAtKey = 'feedbackPromptLastSessionAt';
  static const _featureUseCountKey = 'feedbackPromptFeatureUseCount';
  static const _featureSetKey = 'feedbackPromptFeatureSet';
  static const _submittedKey = 'feedbackPromptSubmitted';
  static const _lastDismissedAtKey = 'feedbackPromptLastDismissedAt';
  static const _lastPromptedAtKey = 'feedbackPromptLastPromptedAt';

  static const int minSessions = 3;
  static const int minFeatureUses = 5;
  static const int minDistinctFeatures = 2;
  static const Duration sessionGap = Duration(minutes: 30);
  static const Duration dismissCooldown = Duration(days: 7);
  static const Duration promptCooldown = Duration(days: 1);

  Future<void> recordHomeSession() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final last = DateTime.tryParse(prefs.getString(_lastSessionAtKey) ?? '');
    if (last != null && now.difference(last) < sessionGap) return;

    await prefs.setInt(
      _sessionCountKey,
      (prefs.getInt(_sessionCountKey) ?? 0) + 1,
    );
    await prefs.setString(_lastSessionAtKey, now.toIso8601String());
  }

  Future<void> recordFeatureUse(String feature) async {
    final normalized = feature.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _featureUseCountKey,
      (prefs.getInt(_featureUseCountKey) ?? 0) + 1,
    );

    final features = prefs.getStringList(_featureSetKey) ?? <String>[];
    if (!features.contains(normalized)) {
      await prefs.setStringList(_featureSetKey, [...features, normalized]);
    }
  }

  Future<bool> shouldShowAutomaticPrompt({required bool hasActiveRide}) async {
    if (hasActiveRide) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_submittedKey) == true) return false;

    final sessions = prefs.getInt(_sessionCountKey) ?? 0;
    final featureUses = prefs.getInt(_featureUseCountKey) ?? 0;
    final distinctFeatures =
        (prefs.getStringList(_featureSetKey) ?? <String>[]).length;
    if (sessions < minSessions ||
        featureUses < minFeatureUses ||
        distinctFeatures < minDistinctFeatures) {
      return false;
    }

    final now = DateTime.now();
    final lastDismissed = DateTime.tryParse(
      prefs.getString(_lastDismissedAtKey) ?? '',
    );
    if (lastDismissed != null &&
        now.difference(lastDismissed) < dismissCooldown) {
      return false;
    }

    final lastPrompted = DateTime.tryParse(
      prefs.getString(_lastPromptedAtKey) ?? '',
    );
    if (lastPrompted != null && now.difference(lastPrompted) < promptCooldown) {
      return false;
    }

    return true;
  }

  Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPromptedAtKey, DateTime.now().toIso8601String());
  }

  Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastDismissedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> markSubmitted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_submittedKey, true);
  }
}
