import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/services/bike_mode_service.dart';
import 'package:journeysync/widgets/bike_mode_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Bike Mode switch is compact and toggles accessibly', (
    tester,
  ) async {
    var enabled = false;
    var changes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                return BikeModeSwitch(
                  value: enabled,
                  onChanged: (value) {
                    changes += 1;
                    setState(() => enabled = value);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(BikeModeSwitch)), const Size(60, 48));
    expect(find.bySemanticsLabel('Bike Mode'), findsOneWidget);

    await tester.tap(find.byType(BikeModeSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();

    expect(changes, 1);
    expect(enabled, isTrue);
    expect(find.bySemanticsLabel('Bike Mode'), findsOneWidget);
  });

  testWidgets('Bike Mode remains on when call screening is not granted', (
    tester,
  ) async {
    const channel = MethodChannel('com.example.journeysync/bike_mode');
    final setupResult = Completer<Map<String, dynamic>>();
    final nativeStates = <bool>[];
    SharedPreferences.setMockInitialValues({'bikeModeEnabled': false});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getBikeModeState':
              return <String, dynamic>{
                'callScreeningAvailable': true,
                'callScreeningGranted': false,
                'smsGranted': false,
                'contactsGranted': false,
                'directSmsSupported': false,
                'enabled': false,
              };
            case 'setBikeModeState':
              final arguments = Map<String, dynamic>.from(
                call.arguments as Map,
              );
              nativeStates.add(arguments['enabled'] == true);
              return true;
            case 'prepareBikeMode':
              return setupResult.future;
          }
          return null;
        });

    final service = BikeModeService.instance;
    try {
      await service.initialize();
      final enabling = service.setEnabled(true);
      await tester.pump();

      expect(service.enabled, isTrue);
      expect(service.busy, isTrue);
      expect(nativeStates, contains(true));

      setupResult.complete(<String, dynamic>{
        'callScreeningAvailable': true,
        'callScreeningGranted': false,
        'smsGranted': false,
        'contactsGranted': false,
        'directSmsSupported': false,
      });
      final capability = await enabling;

      expect(capability.callScreeningGranted, isFalse);
      expect(service.enabled, isTrue);
      expect(service.busy, isFalse);
      await service.setEnabled(false);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}
