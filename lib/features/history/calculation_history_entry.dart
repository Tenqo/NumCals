import '../calculator/calculator_mode.dart';

class CalculationHistoryEntry {
  const CalculationHistoryEntry({
    required this.expression,
    required this.result,
    required this.mode,
    this.fromCurrency,
    this.toCurrency,
    this.sourceAmount,
  });

  final String expression;
  final String result;
  final CalculatorMode mode;
  final String? fromCurrency;
  final String? toCurrency;
  final String? sourceAmount;
}
