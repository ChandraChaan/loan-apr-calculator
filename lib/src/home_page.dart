import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'loan.dart';
import 'look.dart';

final _rupee = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String _pct(double? v) => v == null ? 'n/a' : '${v.toStringAsFixed(2)}%';

class _Form {
  _Form(this.label) {
    for (final c in [amount, months, rate, emi, fee, gst, other]) {
      c.addListener(onChange);
    }
  }

  final String label;
  VoidCallback onChange = () {};
  RateKind kind = RateKind.flat;

  final amount = TextEditingController(text: '100000');
  final months = TextEditingController(text: '12');
  final rate = TextEditingController(text: '12');
  final emi = TextEditingController();
  final fee = TextEditingController(text: '0');
  final gst = TextEditingController(text: '18');
  final other = TextEditingController(text: '0');

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  LoanOffer toOffer() => LoanOffer(
    name: label,
    principal: _d(amount),
    months: int.tryParse(months.text.trim()) ?? 0,
    kind: kind,
    ratePercent: _d(rate),
    givenEmi: _d(emi),
    processingFeePercent: _d(fee),
    gstOnFeePercent: _d(gst),
    otherUpfront: _d(other),
  );

  /// What the lender tells you, in their words.
  String get theySay {
    final o = toOffer();
    final fee = o.processingFeePercent > 0
        ? ' + ${o.processingFeePercent.toStringAsFixed(o.processingFeePercent % 1 == 0 ? 0 : 1)}% fee'
        : '';
    return switch (kind) {
      RateKind.flat => '${_trim(o.ratePercent)}% flat$fee',
      RateKind.reducing => '${_trim(o.ratePercent)}% a year$fee',
      RateKind.emiOnly =>
        o.givenEmi > 0
            ? '${_rupee.format(o.givenEmi)} a month$fee'
            : 'Only the EMI',
    };
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void dispose() {
    for (final c in [amount, months, rate, emi, fee, gst, other]) {
      c.dispose();
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<_Form> _forms = [];

  @override
  void initState() {
    super.initState();
    _add();
  }

  @override
  void dispose() {
    for (final f in _forms) {
      f.dispose();
    }
    super.dispose();
  }

  void _add() {
    final f = _Form('Offer ${String.fromCharCode(65 + _forms.length)}');
    f.onChange = () => setState(() {});
    _forms.add(f);
  }

  @override
  Widget build(BuildContext context) {
    final l = Look.of(context);
    final results = [for (final f in _forms) evaluate(f.toOffer())];

    int? best;
    for (var i = 0; i < results.length; i++) {
      final apr = results[i]?.aprPercent;
      if (apr == null) continue;
      if (best == null || apr < results[best]!.aprPercent!) best = i;
    }
    // A tie (to a hundredth of a percent) has no winner.
    if (best != null) {
      final b = results[best]!.aprPercent!;
      final tied = [
        for (final r in results)
          if (r?.aprPercent != null && (r!.aprPercent! - b).abs() < 0.005) r,
      ].length;
      if (tied > 1) best = null;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                Text('LOAN CHECK', style: l.label()),
                const SizedBox(height: 2),
                Text(
                  'What does this loan really cost?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: l.ink,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '"10% flat" and a "small processing fee" cost much more than 10% a year. '
                  'Type the offer the way the lender said it.',
                  style: TextStyle(color: l.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _forms.length; i++) ...[
                  _OfferPage(
                    form: _forms[i],
                    result: results[i],
                    isBest: best == i && results.length > 1,
                    onKind: (k) => setState(() => _forms[i].kind = k),
                    onRemove: _forms.length > 1
                        ? () => setState(() => _forms.removeAt(i).dispose())
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_forms.length < 3)
                  OutlinedButton.icon(
                    onPressed: () => setState(_add),
                    icon: const Icon(Icons.add),
                    label: const Text('Compare another offer'),
                  ),
                if (_forms.length > 1) ...[
                  const SizedBox(height: 22),
                  Text('SIDE BY SIDE', style: l.label()),
                  const SizedBox(height: 10),
                  _Bars(forms: _forms, results: results, best: best),
                ],
                const SizedBox(height: 22),
                Text(
                  'How it is worked out: the money that reaches you (loan minus processing fee, GST on the fee '
                  'and other upfront charges) is set against the EMIs you pay. The real yearly rate is the monthly '
                  'rate that makes them equal, times 12; effective annual adds monthly compounding. GST on the fee '
                  'is 18% by default, change it if the rate changes. This is a calculator, not financial advice; '
                  'your lender\'s key fact statement is the official figure.',
                  style: TextStyle(color: l.muted, fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One offer as a passbook page: what they say, what it really is, and the ledger.
class _OfferPage extends StatelessWidget {
  const _OfferPage({
    required this.form,
    required this.result,
    required this.isBest,
    required this.onKind,
    required this.onRemove,
  });

  final _Form form;
  final LoanResult? result;
  final bool isBest;
  final ValueChanged<RateKind> onKind;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = Look.of(context);
    final r = result;
    final quoted = form.kind == RateKind.emiOnly
        ? null
        : form.toOffer().ratePercent;
    // Red when the real rate is well above what was quoted (or when only an EMI was given).
    final shock =
        r?.aprPercent != null &&
        (quoted == null || r!.aprPercent! > quoted + 1);

    return Container(
      decoration: BoxDecoration(
        color: l.page,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isBest ? l.good : l.rule,
          width: isBest ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The reveal.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: l.rule)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          Text(form.label.toUpperCase(), style: l.label()),
                          if (isBest)
                            Text(
                              'LOWEST REAL RATE',
                              style: l.label().copyWith(color: l.good),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'They say',
                        style: TextStyle(color: l.muted, fontSize: 12),
                      ),
                      Text(
                        form.theySay,
                        style: TextStyle(
                          color: l.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          decoration: shock ? TextDecoration.lineThrough : null,
                          decorationColor: l.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Real yearly rate (APR)',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: l.muted, fontSize: 12),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          r == null ? 'Check inputs' : _pct(r.aprPercent),
                          style: TextStyle(
                            color: r == null
                                ? l.muted
                                : (shock ? l.red : l.ink),
                            fontSize: r == null ? 15 : 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            fontFeatures: Look.figures,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove offer',
                    onPressed: onRemove,
                    icon: Icon(Icons.close, color: l.muted, size: 20),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<RateKind>(
                  showSelectedIcon: false,
                  // Labels shrink rather than overflow with large system text.
                  segments: const [
                    ButtonSegment(
                      value: RateKind.flat,
                      label: FittedBox(child: Text('Flat')),
                    ),
                    ButtonSegment(
                      value: RateKind.reducing,
                      label: FittedBox(child: Text('Reducing')),
                    ),
                    ButtonSegment(
                      value: RateKind.emiOnly,
                      label: FittedBox(child: Text('Only EMI')),
                    ),
                  ],
                  selected: {form.kind},
                  onSelectionChanged: (s) => onKind(s.first),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _field(form.amount, 'Loan amount ₹'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: _field(form.months, 'Months')),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: form.kind == RateKind.emiOnly
                          ? _field(form.emi, 'EMI ₹')
                          : _field(form.rate, 'Rate % a year', decimal: true),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        form.fee,
                        'Processing fee %',
                        decimal: true,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _field(form.gst, 'GST on fee %', decimal: true),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: _field(form.other, 'Other upfront ₹')),
                  ],
                ),
              ],
            ),
          ),
          if (r != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: l.rule)),
              ),
              child: Column(
                children: [
                  _ledger(l, 'Monthly EMI', _rupee.format(r.emi)),
                  _ledger(
                    l,
                    'Reaches your account',
                    _rupee.format(r.amountReceived),
                  ),
                  _ledger(
                    l,
                    'You pay back in all',
                    _rupee.format(r.totalRepaid),
                  ),
                  _ledger(
                    l,
                    'Cost of this loan',
                    _rupee.format(r.totalCost),
                    strong: true,
                  ),
                  _ledger(
                    l,
                    'Effective annual rate',
                    _pct(r.effectiveAnnualPercent),
                    last: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _ledger(
    Look l,
    String label,
    String value, {
    bool strong = false,
    bool last = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      border: last
          ? null
          : Border(bottom: BorderSide(color: l.rule.withValues(alpha: 0.7))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? l.ink : l.muted,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: l.ink,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            fontSize: strong ? 16 : 14,
            fontFeatures: Look.figures,
          ),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController c,
    String label, {
    bool decimal = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      style: const TextStyle(
        fontFeatures: Look.figures,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(labelText: label),
    ),
  );
}

/// Real yearly rate per offer as bars, so the gap is visible at a glance.
class _Bars extends StatelessWidget {
  const _Bars({required this.forms, required this.results, required this.best});

  final List<_Form> forms;
  final List<LoanResult?> results;
  final int? best;

  @override
  Widget build(BuildContext context) {
    final l = Look.of(context);
    final aprs = [for (final r in results) r?.aprPercent ?? 0.0];
    final top = aprs.fold<double>(0, (a, b) => b > a ? b : a);
    return Column(
      children: [
        for (var i = 0; i < forms.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    forms[i].label,
                    style: TextStyle(fontWeight: FontWeight.w700, color: l.ink),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final r = results[i];
                      final frac = top <= 0 || r?.aprPercent == null
                          ? 0.0
                          : (r!.aprPercent! / top).clamp(0.04, 1.0);
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 26,
                            color: l.rule.withValues(alpha: 0.5),
                          ),
                          Container(
                            height: 26,
                            width: box.maxWidth * frac,
                            color: i == best
                                ? l.good
                                : l.ink.withValues(alpha: 0.75),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              r == null
                                  ? 'check inputs'
                                  : '${_pct(r.aprPercent)}  ·  costs ${_rupee.format(r.totalCost)}',
                              style: TextStyle(
                                color: l.page,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                fontFeatures: Look.figures,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
