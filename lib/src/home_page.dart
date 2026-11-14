import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'loan.dart';

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
    final theme = Theme.of(context);
    final results = [for (final f in _forms) evaluate(f.toOffer())];

    // Lowest real rate among offers that have one.
    int? best;
    for (var i = 0; i < results.length; i++) {
      final apr = results[i]?.aprPercent;
      if (apr == null) continue;
      if (best == null || apr < results[best]!.aprPercent!) best = i;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Loan APR Calculator')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'A loan advertised as "10% flat" or with a processing fee '
                  'costs much more per year than 10%. Enter each offer to see '
                  'the real yearly rate. Nothing leaves this device.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _forms.length; i++) ...[
                  _OfferCard(
                    form: _forms[i],
                    isBest: best == i && results.length > 1,
                    onKind: (k) => setState(() => _forms[i].kind = k),
                    onRemove: _forms.length > 1
                        ? () => setState(() {
                              _forms.removeAt(i).dispose();
                            })
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_forms.length < 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(_add),
                      icon: const Icon(Icons.add),
                      label: const Text('Compare another offer'),
                    ),
                  ),
                const SizedBox(height: 16),
                _ResultTable(forms: _forms, results: results, best: best),
                const SizedBox(height: 12),
                Text(
                  'How it is worked out: the amount you receive (loan minus '
                  'processing fee, GST on the fee and other upfront charges) '
                  'is compared with the EMIs you pay. The yearly rate (APR) is '
                  'the monthly rate that makes them equal, times 12. '
                  'Effective annual rate adds monthly compounding. '
                  'Comparing APR is fair when the offers have a similar '
                  'amount and tenure; total cost is shown too. GST on the fee '
                  'is set at 18% by default; change it if the rate changes. '
                  'This is a calculator, not financial advice. Your lender\'s '
                  'key fact statement is the official figure.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.form,
    required this.isBest,
    required this.onKind,
    required this.onRemove,
  });

  final _Form form;
  final bool isBest;
  final ValueChanged<RateKind> onKind;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(form.label, style: theme.textTheme.titleMedium),
              if (isBest) ...[
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Lowest real rate'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
              ],
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove offer',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
            ]),
            const SizedBox(height: 8),
            SegmentedButton<RateKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: RateKind.flat, label: Text('Flat rate')),
                ButtonSegment(
                    value: RateKind.reducing, label: Text('Reducing rate')),
                ButtonSegment(value: RateKind.emiOnly, label: Text('Only EMI')),
              ],
              selected: {form.kind},
              onSelectionChanged: (s) => onKind(s.first),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _field(form.amount, 'Loan amount (₹)'),
              _field(form.months, 'Months'),
              if (form.kind == RateKind.emiOnly)
                _field(form.emi, 'Monthly EMI (₹)')
              else
                _field(form.rate, 'Rate per year (%)', decimal: true),
              _field(form.fee, 'Processing fee (%)', decimal: true),
              _field(form.gst, 'GST on fee (%)', decimal: true),
              _field(form.other, 'Other upfront (₹)'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool decimal = false}) =>
      SizedBox(
        width: 160,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]')),
          ],
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({
    required this.forms,
    required this.results,
    required this.best,
  });

  final List<_Form> forms;
  final List<LoanResult?> results;
  final int? best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String Function(LoanResult))>[
      ('Monthly EMI', (r) => _rupee.format(r.emi)),
      ('Amount you receive', (r) => _rupee.format(r.amountReceived)),
      ('Total you repay', (r) => _rupee.format(r.totalRepaid)),
      ('Total cost of the loan', (r) => _rupee.format(r.totalCost)),
      ('Real yearly rate (APR)', (r) => _pct(r.aprPercent)),
      ('Effective annual rate', (r) => _pct(r.effectiveAnnualPercent)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            columns: [
              const DataColumn(label: Text('')),
              for (var i = 0; i < forms.length; i++)
                DataColumn(
                  label: Text(forms[i].label,
                      style: TextStyle(
                          fontWeight:
                              best == i ? FontWeight.bold : FontWeight.normal)),
                ),
            ],
            rows: [
              for (final (label, fmt) in rows)
                DataRow(cells: [
                  DataCell(Text(label)),
                  for (final r in results)
                    DataCell(Text(
                      r == null ? 'Check inputs' : fmt(r),
                      style: label.startsWith('Real')
                          ? theme.textTheme.titleSmall
                          : null,
                    )),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
