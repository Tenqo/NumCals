import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'calculator_engine.dart';
import 'currency_service.dart';

void main() {
  runApp(const CalculatorApp());
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = isDark
      ? const ColorScheme.dark(
          primary: Color(0xFFFF9F0A),
          onPrimary: Colors.white,
          surface: Color(0xFF1C1C1E),
          onSurface: Colors.white,
          surfaceContainerHighest: Color(0xFF3A3A3C),
          onSurfaceVariant: Color(0xFFB0B0B5),
          error: Color(0xFFFF453A),
        )
      : const ColorScheme.light(
          primary: Color(0xFFB86D00),
          onPrimary: Colors.white,
          surface: Color(0xFFFFFCF5),
          onSurface: Color(0xFF28251F),
          surfaceContainerHighest: Color(0xFFE9E3D8),
          onSurfaceVariant: Color(0xFF686259),
          error: Color(0xFFB3261E),
        );

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: isDark ? Colors.black : const Color(0xFFF3EFE6),
    colorScheme: colorScheme,
    useMaterial3: true,
  );
}

class CalculatorApp extends StatefulWidget {
  const CalculatorApp({super.key, this.currencyService});

  final CurrencyService? currencyService;

  @override
  State<CalculatorApp> createState() => _CalculatorAppState();
}

class _CalculatorAppState extends State<CalculatorApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SysCalculator',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: CalculatorPage(
        currencyService: widget.currencyService,
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

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
  static const _windowChannel = MethodChannel('syscalculator/window');

  late final CurrencyService _currencyService =
      widget.currencyService ?? const CurrencyService();
  String _expression = '';
  String _display = '0';
  _CalculatorMode _mode = _CalculatorMode.standard;
  bool _useDegrees = true;
  bool _isPinned = false;
  bool _hasError = false;
  bool _justEvaluated = false;
  final List<_CalculationHistoryItem> _history = [];
  List<CurrencyInfo> _currencies = const [];
  String _fromCurrency = 'USD';
  String _toCurrency = 'EUR';
  ExchangeRate? _exchangeRate;
  bool _isLoadingCurrencies = false;
  bool _isLoadingRate = false;
  String? _currencyError;
  String? _convertedFromAmount;
  int _currencyRequestId = 0;

  bool get _isScientific => _mode == _CalculatorMode.scientific;
  bool get _isCurrency => _mode == _CalculatorMode.currency;

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

  static const _keyRows = <List<_KeyDefinition>>[
    [
      _KeyDefinition('AC', 'clear', _KeyStyle.utility),
      _KeyDefinition(
        'Backspace',
        'backspace',
        _KeyStyle.utility,
        Icons.backspace_outlined,
      ),
      _KeyDefinition('%', '%', _KeyStyle.utility),
      _KeyDefinition('÷', '÷', _KeyStyle.operator),
    ],
    [
      _KeyDefinition('7', '7'),
      _KeyDefinition('8', '8'),
      _KeyDefinition('9', '9'),
      _KeyDefinition('×', '×', _KeyStyle.operator),
    ],
    [
      _KeyDefinition('4', '4'),
      _KeyDefinition('5', '5'),
      _KeyDefinition('6', '6'),
      _KeyDefinition('-', '-', _KeyStyle.operator),
    ],
    [
      _KeyDefinition('1', '1'),
      _KeyDefinition('2', '2'),
      _KeyDefinition('3', '3'),
      _KeyDefinition('+', '+', _KeyStyle.operator),
    ],
    [
      _KeyDefinition('+/−', 'sign', _KeyStyle.utility),
      _KeyDefinition('0', '0'),
      _KeyDefinition('.', '.'),
      _KeyDefinition('=', 'equals', _KeyStyle.equals),
    ],
  ];

  static const _scientificRows = <List<_KeyDefinition>>[
    [
      _KeyDefinition('sin', 'sin(', _KeyStyle.scientific),
      _KeyDefinition('cos', 'cos(', _KeyStyle.scientific),
      _KeyDefinition('tan', 'tan(', _KeyStyle.scientific),
      _KeyDefinition('√', 'sqrt(', _KeyStyle.scientific),
    ],
    [
      _KeyDefinition('x²', '^2', _KeyStyle.scientific),
      _KeyDefinition('xʸ', '^', _KeyStyle.scientific),
      _KeyDefinition('ln', 'ln(', _KeyStyle.scientific),
      _KeyDefinition('log', 'log(', _KeyStyle.scientific),
    ],
    [
      _KeyDefinition('(', '(', _KeyStyle.scientific),
      _KeyDefinition(')', ')', _KeyStyle.scientific),
      _KeyDefinition('!', '!', _KeyStyle.scientific),
      _KeyDefinition('π', 'π', _KeyStyle.scientific),
      _KeyDefinition('e', 'e', _KeyStyle.scientific),
    ],
  ];

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
            ? _CalculatorMode.standard
            : _CalculatorMode.scientific,
      );
      return;
    }
    _append(action);
  }

  Future<void> _selectMode(_CalculatorMode mode) async {
    setState(() {
      _mode = mode;
      _reset();
      _currencyError = null;
    });
    if (mode != _CalculatorMode.currency) return;
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
      setState(() {
        _convertedFromAmount = _formatNumber(amount);
        _display = _formatNumber(amount * rate.rate);
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

  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.brightness_auto_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Change appearance'),
                  subtitle: const Text('System, light, or dark'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showAppearanceSettings();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('App diagnostics'),
                  subtitle: const Text('Check that the app and services work'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showDiagnostics();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.keyboard_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Keyboard shortcuts'),
                  subtitle: const Text('Use the keyboard to calculate faster'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showKeyboardShortcuts();
                  },
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Keep on top'),
                          const SizedBox(height: 3),
                          Text(
                            'Show above other windows',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPinned,
                      onChanged: (value) async {
                        await _setPinned(value);
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
                if (_isScientific) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Text('Use radians')),
                      Switch(
                        value: !_useDegrees,
                        onChanged: (value) {
                          setState(() => _useDegrees = !value);
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAppearanceSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Appearance'),
        content: RadioGroup<ThemeMode>(
          groupValue: widget.themeMode,
          onChanged: (mode) => _selectThemeMode(mode, dialogContext),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('System default'),
                subtitle: const Text('Match Windows appearance'),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Light'),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark'),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _selectThemeMode(ThemeMode? mode, BuildContext dialogContext) {
    if (mode == null) return;
    widget.onThemeModeChanged(mode);
    Navigator.pop(dialogContext);
  }

  void _showKeyboardShortcuts() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Keyboard shortcuts'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShortcutRow(keys: '0–9', action: 'Enter numbers'),
            _ShortcutRow(keys: '+  −  *  /', action: 'Choose an operation'),
            _ShortcutRow(keys: 'Enter  or  =', action: 'Calculate'),
            _ShortcutRow(keys: 'Backspace', action: 'Delete the last key'),
            _ShortcutRow(keys: 'Esc', action: 'Clear'),
            _ShortcutRow(keys: '(  )  %  ^', action: 'More operations'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _addHistoryEntry({
    required String expression,
    required String result,
    required _CalculatorMode mode,
    String? fromCurrency,
    String? toCurrency,
    String? sourceAmount,
  }) {
    _history.insert(
      0,
      _CalculationHistoryItem(
        expression: expression,
        result: result,
        mode: mode,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        sourceAmount: sourceAmount,
      ),
    );
    if (_history.length > 10) _history.removeLast();
  }

  void _showHistory() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              const Expanded(child: Text('Recent calculations')),
              if (_history.isNotEmpty)
                IconButton(
                  tooltip: 'Clear history',
                  onPressed: () {
                    setState(_history.clear);
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: _history.isEmpty
                ? Text(
                    'Your recent calculations will appear here.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      final resultLabel = entry.toCurrency == null
                          ? entry.result
                          : '${entry.result} ${entry.toCurrency}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          resultLabel,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 18),
                        ),
                        subtitle: Text(
                          entry.expression,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
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
                          Navigator.pop(dialogContext);
                          if (entry.mode == _CalculatorMode.currency) {
                            _refreshExchangeRate();
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
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

  void _showDiagnostics() {
    var checkStarted = false;
    var currencyStatus = 'Checking...';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!checkStarted) {
            checkStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await _currencyService.fetchCurrencies();
                await _currencyService.fetchRate('USD', 'EUR');
                if (!dialogContext.mounted) return;
                setDialogState(
                  () => currencyStatus = 'Working · daily, not live',
                );
              } on Object catch (error) {
                if (!dialogContext.mounted) return;
                setDialogState(() => currencyStatus = 'Unavailable — $error');
              }
            });
          }

          final calculationWorks = _engine.evaluate('2 + 2') == 4;
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('App diagnostics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DiagnosticStatus(
                  label: 'User interface',
                  status: 'Working',
                ),
                const SizedBox(height: 12),
                _DiagnosticStatus(
                  label: 'Calculator',
                  status: calculationWorks ? 'Working' : 'Not working',
                ),
                const SizedBox(height: 12),
                _DiagnosticStatus(
                  label: 'Currency:',
                  status: currencyStatus,
                  linkLabel: 'Stock license',
                  onLinkTap: _openFrankfurterWebsite,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final displayCaption = !_justEvaluated || _isCurrency ? '' : _expression;
    final displayText = _isCurrency && _justEvaluated
        ? '$_display $_toCurrency'
        : _display;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colorScheme = Theme.of(context).colorScheme;
              final rowCount = _isScientific ? 8 : 5;
              final contentWidth =
                  (constraints.maxWidth < 580.0
                      ? constraints.maxWidth
                      : 580.0) -
                  40.0;
              final keyPadding = contentWidth < 300 ? 3.0 : 5.0;
              final displayReserve = _isCurrency ? 155.0 : 70.0;
              final heightLimitedKeyHeight =
                  (constraints.maxHeight -
                      28 -
                      48 -
                      displayReserve -
                      rowCount * keyPadding * 2) /
                  rowCount;
              final widthLimitedKeyHeight =
                  contentWidth / (_isScientific ? 5.0 : 4.0) - keyPadding * 2;
              final keyHeight =
                  (heightLimitedKeyHeight < widthLimitedKeyHeight
                          ? heightLimitedKeyHeight
                          : widthLimitedKeyHeight)
                      .clamp(22.0, 72.0);
              final keypadWidth = _isScientific
                  ? contentWidth
                  : 4.0 * (keyHeight + keyPadding * 2);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      children: [
                        Center(
                          child: SizedBox(
                            width: contentWidth,
                            height: 48,
                            child: Container(
                              key: const ValueKey('app-toolbar'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  PopupMenuButton<_CalculatorMode>(
                                    tooltip: 'Choose calculator mode',
                                    icon: const Icon(Icons.menu_rounded),
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    color: colorScheme.surfaceContainerHighest,
                                    onSelected: (mode) {
                                      _selectMode(mode);
                                    },
                                    itemBuilder: (context) => [
                                      _modeMenuItem(
                                        title: 'Standard calculator',
                                        icon: Icons.calculate_outlined,
                                        mode: _CalculatorMode.standard,
                                      ),
                                      _modeMenuItem(
                                        title: 'Scientific mode',
                                        icon: Icons.functions_rounded,
                                        mode: _CalculatorMode.scientific,
                                      ),
                                      _modeMenuItem(
                                        title: 'Currency converter',
                                        icon: Icons.currency_exchange_rounded,
                                        mode: _CalculatorMode.currency,
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Recent calculations',
                                    onPressed: _showHistory,
                                    color: colorScheme.onSurfaceVariant,
                                    icon: const Icon(Icons.history_rounded),
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 36,
                                      height: 36,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'Settings',
                                    onPressed: _showSettings,
                                    color: colorScheme.onSurfaceVariant,
                                    icon: const Icon(Icons.settings_outlined),
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 36,
                                      height: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: keypadWidth,
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (_isCurrency) ...[
                                        _buildCurrencyControls(keypadWidth),
                                        const SizedBox(height: 4),
                                        _buildExchangeRateStatus(),
                                        const SizedBox(height: 8),
                                      ],
                                      if (displayCaption.isNotEmpty)
                                        SizedBox(
                                          height: 18,
                                          child: Text(
                                            displayCaption,
                                            key: const ValueKey(
                                              'expression-caption',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      if (_convertedFromAmount != null)
                                        SizedBox(
                                          height: 22,
                                          child: Text(
                                            '$_convertedFromAmount $_fromCurrency =',
                                            key: const ValueKey(
                                              'currency-source-amount',
                                            ),
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      Flexible(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  displayText,
                                                  key: const ValueKey(
                                                    'calculator-display',
                                                  ),
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    color:
                                                        colorScheme.onSurface,
                                                    fontSize: 64,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.05,
                                                    letterSpacing: -1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_justEvaluated && !_hasError)
                                              IconButton(
                                                tooltip: 'Copy result',
                                                onPressed: _copyResult,
                                                icon: const Icon(
                                                  Icons.copy_rounded,
                                                ),
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_isScientific)
                          for (final row in _scientificRows)
                            Center(
                              child: SizedBox(
                                width: keypadWidth,
                                child: _buildKeyRow(row, keyHeight, keyPadding),
                              ),
                            ),
                        for (final row in _keyRows)
                          Center(
                            child: SizedBox(
                              width: keypadWidth,
                              child: _buildKeyRow(row, keyHeight, keyPadding),
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
      ),
    );
  }

  Widget _buildKeyRow(List<_KeyDefinition> row, double height, double padding) {
    return Row(
      children: [
        for (final key in row)
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: _CalculatorKey(
                label: key.label == 'angle'
                    ? (_useDegrees ? 'DEG' : 'RAD')
                    : key.label,
                style: key.style,
                height: height,
                icon: key.icon,
                onPressed: () => _press(key.action),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrencyControls(double width) {
    if (_isLoadingCurrencies || _currencies.isEmpty) {
      return SizedBox(
        width: width,
        height: 40,
        child: Center(
          child: Text(
            _isLoadingCurrencies
                ? 'Loading currencies…'
                : 'Currencies unavailable',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: _currencyDropdown(
              value: _fromCurrency,
              onChanged: (value) {
                if (value != null) _changeCurrencyPair(base: value);
              },
            ),
          ),
          IconButton(
            tooltip: 'Swap currencies',
            onPressed: _swapCurrencies,
            icon: const Icon(Icons.swap_horiz_rounded),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: _currencyDropdown(
              value: _toCurrency,
              onChanged: (value) {
                if (value != null) _changeCurrencyPair(quote: value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        menuMaxHeight: 320,
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
        ),
        selectedItemBuilder: (context) => [
          for (final currency in _currencies)
            Align(
              alignment: Alignment.center,
              child: Text(currency.code, maxLines: 1),
            ),
        ],
        items: [
          for (final currency in _currencies)
            DropdownMenuItem(
              value: currency.code,
              child: Text(
                '${currency.code} · ${currency.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: _isLoadingRate ? null : onChanged,
      ),
    );
  }

  Widget _buildExchangeRateStatus() {
    final error = _currencyError;
    if (error != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retry exchange rate',
            onPressed: _currencies.isEmpty
                ? _loadCurrencies
                : _refreshExchangeRate,
            icon: const Icon(Icons.refresh_rounded),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }
    if (_isLoadingRate || _isLoadingCurrencies) {
      return Text(
        'Fetching reference rate…',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      );
    }
    final rate = _exchangeRate;
    if (rate == null) return const SizedBox(height: 16);
    return Tooltip(
      message:
          'Frankfurter reference rate updated ${_formatRateDate(rate)}. '
          'Rates are not live market quotes.',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 $_fromCurrency = '
                  '${_formatNumber(rate.rate)} $_toCurrency',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                Text(
                  'Updated ${_formatRateDate(rate)} · reference rate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openFrankfurterWebsite,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              minimumSize: const Size(0, 20),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Frankfurter ↗', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  String _formatRateDate(ExchangeRate rate) {
    final date = rate.date;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  PopupMenuItem<_CalculatorMode> _modeMenuItem({
    required String title,
    required IconData icon,
    required _CalculatorMode mode,
  }) {
    return PopupMenuItem<_CalculatorMode>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (_mode == mode) const Icon(Icons.check_rounded, size: 16),
        ],
      ),
    );
  }
}

class _CalculationHistoryItem {
  const _CalculationHistoryItem({
    required this.expression,
    required this.result,
    required this.mode,
    this.fromCurrency,
    this.toCurrency,
    this.sourceAmount,
  });

  final String expression;
  final String result;
  final _CalculatorMode mode;
  final String? fromCurrency;
  final String? toCurrency;
  final String? sourceAmount;
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              keys,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(action)),
        ],
      ),
    );
  }
}

class _DiagnosticStatus extends StatelessWidget {
  const _DiagnosticStatus({
    required this.label,
    required this.status,
    this.linkLabel,
    this.onLinkTap,
  });

  final String label;
  final String status;
  final String? linkLabel;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isChecking = status == 'Checking...';
    final color = isChecking
        ? colorScheme.onSurfaceVariant
        : status.startsWith('Working')
        ? isDark
              ? const Color(0xFF30D158)
              : const Color(0xFF287840)
        : colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (linkLabel == null)
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600))
        else
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onLinkTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  linkLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 3),
        Text(status, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

enum _CalculatorMode { standard, scientific, currency }

enum _KeyStyle { number, utility, operator, equals, scientific }

class _KeyDefinition {
  const _KeyDefinition(
    this.label,
    this.action, [
    this.style = _KeyStyle.number,
    this.icon,
  ]);

  final String label;
  final String action;
  final _KeyStyle style;
  final IconData? icon;
}

class _CalculatorKey extends StatelessWidget {
  const _CalculatorKey({
    required this.label,
    required this.style,
    required this.height,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final _KeyStyle style;
  final double height;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = switch (style) {
      _KeyStyle.number =>
        isDark ? const Color(0xFF333336) : const Color(0xFFE6E0D6),
      _KeyStyle.utility =>
        isDark ? const Color(0xFFA5A5AA) : const Color(0xFFD8D1C5),
      _KeyStyle.operator || _KeyStyle.equals => colorScheme.primary,
      _KeyStyle.scientific =>
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE6E0D6),
    };
    final foregroundColor = switch (style) {
      _KeyStyle.utility => isDark ? Colors.black : const Color(0xFF38342D),
      _KeyStyle.operator || _KeyStyle.equals => colorScheme.onPrimary,
      _ => colorScheme.onSurface,
    };

    return Center(
      child: SizedBox.square(
        dimension: height,
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: backgroundColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Center(
                child: icon == null
                    ? Text(
                        label,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize:
                              height *
                              (label.length > 3
                                  ? 0.34
                                  : label.length > 1
                                  ? 0.4
                                  : 0.55),
                          fontWeight: FontWeight.w300,
                        ),
                      )
                    : Icon(icon, color: foregroundColor, size: height * 0.44),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
