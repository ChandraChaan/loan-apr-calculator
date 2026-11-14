import 'dart:math' as math;

/// How the lender quotes the interest.
enum RateKind {
  /// Interest is charged on the full original amount for the whole tenure.
  /// Total interest = principal x rate x years.
  flat,

  /// Interest is charged on the balance still owed (the normal bank EMI).
  reducing,

  /// You are only told the monthly EMI, no rate.
  emiOnly,
}

class LoanOffer {
  const LoanOffer({
    required this.name,
    required this.principal,
    required this.months,
    required this.kind,
    this.ratePercent = 0,
    this.givenEmi = 0,
    this.processingFeePercent = 0,
    this.gstOnFeePercent = 18,
    this.otherUpfront = 0,
  });

  final String name;

  /// Loan amount you ask for and repay, in rupees.
  final double principal;
  final int months;
  final RateKind kind;

  /// Yearly rate in percent, used by [RateKind.flat] and [RateKind.reducing].
  final double ratePercent;

  /// Monthly EMI, used by [RateKind.emiOnly].
  final double givenEmi;

  /// Processing fee as a percent of [principal], taken before you get the money.
  final double processingFeePercent;

  /// Tax charged on the processing fee, in percent. Editable because the rate
  /// is set by law and can change.
  final double gstOnFeePercent;

  /// Anything else taken up front (insurance premium, documentation charge).
  final double otherUpfront;

  bool get isValid =>
      principal > 0 &&
      months > 0 &&
      ratePercent >= 0 &&
      processingFeePercent >= 0 &&
      gstOnFeePercent >= 0 &&
      otherUpfront >= 0 &&
      (kind != RateKind.emiOnly || givenEmi > 0) &&
      principal - upfrontCharges > 0;

  double get processingFee => principal * processingFeePercent / 100;
  double get gstOnFee => processingFee * gstOnFeePercent / 100;
  double get upfrontCharges => processingFee + gstOnFee + otherUpfront;
}

class LoanResult {
  const LoanResult({
    required this.emi,
    required this.totalRepaid,
    required this.upfrontCharges,
    required this.amountReceived,
    required this.totalCost,
    required this.aprPercent,
    required this.effectiveAnnualPercent,
  });

  final double emi;
  final double totalRepaid;
  final double upfrontCharges;

  /// What actually reaches your account: principal minus upfront charges.
  final double amountReceived;

  /// Everything you pay beyond the amount you receive.
  final double totalCost;

  /// Yearly rate that makes the money you receive equal to the EMIs you pay,
  /// quoted the usual way (monthly rate x 12). Null if no rate can be found.
  final double? aprPercent;

  /// Same rate with monthly compounding included: (1 + monthly)^12 - 1.
  final double? effectiveAnnualPercent;
}

double emiReducing(double principal, double yearlyPercent, int months) {
  final i = yearlyPercent / 1200;
  if (i == 0) return principal / months;
  final f = math.pow(1 + i, months);
  return principal * i * f / (f - 1);
}

double emiFlat(double principal, double yearlyPercent, int months) {
  final interest = principal * yearlyPercent / 100 * months / 12;
  return (principal + interest) / months;
}

/// Monthly rate at which [emi] paid for [months] months is worth [received]
/// today, or null if there is none (the EMIs add up to less than [received]).
double? monthlyRateFor(double received, double emi, int months) {
  if (emi * months < received) return null;
  double pv(double i) {
    if (i == 0) return emi * months;
    return emi * (1 - math.pow(1 + i, -months)) / i;
  }

  // pv() falls as the rate rises, so bisect.
  var lo = 0.0;
  var hi = 1.0; // 100% per month is far beyond any real loan
  for (var k = 0; k < 200; k++) {
    final mid = (lo + hi) / 2;
    if (pv(mid) > received) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

LoanResult? evaluate(LoanOffer o) {
  if (!o.isValid) return null;
  final emi = switch (o.kind) {
    RateKind.flat => emiFlat(o.principal, o.ratePercent, o.months),
    RateKind.reducing => emiReducing(o.principal, o.ratePercent, o.months),
    RateKind.emiOnly => o.givenEmi,
  };
  final received = o.principal - o.upfrontCharges;
  final total = emi * o.months;
  final i = monthlyRateFor(received, emi, o.months);
  return LoanResult(
    emi: emi,
    totalRepaid: total,
    upfrontCharges: o.upfrontCharges,
    amountReceived: received,
    totalCost: total - received,
    aprPercent: i == null ? null : i * 1200,
    effectiveAnnualPercent:
        i == null ? null : (math.pow(1 + i, 12) - 1) * 100,
  );
}
