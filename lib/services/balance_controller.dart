import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/balance_models.dart';

/// Manages daily balance records, automatic carry-forward, and local storage.
class BalanceController extends ChangeNotifier {
  static const _storageKey = 'balance_tracker_days_v1';
  static const _startDateStorageKey = 'balance_tracker_start_date_v1';

  BalanceController({
    DateTime? initialDate,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        _currentDateKey = toDateKey(initialDate ?? (clock ?? DateTime.now)()),
        _startDateKey = toDateKey(initialDate ?? (clock ?? DateTime.now)());

  final DateTime Function() _clock;
  final Map<String, DayRecord> _records = {};
  String _currentDateKey;
  String _startDateKey;
  bool _loaded = false;

  String get currentDateKey => _currentDateKey;
  String get startDateKey => _startDateKey;
  String get todayDateKey => toDateKey(_clock());
  bool get isLoaded => _loaded;
  bool get isTodayEditable => _currentDateKey == todayDateKey;
  bool get canEditOpeningBalance =>
      isTodayEditable && _currentDateKey == _startDateKey;

  DayRecord get currentDay => getOrCreateDay(_currentDateKey);

  /// Loads persisted records from [SharedPreferences].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStart = prefs.getString(_startDateStorageKey);
    final raw = prefs.getString(_storageKey);

    if (savedStart != null) {
      _startDateKey = savedStart;
    }

    if (raw != null && raw.isNotEmpty) {
      _records
        ..clear()
        ..addAll(DayRecord.decodeMap(raw));
    }

    if (_records.isEmpty) {
      _records[_startDateKey] = DayRecord(
        dateKey: _startDateKey,
        openingBalance: 0,
      );
    }

    _syncCarryForward();
    _loaded = true;
    notifyListeners();
  }

  /// Returns the [DayRecord] for [dateKey], carrying forward the latest prior
  /// closing balance if the date has not been initialized yet.
  DayRecord getOrCreateDay(String dateKey) {
    if (_records.containsKey(dateKey)) {
      return _records[dateKey]!;
    }

    final opening = _findOpeningForNewDay(dateKey);
    final record = DayRecord(dateKey: dateKey, openingBalance: opening);
    _records[dateKey] = record;
    return record;
  }

  double _findOpeningForNewDay(String dateKey) {
    final sortedKeys = _records.keys.toList()..sort();
    String? latestBefore;
    for (final k in sortedKeys) {
      if (k.compareTo(dateKey) < 0) {
        latestBefore = k;
      }
    }
    if (latestBefore == null) return 0;
    return _records[latestBefore]!.closingBalance;
  }

  /// Propagates closing balances forward across all recorded dates in order.
  void _syncCarryForward() {
    if (_records.isEmpty) return;
    final sortedKeys = _records.keys.toList()..sort();
    for (var i = 1; i < sortedKeys.length; i++) {
      final prev = _records[sortedKeys[i - 1]]!;
      final curr = _records[sortedKeys[i]]!;
      curr.openingBalance = prev.closingBalance;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startDateStorageKey, _startDateKey);
    await prefs.setString(_storageKey, DayRecord.encodeMap(_records));
  }

  /// Updates the opening balance on the initial day (only if today) and recalculates later days.
  Future<void> setOpeningBalance(double amount) async {
    if (!canEditOpeningBalance) return;
    currentDay.openingBalance = amount;
    _syncCarryForward();
    notifyListeners();
    await _save();
  }

  /// Adds a transaction to the active day (only if today) with the current timestamp.
  Future<void> addEntry({
    required double money,
    required String description,
    required EntryType type,
    DateTime? timestamp,
  }) async {
    if (!isTodayEditable) return;
    final entry = TransactionEntry(
      money: money,
      description: description,
      type: type,
      createdAt: timestamp ?? _clock(),
    );
    currentDay.entries.add(entry);
    _syncCarryForward();
    notifyListeners();
    await _save();
  }

  /// Deletes the transaction at [index] from the active day (only if today).
  Future<void> deleteEntry(int index) async {
    if (!isTodayEditable) return;
    final entries = currentDay.entries;
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    _syncCarryForward();
    notifyListeners();
    await _save();
  }

  /// Navigates to [dateKey], preventing navigation earlier than [_startDateKey].
  Future<void> goToDate(String dateKey) async {
    if (dateKey.compareTo(_startDateKey) < 0) return;
    _currentDateKey = dateKey;
    getOrCreateDay(dateKey);
    _syncCarryForward();
    notifyListeners();
    await _save();
  }

  Future<void> goToPreviousDay() => goToDate(addDaysToKey(_currentDateKey, -1));

  Future<void> goToNextDay() => goToDate(addDaysToKey(_currentDateKey, 1));
}
