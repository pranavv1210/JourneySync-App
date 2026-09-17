import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/widgets/bike_mode_switch.dart';

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
    expect(
      tester
          .getSemantics(find.byType(BikeModeSwitch))
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isToggled),
      isFalse,
    );

    await tester.tap(find.byType(BikeModeSwitch));
    await tester.pumpAndSettle();

    expect(changes, 1);
    expect(enabled, isTrue);
    expect(
      tester
          .getSemantics(find.byType(BikeModeSwitch))
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isToggled),
      isTrue,
    );
  });
}
