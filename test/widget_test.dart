import 'package:balance_tracker/models/balance_models.dart';
import 'package:balance_tracker/screens/balance_sheet_screen.dart';
import 'package:balance_tracker/services/balance_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Carries forward closing balance to next calendar date', () async {
    final fixedNow = DateTime(2026, 11, 25, 10, 0);
    final ctrl = BalanceController(
      initialDate: fixedNow,
      clock: () => fixedNow,
    );
    await ctrl.load();

    await ctrl.setOpeningBalance(1000);
    await ctrl.addEntry(
      money: 200,
      description: 'Lunch',
      type: EntryType.debit,
      timestamp: DateTime(2026, 11, 25, 13, 15),
    );
    await ctrl.addEntry(
      money: 500,
      description: 'Refund',
      type: EntryType.credit,
      timestamp: DateTime(2026, 11, 25, 16, 40),
    );

    expect(ctrl.currentDay.closingBalance, 1300);

    await ctrl.goToNextDay();
    expect(ctrl.currentDateKey, '2026-11-26');
    expect(ctrl.currentDay.openingBalance, 1300);
    expect(ctrl.currentDay.closingBalance, 1300);
    expect(ctrl.canEditOpeningBalance, isFalse);
    expect(ctrl.isTodayEditable, isFalse);

    // Future date should reject edits
    await ctrl.addEntry(
      money: 100,
      description: 'Blocked',
      type: EntryType.debit,
    );
    expect(ctrl.currentDay.entries, isEmpty);
  });

  testWidgets('Adds entry with time and deletes via long press',
      (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 11, 25, 10, 0);
    final ctrl = BalanceController(
      initialDate: fixedNow,
      clock: () => fixedNow,
    );
    await ctrl.load();
    await ctrl.setOpeningBalance(500);

    await tester.pumpWidget(
      MaterialApp(
        home: BalanceSheetScreen(controller: ctrl),
      ),
    );

    expect(find.text('25 Nov 2026'), findsOneWidget);

    // Add a debit entry
    await tester.enterText(find.byKey(const Key('moneyInput')), '150');
    await tester.enterText(find.byKey(const Key('descInput')), 'Coffee');
    await tester.tap(find.byKey(const Key('addEntryBtn')));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(ctrl.currentDay.closingBalance, 350);

    // Long-press the row to reveal the delete bar
    await tester.longPress(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsNothing);
    expect(ctrl.currentDay.closingBalance, 500);
  });

  testWidgets('Renders cleanly on phone (360x780) without horizontal scroll',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixedNow = DateTime(2026, 11, 25, 9, 30);
    final ctrl = BalanceController(
      initialDate: fixedNow,
      clock: () => fixedNow,
    );
    await ctrl.load();
    await ctrl.addEntry(
      money: 120,
      description: 'Morning Coffee & Breakfast',
      type: EntryType.debit,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BalanceSheetScreen(controller: ctrl),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DESC'), findsOneWidget);
    expect(find.text('C/D'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('09:30 AM'), findsOneWidget);
    expect(find.text('Morning Coffee & Breakfast'), findsOneWidget);

    // Navigate to tomorrow -> should be read-only
    await tester.tap(find.text('→'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addEntryBtn')), findsNothing);
    expect(
      find.text("View only: Only today's sheet can be edited."),
      findsOneWidget,
    );
  });
}
