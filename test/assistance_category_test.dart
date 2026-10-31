import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/models/assistance_category.dart';

void main() {
  group('AssistanceCategory', () {
    test('round-trips every persisted alert message', () {
      for (final category in AssistanceCategory.values) {
        expect(
          AssistanceCategory.fromAlert({'message': category.alertMessage}),
          category,
        );
      }
    });

    test('treats legacy SOS rows as general assistance', () {
      expect(
        AssistanceCategory.fromAlert({'message': 'SOS alert triggered'}),
        AssistanceCategory.general,
      );
    });
  });
}
