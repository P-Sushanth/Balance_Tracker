import 'package:flutter/material.dart';

import '../models/balance_models.dart';
import '../services/balance_controller.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({
    super.key,
    required this.controller,
  });

  final BalanceController controller;

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  static const _borderColor = Color(0xFFCBD5E1);
  static const _borderDark = Color(0xFF94A3B8);
  static const _headerBg = Color(0xFFE2E8F0);
  static const _rowAltBg = Color(0xFFF8FAFC);
  static const _creditColor = Color(0xFF15803D);
  static const _debitColor = Color(0xFFB91C1C);

  final _openingController = TextEditingController();
  final _moneyController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  EntryType _selectedType = EntryType.debit;
  int? _selectedDeleteIdx;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncOpeningField);
    _syncOpeningField();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncOpeningField);
    _openingController.dispose();
    _moneyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _syncOpeningField() {
    final value = widget.controller.currentDay.openingBalance;
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    if (_openingController.text != formatted) {
      _openingController.text = formatted;
    }
  }

  String _fmtCurrency(double amount) => '₹${amount.toStringAsFixed(2)}';

  Future<void> _pickDate() async {
    final start = parseDateKey(widget.controller.startDateKey);
    final current = parseDateKey(widget.controller.currentDateKey);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: start,
      lastDate: DateTime(start.year + 5),
    );
    if (picked != null) {
      setState(() => _selectedDeleteIdx = null);
      await widget.controller.goToDate(toDateKey(picked));
    }
  }

  Future<void> _submitEntry() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final money = double.tryParse(_moneyController.text.trim());
    final desc = _descController.text.trim();
    if (money == null || money <= 0 || desc.isEmpty) return;

    await widget.controller.addEntry(
      money: money,
      description: desc,
      type: _selectedType,
    );
    _moneyController.clear();
    _descController.clear();
    setState(() => _selectedDeleteIdx = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final day = ctrl.currentDay;
        final nextDateKey = addDaysToKey(ctrl.currentDateKey, 1);

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F9),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final isPhone = viewport.maxWidth < 600;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Container(
                      margin: isPhone
                          ? EdgeInsets.zero
                          : const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: isPhone
                            ? null
                            : Border.all(color: _borderDark, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBar(ctrl, isPhone: isPhone),
                          _buildSummaryStrip(ctrl, day),
                          Expanded(child: _buildSheet(ctrl, day, isPhone: isPhone)),
                          if (ctrl.isTodayEditable &&
                              _selectedDeleteIdx != null &&
                              _selectedDeleteIdx! < day.entries.length)
                            _buildDeleteBar(
                                ctrl, day.entries[_selectedDeleteIdx!]),
                          if (ctrl.isTodayEditable)
                            _buildAddRow(isPhone: isPhone)
                          else
                            _buildReadOnlyBanner(),
                          _buildFooterBar(ctrl, day, nextDateKey,
                              isPhone: isPhone),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BalanceController ctrl, {required bool isPhone}) {
    final isAtStart = ctrl.currentDateKey == ctrl.startDateKey;
    final dateNav = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 10 : 14,
              vertical: isPhone ? 8 : 10,
            ),
          ),
          onPressed: isAtStart
              ? null
              : () {
                  setState(() => _selectedDeleteIdx = null);
                  ctrl.goToPreviousDay();
                },
          child: Text(isPhone ? '←' : '← Prev'),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: InkWell(
            onTap: _pickDate,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isPhone ? 10 : 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _borderDark, width: 1.5),
              ),
              child: Text(
                formatDisplayDate(ctrl.currentDateKey),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isPhone ? 13 : 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 10 : 14,
              vertical: isPhone ? 8 : 10,
            ),
          ),
          onPressed: () {
            setState(() => _selectedDeleteIdx = null);
            ctrl.goToNextDay();
          },
          child: Text(isPhone ? '→' : 'Next →'),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 16,
        vertical: isPhone ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(bottom: BorderSide(color: _borderDark, width: 2)),
      ),
      child: isPhone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'BALANCE TRACKER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: dateNav),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BALANCE TRACKER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                dateNav,
              ],
            ),
    );
  }

  Widget _buildSummaryStrip(BalanceController ctrl, DayRecord day) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        final cells = [
          _summaryCell(
            label: 'OPENING BALANCE',
            child: ctrl.canEditOpeningBalance
                ? SizedBox(
                    height: 36,
                    child: TextField(
                      key: const Key('openingBalanceField'),
                      controller: _openingController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val.trim()) ?? 0;
                        ctrl.setOpeningBalance(parsed);
                      },
                    ),
                  )
                : Text(
                    _fmtCurrency(day.openingBalance),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          _summaryCell(
            label: 'TOTAL CREDIT (+)',
            child: Text(
              _fmtCurrency(day.totalCredit),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _creditColor,
              ),
            ),
          ),
          _summaryCell(
            label: 'TOTAL DEBIT (-)',
            child: Text(
              _fmtCurrency(day.totalDebit),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _debitColor,
              ),
            ),
          ),
          _summaryCell(
            label: 'CLOSING BALANCE',
            isLast: true,
            child: Text(
              _fmtCurrency(day.closingBalance),
              key: const Key('closingBalanceText'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ];

        if (isCompact) {
          return Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _borderDark, width: 2)),
            ),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: cells[0]),
                  Expanded(child: cells[1]),
                ]),
                const Divider(height: 1, color: _borderColor),
                Row(children: [
                  Expanded(child: cells[2]),
                  Expanded(child: cells[3]),
                ]),
              ],
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _borderDark, width: 2)),
          ),
          child: Row(
            children: cells.map((c) => Expanded(child: c)).toList(),
          ),
        );
      },
    );
  }

  Widget _summaryCell({
    required String label,
    required Widget child,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(right: BorderSide(color: _borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Widget _buildSheet(
    BalanceController ctrl,
    DayRecord day, {
    required bool isPhone,
  }) {
    final snoW = isPhone ? 34.0 : 56.0;
    final moneyW = isPhone ? 84.0 : 120.0;
    final typeW = isPhone ? 40.0 : 56.0;
    final timeW = isPhone ? 68.0 : 90.0;

    return Column(
      children: [
        // Header Row
        Container(
          color: _headerBg,
          child: Row(
            children: [
              _HeaderCell('#', width: snoW, align: TextAlign.center, compact: isPhone),
              _HeaderCell('MONEY', width: moneyW, compact: isPhone),
              Expanded(child: _HeaderCell('DESC', compact: isPhone)),
              _HeaderCell('C/D', width: typeW, align: TextAlign.center, compact: isPhone),
              _HeaderCell('TIME', width: timeW, isLast: true, compact: isPhone),
            ],
          ),
        ),
        const Divider(height: 2, thickness: 2, color: _borderDark),
        Expanded(
          child: day.entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      ctrl.isTodayEditable
                          ? 'No entries for today yet. Add one below.'
                          : 'No entries recorded for this date.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: day.entries.length,
                  itemBuilder: (context, index) {
                    final entry = day.entries[index];
                    final isSelected =
                        ctrl.isTodayEditable && _selectedDeleteIdx == index;
                    final isCredit = entry.type == EntryType.credit;

                    return GestureDetector(
                      onLongPress: ctrl.isTodayEditable
                          ? () {
                              setState(() => _selectedDeleteIdx = index);
                            }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFEF2F2)
                              : (index.isOdd ? _rowAltBg : Colors.white),
                          border: Border(
                            bottom: const BorderSide(color: _borderColor),
                            left: isSelected
                                ? const BorderSide(color: _debitColor, width: 3)
                                : BorderSide.none,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _DataCell(
                                '${index + 1}',
                                width: snoW,
                                align: TextAlign.center,
                                compact: isPhone,
                                style: TextStyle(
                                  fontSize: isPhone ? 12 : 13,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              _DataCell(
                                '${isCredit ? '+' : '-'}${_fmtCurrency(entry.money)}',
                                width: moneyW,
                                compact: isPhone,
                                style: TextStyle(
                                  fontSize: isPhone ? 12 : 13,
                                  fontWeight: FontWeight.w700,
                                  color: isCredit ? _creditColor : _debitColor,
                                ),
                              ),
                              Expanded(
                                child: _DataCell(
                                  entry.description,
                                  compact: isPhone,
                                  style: TextStyle(fontSize: isPhone ? 12 : 13),
                                ),
                              ),
                              SizedBox(
                                width: typeW,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isPhone ? 4 : 8,
                                    vertical: 8,
                                  ),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: _borderColor),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isCredit
                                          ? const Color(0xFFF0FDF4)
                                          : const Color(0xFFFEF2F2),
                                      border: Border.all(
                                        color: isCredit
                                            ? _creditColor
                                            : _debitColor,
                                      ),
                                    ),
                                    child: Text(
                                      entry.type.shortLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isCredit
                                            ? _creditColor
                                            : _debitColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _DataCell(
                                formatTime(entry.createdAt),
                                width: timeW,
                                isLast: true,
                                compact: isPhone,
                                style: TextStyle(
                                  fontSize: isPhone ? 11 : 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: _borderDark, width: 2)),
      ),
      child: const Text(
        'View only: Only today\'s sheet can be edited.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildDeleteBar(BalanceController ctrl, TransactionEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFEF2F2),
        border: Border(top: BorderSide(color: _debitColor, width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Delete "${entry.description}" (${_fmtCurrency(entry.money)})?',
              style: const TextStyle(
                color: _debitColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedDeleteIdx = null),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _debitColor,
              side: const BorderSide(color: _debitColor),
            ),
            onPressed: () async {
              final idx = _selectedDeleteIdx;
              setState(() => _selectedDeleteIdx = null);
              if (idx != null) {
                await ctrl.deleteEntry(idx);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRow({required bool isPhone}) {
    final moneyField = TextFormField(
      key: const Key('moneyInput'),
      controller: _moneyController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        hintText: 'Amount',
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
      ),
      validator: (v) {
        final n = double.tryParse((v ?? '').trim());
        return (n == null || n <= 0) ? 'Invalid' : null;
      },
    );

    final descField = TextFormField(
      key: const Key('descInput'),
      controller: _descController,
      decoration: const InputDecoration(
        hintText: 'Description (e.g. Lunch, Refund)',
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );

    final typeDropdown = DropdownButtonFormField<EntryType>(
      key: const Key('typeDropdown'),
      initialValue: _selectedType,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
      ),
      items: const [
        DropdownMenuItem(
          value: EntryType.debit,
          child: Text('Debit (-)'),
        ),
        DropdownMenuItem(
          value: EntryType.credit,
          child: Text('Credit (+)'),
        ),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedType = val);
      },
    );

    final addButton = FilledButton(
      key: const Key('addEntryBtn'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      onPressed: _submitEntry,
      child: const Text('+ Add'),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: _borderDark, width: 2)),
      ),
      child: Form(
        key: _formKey,
        child: isPhone
            ? Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: moneyField),
                      const SizedBox(width: 8),
                      Expanded(child: typeDropdown),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: descField),
                      const SizedBox(width: 8),
                      addButton,
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  SizedBox(width: 120, child: moneyField),
                  const SizedBox(width: 8),
                  Expanded(child: descField),
                  const SizedBox(width: 8),
                  SizedBox(width: 148, child: typeDropdown),
                  const SizedBox(width: 8),
                  addButton,
                ],
              ),
      ),
    );
  }

  Widget _buildFooterBar(
    BalanceController ctrl,
    DayRecord day,
    String nextDateKey, {
    required bool isPhone,
  }) {
    final note = Text(
      'Closing (${_fmtCurrency(day.closingBalance)}) → ${formatDisplayDate(nextDateKey)} Opening. Long-press a row to delete.',
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF475569),
      ),
    );

    final nextButton = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(),
      ),
      onPressed: () {
        setState(() => _selectedDeleteIdx = null);
        ctrl.goToNextDay();
      },
      child: const Text('Close Day & Next →'),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 16,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(top: BorderSide(color: _borderDark, width: 2)),
      ),
      child: isPhone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                note,
                const SizedBox(height: 8),
                nextButton,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: note),
                const SizedBox(width: 12),
                nextButton,
              ],
            ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.text, {
    this.width,
    this.align = TextAlign.left,
    this.isLast = false,
    this.compact = false,
  });

  final String text;
  final double? width;
  final TextAlign align;
  final bool isLast;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 10,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(right: BorderSide(color: Color(0xFFCBD5E1))),
      ),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
    return width != null ? SizedBox(width: width, child: child) : child;
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell(
    this.text, {
    this.width,
    this.align = TextAlign.left,
    this.style,
    this.isLast = false,
    this.compact = false,
  });

  final String text;
  final double? width;
  final TextAlign align;
  final TextStyle? style;
  final bool isLast;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 10,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(right: BorderSide(color: Color(0xFFCBD5E1))),
      ),
      alignment:
          align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: align,
        style: style ?? TextStyle(fontSize: compact ? 12 : 13),
      ),
    );
    return width != null ? SizedBox(width: width, child: child) : child;
  }
}
