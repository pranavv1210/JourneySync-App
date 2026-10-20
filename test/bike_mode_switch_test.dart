import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/services/bike_mode_service.dart';
import 'package:journeysync/widgets/bike_mode_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Ride Mode switch is compact and toggles accessibly', (
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
    expect(find.bySemanticsLabel('Ride Mode'), findsOneWidget);

    await tester.tap(find.byType(BikeModeSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();

    expect(changes, 1);
    expect(enabled, isTrue);
    expect(find.bySemanticsLabel('Ride Mode'), findsOneWidget);
  });

  testWidgets('Ride Mode returns off when call screening is not granted', (
    tester,
  ) async {
    const channel = MethodChannel('com.example.journeysync/bike_mode');
    var setupResult = Completer<Map<String, dynamic>>();
    final nativeStates = <bool>[];
    final nativeArguments = <Map<String, dynamic>>[];
    var openedCallerIdSettings = false;
    var clearedNativeState = false;
    SharedPreferences.setMockInitialValues({
      'bikeModeEnabled': false,
      'rideModeAllowEmergency': true,
      'rideModeAllowFavorites': true,
      'rideModeAllowRepeatCallers': true,
      'rideModeAllowRideMembers': true,
    });
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
                'lastScreenedAt': 1700000000000,
                'lastScreenedAction': 'allowed',
                'lastScreenedReason': 'favorite_contact',
              };
            case 'setBikeModeState':
              final arguments = Map<String, dynamic>.from(
                call.arguments as Map,
              );
              nativeArguments.add(arguments);
              nativeStates.add(arguments['enabled'] == true);
              return true;
            case 'prepareBikeMode':
              return setupResult.future;
            case 'openCallerIdSettings':
              openedCallerIdSettings = true;
              return true;
            case 'clearBikeModeState':
              clearedNativeState = true;
              return true;
          }
          return null;
        });

    final service = BikeModeService.instance;
    try {
      await service.initialize();
      expect(service.lastScreenedAt, isNotNull);
      expect(service.lastScreenedAction, 'allowed');
      expect(service.lastScreenedReason, 'favorite_contact');
      expect(service.allowEmergencyContacts, isFalse);
      expect(service.allowFavorites, isFalse);
      expect(service.allowRepeatCallers, isFalse);
      expect(service.allowRideMembers, isFalse);
      final enabling = service.setEnabled(true);
      await tester.pump();

      expect(service.enabled, isFalse);
      expect(service.busy, isTrue);
      expect(nativeStates, isNot(contains(true)));

      setupResult.complete(<String, dynamic>{
        'callScreeningAvailable': true,
        'callScreeningGranted': false,
        'smsGranted': false,
        'contactsGranted': false,
        'directSmsSupported': false,
      });
      final capability = await enabling;

      expect(capability.callScreeningGranted, isFalse);
      expect(service.enabled, isFalse);
      expect(service.busy, isFalse);
      expect(await service.openCallerIdSettings(), isTrue);
      expect(openedCallerIdSettings, isTrue);

      setupResult = Completer<Map<String, dynamic>>();
      final granted = service.setEnabled(true);
      setupResult.complete(<String, dynamic>{
        'callScreeningAvailable': true,
        'callScreeningGranted': true,
        'smsGranted': true,
        'contactsGranted': true,
        'directSmsSupported': true,
      });
      await granted;
      expect(service.enabled, isTrue);
      expect(nativeStates.last, isTrue);

      await service.updatePreferences(
        allowRepeatCallers: false,
        autoTurnOff: true,
        stationaryMinutes: 15,
        restoreCallerIdAfterRide: false,
      );
      expect(service.allowRepeatCallers, isFalse);
      expect(service.autoTurnOff, isTrue);
      expect(service.stationaryMinutes, 15);
      expect(service.restoreCallerIdAfterRide, isFalse);
      expect(nativeArguments.last['allowRepeatCallers'], isFalse);
      expect(nativeArguments.last['autoTurnOff'], isTrue);
      expect(nativeArguments.last['stationaryMinutes'], 15);
      await service.setEnabled(false);
      await service.clearForSignOut();
      final clearedPrefs = await SharedPreferences.getInstance();
      expect(clearedPrefs.getBool('bikeModeEnabled'), isNull);
      expect(clearedPrefs.getStringList('bikeModeMessages'), isNull);
      expect(clearedNativeState, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}
