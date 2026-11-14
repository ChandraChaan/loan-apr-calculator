import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loan_apr_calculator/src/loan.dart';

LoanOffer offer({
  RateKind kind = RateKind.reducing,
  double principal = 100000,
  int months = 12,
  double rate = 12,
  double emi = 0,
  double fee = 0,
  double gst = 18,
  double other = 0,
}) => LoanOffer(
  name: 't',
  principal: principal,
  months: months,
  kind: kind,
  ratePercent: rate,
  givenEmi: emi,
  processingFeePercent: fee,
  gstOnFeePercent: gst,
  otherUpfront: other,
);

void main() {
  test('reducing EMI matches the standard formula value', () {
    // 1,00,000 at 12% for 12 months is a well known 8,884.88 EMI.
    expect(emiReducing(100000, 12, 12), closeTo(8884.88, 0.01));
  });

  test('reducing loan with no fees has APR equal to the quoted rate', () {
    final r = evaluate(offer(rate: 12))!;
    expect(r.aprPercent, closeTo(12, 1e-6));
    expect(r.effectiveAnnualPercent, closeTo(12.6825, 0.001));
    expect(r.totalCost, closeTo(r.emi * 12 - 100000, 1e-6));
  });

  test('zero rate reducing loan costs nothing', () {
    final r = evaluate(offer(rate: 0))!;
    expect(r.emi, closeTo(100000 / 12, 1e-9));
    expect(r.aprPercent, closeTo(0, 1e-9));
  });

  test('flat rate is much more expensive than the same reducing rate', () {
    final flat = evaluate(offer(kind: RateKind.flat, rate: 10))!;
    final reducing = evaluate(offer(rate: 10))!;
    expect(flat.emi, closeTo(110000 / 12, 1e-9));
    // 10% flat over 12 months is about 18% a year on the real balance.
    expect(flat.aprPercent, inInclusiveRange(17.5, 18.5));
    expect(flat.aprPercent!, greaterThan(reducing.aprPercent! * 1.5));
  });

  test(
    'IRR is self consistent: EMIs discounted at the APR give back the cash',
    () {
      final o = offer(
        kind: RateKind.flat,
        rate: 14,
        months: 24,
        fee: 2,
        other: 500,
      );
      final r = evaluate(o)!;
      final i = r.aprPercent! / 1200;
      var pv = 0.0;
      for (var m = 1; m <= 24; m++) {
        pv += r.emi / math.pow(1 + i, m);
      }
      expect(pv, closeTo(r.amountReceived, 0.01));
    },
  );

  test('processing fee with GST raises the APR and lowers cash received', () {
    final plain = evaluate(offer(rate: 12))!;
    final withFee = evaluate(offer(rate: 12, fee: 2))!;
    expect(withFee.upfrontCharges, closeTo(2000 + 360, 1e-9));
    expect(withFee.amountReceived, closeTo(100000 - 2360, 1e-9));
    expect(withFee.aprPercent!, greaterThan(plain.aprPercent!));
  });

  test('EMI-only offer: rate is worked out from the EMI alone', () {
    // Pay 9,000 x 12 for 1,00,000 received: a bit over 14% a year.
    final r = evaluate(offer(kind: RateKind.emiOnly, emi: 9000))!;
    expect(r.totalRepaid, 108000);
    expect(r.totalCost, 8000);
    expect(r.aprPercent, inInclusiveRange(14, 15));
  });

  test('EMIs that add up to less than the cash received give no rate', () {
    final r = evaluate(offer(kind: RateKind.emiOnly, emi: 8000))!;
    expect(r.aprPercent, isNull);
  });

  test('invalid offers are rejected', () {
    expect(evaluate(offer(principal: 0)), isNull);
    expect(evaluate(offer(months: 0)), isNull);
    expect(evaluate(offer(kind: RateKind.emiOnly, emi: 0)), isNull);
    expect(
      evaluate(offer(other: 100000)),
      isNull,
      reason: 'charges equal to the whole loan leave nothing received',
    );
  });
}
