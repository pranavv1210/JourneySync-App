enum AssistanceCategory {
  medical(
    label: 'Accident / Medical Emergency',
    alertMessage: 'Accident or medical emergency',
  ),
  breakdown(
    label: 'Motorcycle Breakdown',
    alertMessage: 'Motorcycle breakdown assistance needed',
  ),
  separated(
    label: 'Separated from Group',
    alertMessage: 'Separated from the riding group',
  ),
  general(
    label: 'General Assistance',
    alertMessage: 'General assistance needed',
  );

  const AssistanceCategory({required this.label, required this.alertMessage});

  final String label;
  final String alertMessage;

  static AssistanceCategory fromAlert(Map<String, dynamic>? alert) {
    final message = (alert?['message'] ?? '').toString().toLowerCase();
    return values.firstWhere(
      (category) => message.contains(category.alertMessage.toLowerCase()),
      orElse: () => AssistanceCategory.general,
    );
  }
}
