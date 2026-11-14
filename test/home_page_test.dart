import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_apr_calculator/main.dart';

void main() {
  testWidgets('shows the real rate for a flat-rate offer', (tester) async {
    await tester.pumpWidget(const LoanAprApp());
    // Defaults: 1,00,000 for 12 months at 12% flat is about 21.5% a year.
    expect(find.text('Real yearly rate (APR)'), findsOneWidget);
    expect(find.textContaining('21.'), findsWidgets);
    expect(find.text('12% flat'), findsOneWidget);
  });

  testWidgets('a second offer can be added and compared', (tester) async {
    await tester.pumpWidget(const LoanAprApp());
    await tester.scrollUntilVisible(
      find.text('Compare another offer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Compare another offer'));
    await tester.pump();
    // The new card is added below, just out of view.
    expect(find.text('OFFER B', skipOffstage: false), findsOneWidget);
  });

  testWidgets('two offers at phone width: no overflow, cheaper one marked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LoanAprApp());
    await tester.tap(find.text('Compare another offer'));
    await tester.pump();
    // Two identical offers: a tie names no winner.
    expect(find.text('LOWEST REAL RATE'), findsNothing);
    // Offer B: reducing 12% instead of flat 12%.
    await tester.tap(find.text('Reducing').last);
    await tester.pump();

    expect(find.text('LOWEST REAL RATE'), findsOneWidget);
    expect(find.text('SIDE BY SIDE'), findsOneWidget);
    expect(
      find.textContaining('12.00%'),
      findsWidgets,
      reason: 'reducing 12% with no fee is exactly 12%',
    );
    expect(tester.takeException(), isNull);
  });
}
