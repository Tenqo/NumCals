import 'calculation_history_entry.dart';

class HistoryController {
  static const _maxEntries = 10;

  final List<CalculationHistoryEntry> _entries = [];

  List<CalculationHistoryEntry> get entries =>
      List<CalculationHistoryEntry>.unmodifiable(_entries);

  void add(CalculationHistoryEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) _entries.removeLast();
  }

  void clear() => _entries.clear();
}
