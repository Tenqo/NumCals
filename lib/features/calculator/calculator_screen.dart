import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'calculator_engine.dart';
import 'calculator_mode.dart';
import '../currency/currency_service.dart';
import '../history/calculation_history_entry.dart';
import '../history/history_controller.dart';
import 'widgets/calculator_screen_dialogs.dart';
import 'widgets/calculator_screen_view.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    super.key,
    this.currencyService,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final CurrencyService? currencyService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  static const _engine = CalculatorEngine();
  static const _windowChannel = MethodChannel('numcals/window');

  late final CurrencyService _currencyService =
      widget.currencyService ?? CurrencyService();
  String _expression = '';
  String _display = '0';
  CalculatorMode _mode = CalculatorMode.standard;
  bool _useDegrees = true;
  bool _isPinned = false;
  bool _hasError = false;
  bool _justEvaluated = false;
  final HistoryController _history = HistoryController();
  List<CurrencyInfo> _currencies = const [];
  String _fromCurrency = 'USD';
  String _toCurrency = 'EUR';
  ExchangeRate? _exchangeRate;
  bool _isLoadingCurrencies = false;
  bool _isLoadingRate = false;
  String? _currencyError;
  String? _convertedFromAmount;
  int _currencyRequestId = 0;

  bool get _isScientific => _mode == CalculatorMode.scientific;
  bool get _isCurrency => _mode == CalculatorMode.currency;

  static final _digitKeys = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    String? digit;
    for (final entry in _digitKeys.entries) {
      if (entry.key.keyId == event.logicalKey.keyId) {
        digit = entry.value;
        break;
      }
    }
    if (digit != null) {
      _press(digit);
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null && character.isNotEmpty) {
      if (RegExp(r'^[0-9]$').hasMatch(character)) {
        _press(character);
        return KeyEventResult.handled;
      }
      switch (character) {
        case '+':
        case '-':
        case '*':
        case '/':
        case '.':
        case ',':
        case '(':
        case ')':
        case '%':
        case '!':
        case '^':
          _press(
            character == '*'
                ? '×'
                : character == '/'
                ? '÷'
                : character,
          );
          return KeyEventResult.handled;
        case '=':
        case '\r':
        case '\n':
          _press('equals');
          return KeyEventResult.handled;
      }
    }

    final keyId = event.logicalKey.keyId;
    if (keyId == LogicalKeyboardKey.enter.keyId ||
        keyId == LogicalKeyboardKey.numpadEnter.keyId ||
        keyId == LogicalKeyboardKey.numpadEqual.keyId) {
      _press('equals');
    } else if (keyId == LogicalKeyboardKey.numpadAdd.keyId) {
      _press('+');
    } else if (keyId == LogicalKeyboardKey.numpadSubtract.keyId) {
      _press('-');
    } else if (keyId == LogicalKeyboardKey.numpadMultiply.keyId) {
      _press('×');
    } else if (keyId == LogicalKeyboardKey.numpadDivide.keyId) {
      _press('÷');
    } else if (keyId == LogicalKeyboardKey.numpadDecimal.keyId ||
        keyId == LogicalKeyboardKey.period.keyId ||
        keyId == LogicalKeyboardKey.comma.keyId) {
      _press('.');
    } else if (keyId == LogicalKeyboardKey.backspace.keyId) {
      _press('backspace');
    } else if (keyId == LogicalKeyboardKey.escape.keyId ||
        keyId == LogicalKeyboardKey.delete.keyId) {
      _press('clear');
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _press(String action) {
    if (action == 'clear') {
      setState(_reset);
      return;
    }
    if (action == 'backspace') {
      _backspace();
      return;
    }
    if (action == 'equals') {
      _calculateResult();
      return;
    }
    if (action == 'angle') {
      setState(() => _useDegrees = !_useDegrees);
      return;
    }
    if (action == 'sign') {
      _toggleSign();
      return;
    }
    if (action == 'scientific') {
      setState(
        () => _mode = _isScientific
            ? CalculatorMode.standard
            : CalculatorMode.scientific,
      );
      return;
    }
    _append(action);
  }

  Future<void> _selectMode(CalculatorMode mode) async {
    setState(() {
      _mode = mode;
      _reset();
      _currencyError = null;
    });
    if (mode != CalculatorMode.currency) return;
    if (_currencies.isEmpty) {
      await _loadCurrencies();
    } else {
      await _refreshExchangeRate();
    }
  }

  Future<void> _loadCurrencies() async {
    setState(() {
      _isLoadingCurrencies = true;
      _currencyError = null;
    });
    try {
      final currencies = await _currencyService.fetchCurrencies();
      if (!mounted) return;
      setState(() {
        _currencies = currencies;
        if (!currencies.any((currency) => currency.code == _fromCurrency)) {
          _fromCurrency = currencies.first.code;
        }
        if (!currencies.any((currency) => currency.code == _toCurrency)) {
          _toCurrency = currencies.length > 1
              ? currencies[1].code
              : currencies.first.code;
        }
        _isLoadingCurrencies = false;
      });
      await _refreshExchangeRate();
    } on CurrencyServiceException catch (error) {
      _showCurrencyError(error.message);
    } on FormatException catch (error) {
      _showCurrencyError(error.message);
    } on TimeoutException {
      _showCurrencyError(
        'The currency service timed out. Check your internet.',
      );
    }
  }

  Future<void> _refreshExchangeRate() async {
    final requestId = ++_currencyRequestId;
    final base = _fromCurrency;
    final quote = _toCurrency;
    setState(() {
      _isLoadingRate = true;
      _currencyError = null;
      _exchangeRate = null;
    });
    try {
      final exchangeRate = await _currencyService.fetchRate(base, quote);
      if (!mounted || requestId != _currencyRequestId) return;
      setState(() {
        _exchangeRate = exchangeRate;
        _isLoadingRate = false;
      });
    } on CurrencyServiceException catch (error) {
      if (requestId == _currencyRequestId) _showCurrencyError(error.message);
    } on FormatException catch (error) {
      if (requestId == _currencyRequestId) {
        _showCurrencyError(error.message);
      }
    } on TimeoutException {
      if (requestId == _currencyRequestId) {
        _showCurrencyError(
          'The exchange-rate service timed out. Check your internet.',
        );
      }
    }
  }

  void _showCurrencyError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoadingCurrencies = false;
      _isLoadingRate = false;
      _exchangeRate = null;
      _currencyError = message;
    });
  }

  void _changeCurrencyPair({String? base, String? quote}) {
    setState(() {
      if (base != null) _fromCurrency = base;
      if (quote != null) _toCurrency = quote;
      _reset();
    });
    _refreshExchangeRate();
  }

  void _swapCurrencies() {
    setState(() {
      final previousBase = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = previousBase;
      _reset();
    });
    _refreshExchangeRate();
  }

  void _append(String token) {
    setState(() {
      if (_hasError) _reset();

      final isOperator = const {'+', '-', '×', '÷', '^'}.contains(token);
      if (_justEvaluated) {
        if (isOperator) {
          _expression = _display;
        } else if (token.endsWith('(')) {
          _expression = '$token$_display)';
          _display = _expression;
          _justEvaluated = false;
          return;
        } else {
          _expression = '';
        }
        _justEvaluated = false;
      }

      if (token == '.') {
        final currentNumber = RegExp(r'\d*\.?\d*$')
            .firstMatch(_expression)
            ?.group(0);
        if (currentNumber?.contains('.') ?? false) return;
        if (_expression.isEmpty || _endsWithOperatorOrOpenGroup(_expression)) {
          token = '0.';
        }
      }

      if (_startsValue(token) &&
          !(_isDigitToken(token) && _endsInNumber(_expression)) &&
          !(token == '.' && _endsInNumber(_expression)) &&
          _endsValue(_expression)) {
        _expression += '×';
      }
      _expression += token;
      if (_expression.length > CalculatorEngine.maxExpressionLength) {
        _expression = '';
        _display = 'Error';
        _hasError = true;
        _justEvaluated = false;
        return;
      }
      _display = _expression;
      _hasError = false;
    });
  }

  bool _startsValue(String token) {
    return RegExp(r'^(?:\d|\.|π|e|\(|[a-z]+\()').hasMatch(token);
  }

  bool _isDigitToken(String token) {
    return RegExp(r'^\d$').hasMatch(token);
  }

  bool _endsValue(String expression) {
    return RegExp(r'(?:\d|π|e|[)!%])$').hasMatch(expression);
  }

  bool _endsInNumber(String expression) {
    return RegExp(r'\d*\.?\d+$').hasMatch(expression);
  }

  bool _endsWithOperatorOrOpenGroup(String expression) {
    return expression.isEmpty || RegExp(r'[+\-×÷^(]$').hasMatch(expression);
  }

  void _toggleSign() {
    setState(() {
      if (_hasError) _reset();
      if (_justEvaluated) {
        _expression = _display.startsWith('-')
            ? _display.substring(1)
            : '-$_display';
        _display = _expression;
        _justEvaluated = false;
        return;
      }

      final match = RegExp(r'\d*\.?\d+$').firstMatch(_expression);
      if (match != null) {
        final start = match.start;
        final hasUnaryMinus =
            start > 0 &&
            _expression[start - 1] == '-' &&
            _endsWithOperatorOrOpenGroup(_expression.substring(0, start - 1));
        if (hasUnaryMinus) {
          _expression = _expression.replaceRange(start - 1, start, '');
        } else if (_endsWithOperatorOrOpenGroup(
          _expression.substring(0, start),
        )) {
          _expression = _expression.replaceRange(start, start, '-');
        } else {
          _expression = _expression.replaceRange(start, start, '-');
        }
      } else if (_endsWithOperatorOrOpenGroup(_expression)) {
        _expression += '-';
      }
      _display = _expression.isEmpty ? '0' : _expression;
    });
  }

  void _backspace() {
    setState(() {
      if (_hasError || _justEvaluated) {
        _reset();
        return;
      }
      if (_expression.isEmpty) return;

      final function = RegExp(r'(?:sin|cos|tan|sqrt|ln|log)\($');
      final match = function.firstMatch(_expression);
      _expression = match == null
          ? _expression.substring(0, _expression.length - 1)
          : _expression.substring(0, match.start);
      _display = _expression.isEmpty ? '0' : _expression;
    });
  }

  void _calculateResult() {
    if (_expression.isEmpty || _hasError) return;
    if (_isCurrency) {
      _calculateCurrencyResult();
      return;
    }
    try {
      final result = _engine.evaluate(_expression, useDegrees: _useDegrees);
      setState(() {
        _display = _formatNumber(result);
        _justEvaluated = true;
        _hasError = false;
        _addHistoryEntry(
          expression: _expression,
          result: _display,
          mode: _mode,
        );
      });
    } on FormatException {
      _showCalculationError();
    } on ArgumentError {
      _showCalculationError();
    }
  }

  Future<void> _calculateCurrencyResult() async {
    final rate = _exchangeRate;
    if (rate == null) {
      if (!_isLoadingRate && !_isLoadingCurrencies) {
        await _refreshExchangeRate();
      }
      return;
    }
    try {
      final amount = _engine.evaluate(_expression, useDegrees: _useDegrees);
      final convertedAmount = amount * rate.rate;
      if (!convertedAmount.isFinite) {
        _showCalculationError();
        return;
      }
      setState(() {
        _convertedFromAmount = _formatNumber(amount);
        _display = _formatNumber(convertedAmount);
        _justEvaluated = true;
        _hasError = false;
        _addHistoryEntry(
          expression: _expression,
          result: _display,
          mode: _mode,
          fromCurrency: _fromCurrency,
          toCurrency: _toCurrency,
          sourceAmount: _convertedFromAmount,
        );
      });
    } on FormatException {
      _showCalculationError();
    } on ArgumentError {
      _showCalculationError();
    }
  }

  void _showCalculationError() {
    setState(() {
      _display = 'Error';
      _hasError = true;
      _justEvaluated = false;
    });
  }

  Future<void> _setPinned(bool pinned) async {
    try {
      await _windowChannel.invokeMethod<void>('setAlwaysOnTop', pinned);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Could not change window pin setting.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isPinned = pinned);
  }

  Future<void> _openFrankfurterWebsite() async {
    try {
      await _windowChannel.invokeMethod<void>('openFrankfurterWebsite');
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Could not open the Frankfurter website.',
          ),
        ),
      );
    }
  }

  String _formatNumber(double value) {
    if (value.abs() >= 1e12 || (value != 0 && value.abs() < 1e-8)) {
      return value.toStringAsPrecision(8);
    }
    return value.toStringAsFixed(10).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _reset() {
    _expression = '';
    _display = '0';
    _hasError = false;
    _justEvaluated = false;
    _convertedFromAmount = null;
  }

  void _addHistoryEntry({
    required String expression,
    required String result,
    required CalculatorMode mode,
    String? fromCurrency,
    String? toCurrency,
    String? sourceAmount,
  }) {
    _history.add(
      CalculationHistoryEntry(
        expression: expression,
        result: result,
        mode: mode,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        sourceAmount: sourceAmount,
      ),
    );
  }

  void _showSettings() {
    showCalculatorSettingsDialog(
      context: context,
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
      isPinned: _isPinned,
      onPinnedChanged: _setPinned,
      isScientific: _isScientific,
      useDegrees: _useDegrees,
      onDegreesChanged: (value) => setState(() => _useDegrees = value),
      onDiagnostics: _showDiagnostics,
      onKeyboardShortcuts: _showKeyboardShortcuts,
    );
  }

  void _showKeyboardShortcuts() {
    showCalculatorKeyboardShortcutsDialog(context: context);
  }

  void _showDiagnostics() {
    showCalculatorDiagnosticsDialog(
      context: context,
      currencyService: _currencyService,
      calculationWorks: _engine.evaluate('2 + 2') == 4,
      onOpenFrankfurter: _openFrankfurterWebsite,
    );
  }

  void _showHistory() {
    showCalculatorHistoryDialog(
      context: context,
      entries: () => _history.entries,
      onClear: () => setState(_history.clear),
      onSelect: _selectHistoryEntry,
    );
  }

  void _selectHistoryEntry(CalculationHistoryEntry entry) {
    setState(() {
      _mode = entry.mode;
      _expression = entry.expression;
      _display = entry.result;
      _convertedFromAmount = entry.sourceAmount;
      _justEvaluated = true;
      _hasError = false;
      if (entry.fromCurrency != null) {
        _fromCurrency = entry.fromCurrency!;
      }
      if (entry.toCurrency != null) {
        _toCurrency = entry.toCurrency!;
      }
    });
    if (entry.mode == CalculatorMode.currency) _refreshExchangeRate();
  }

  Future<void> _copyResult() async {
    final text = _isCurrency ? '$_display $_toCurrency' : _display;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CalculatorScreenView(
    mode: _mode,
    expression: _expression,
    display: _display,
    useDegrees: _useDegrees,
    justEvaluated: _justEvaluated,
    hasError: _hasError,
    convertedFromAmount: _convertedFromAmount,
    fromCurrency: _fromCurrency,
    toCurrency: _toCurrency,
    currencies: _currencies,
    exchangeRate: _exchangeRate,
    isLoadingCurrencies: _isLoadingCurrencies,
    isLoadingRate: _isLoadingRate,
    currencyError: _currencyError,
    onKeyEvent: _handleKeyEvent,
    onModeSelected: (mode) {
      _selectMode(mode);
    },
    onHistoryPressed: _showHistory,
    onSettingsPressed: _showSettings,
    onCopyResult: _copyResult,
    onKeyPressed: _press,
    onBaseCurrencyChanged: (value) {
      if (value != null) _changeCurrencyPair(base: value);
    },
    onQuoteCurrencyChanged: (value) {
      if (value != null) _changeCurrencyPair(quote: value);
    },
    onSwapCurrencies: _swapCurrencies,
    onRetryCurrency: _currencies.isEmpty
        ? _loadCurrencies
        : _refreshExchangeRate,
    onOpenFrankfurter: _openFrankfurterWebsite,
    formatNumber: _formatNumber,
  );
}
