import 'package:flutter_test/flutter_test.dart';
import 'package:loan_apr_calculator/main.dart';

void main() {
  testWidgets('shows the real rate for a flat-rate offer', (tester) async {
    await tester.pumpWidget(const LoanAprApp());
    // Defaults: 1,00,000 for 12 months at 12% flat is about 21.5% a year.
    expect(find.text('Real yearly rate (APR)'), findsOneWidget);
    expect(find.textContaining('21.'), findsWidgets);
  });

  testWidgets('a second offer can be added and compared', (tester) async {
    await tester.pumpWidget(const LoanAprApp());
    await tester.tap(find.text('Compare another offer'));
    await tester.pump();
    expect(find.text('Offer B'), findsWidgets);
  });
}
