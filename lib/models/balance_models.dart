import 'dart:convert';

/// Whether a transaction adds to or subtracts from the day's balance.
enum EntryType {
  credit,
  debit;

  String get label => this == EntryType.credit ? 'CREDIT' : 'DEBIT';
  String get shortLabel => this == EntryType.credit ? 'C' : 'D';

  static EntryType fromString(String value) {
    return value == 'credit' ? EntryType.credit : EntryType.debit;
  }
}

/// A single row in the daily balance sheet.
class TransactionEntry {
  TransactionEntry({
    required this.money,
    required this.description,
    required this.type,
    required this.createdAt,
  });

  final double money;
  final String description;
  final EntryType type;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'money': money,
        'description': description,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TransactionEntry.fromJson(Map<String, dynamic> json) {
    return TransactionEntry(
      money: (json['money'] as num).toDouble(),
      description: json['description'] as String,
      type: EntryType.fromString(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Holds the opening balance and all transactions for a single calendar date.
class DayRecord {
  DayRecord({
    required this.dateKey,
    required this.openingBalance,
    List<TransactionEntry>? entries,
  }) : entries = entries ?? [];

  final String dateKey;
  double openingBalance;
  final List<TransactionEntry> entries;

  double get totalCredit => entries
      .where((e) => e.type == EntryType.credit)
      .fold(0.0, (sum, e) => sum + e.money);

  double get totalDebit => entries
      .where((e) => e.type == EntryType.debit)
      .fold(0.0, (sum, e) => sum + e.money);

  double get closingBalance => openingBalance + totalCredit - totalDebit;

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'openingBalance': openingBalance,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory DayRecord.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List<dynamic>? ?? []);
    return DayRecord(
      dateKey: json['dateKey'] as String,
      openingBalance: (json['openingBalance'] as num).toDouble(),
      entries: rawEntries
          .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static String encodeMap(Map<String, DayRecord> records) {
    final map = records.map((k, v) => MapEntry(k, v.toJson()));
    return jsonEncode(map);
  }

  static Map<String, DayRecord> decodeMap(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (k, v) => MapEntry(k, DayRecord.fromJson(v as Map<String, dynamic>)),
    );
  }
}

/// Date formatting helpers (YYYY-MM-DD keys and readable display strings).
String toDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseDateKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

String addDaysToKey(String key, int delta) {
  final dt = parseDateKey(key);
  return toDateKey(DateTime(dt.year, dt.month, dt.day + delta));
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDisplayDate(String key) {
  final dt = parseDateKey(key);
  final day = dt.day.toString().padLeft(2, '0');
  final month = _monthNames[dt.month - 1];
  return '$day $month ${dt.year}';
}

String formatTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${hour12.toString().padLeft(2, '0')}:$minute $period';
}
