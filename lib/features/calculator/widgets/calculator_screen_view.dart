import 'package:material_ui/material_ui.dart';

import '../../currency/currency_service.dart';
import '../calculator_mode.dart';

class CalculatorScreenView extends StatelessWidget {
  const CalculatorScreenView({
    super.key,
    required this.mode,
    required this.expression,
    required this.display,
    required this.useDegrees,
    required this.justEvaluated,
    required this.hasError,
    required this.convertedFromAmount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.currencies,
    required this.exchangeRate,
    required this.isLoadingCurrencies,
    required this.isLoadingRate,
    required this.currencyError,
    required this.onKeyEvent,
    required this.onModeSelected,
    required this.onHistoryPressed,
    required this.onSettingsPressed,
    required this.onCopyResult,
    required this.onKeyPressed,
    required this.onBaseCurrencyChanged,
    required this.onQuoteCurrencyChanged,
    required this.onSwapCurrencies,
    required this.onRetryCurrency,
    required this.onOpenFrankfurter,
    required this.formatNumber,
  });

  final CalculatorMode mode;
  final String expression;
  final String display;
  final bool useDegrees;
  final bool justEvaluated;
  final bool hasError;
  final String? convertedFromAmount;
  final String fromCurrency;
  final String toCurrency;
  final List<CurrencyInfo> currencies;
  final ExchangeRate? exchangeRate;
  final bool isLoadingCurrencies;
  final bool isLoadingRate;
  final String? currencyError;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final ValueChanged<CalculatorMode> onModeSelected;
  final VoidCallback onHistoryPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onCopyResult;
  final ValueChanged<String> onKeyPressed;
  final ValueChanged<String?> onBaseCurrencyChanged;
  final ValueChanged<String?> onQuoteCurrencyChanged;
  final VoidCallback onSwapCurrencies;
  final VoidCallback onRetryCurrency;
  final VoidCallback onOpenFrankfurter;
  final String Function(double) formatNumber;

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

  @override
  Widget build(BuildContext context) {
    final displayCaption = !justEvaluated || mode == CalculatorMode.currency
        ? ''
        : expression;
    final displayText = mode == CalculatorMode.currency && justEvaluated
        ? '$display $toCurrency'
        : display;

    return Focus(
      autofocus: true,
      onKeyEvent: onKeyEvent,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colorScheme = Theme.of(context).colorScheme;
              final rowCount = mode == CalculatorMode.scientific ? 8 : 5;
              final contentWidth =
                  (constraints.maxWidth < 580.0
                      ? constraints.maxWidth
                      : 580.0) -
                  40.0;
              final keyPadding = contentWidth < 300 ? 3.0 : 5.0;
              final displayReserve = mode == CalculatorMode.currency
                  ? 155.0
                  : 70.0;
              final heightLimitedKeyHeight =
                  (constraints.maxHeight -
                      28 -
                      48 -
                      displayReserve -
                      rowCount * keyPadding * 2) /
                  rowCount;
              final widthLimitedKeyHeight =
                  contentWidth /
                      (mode == CalculatorMode.scientific ? 5.0 : 4.0) -
                  keyPadding * 2;
              final keyHeight =
                  (heightLimitedKeyHeight < widthLimitedKeyHeight
                          ? heightLimitedKeyHeight
                          : widthLimitedKeyHeight)
                      .clamp(22.0, 72.0);
              final keypadWidth = mode == CalculatorMode.scientific
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
                                  PopupMenuButton<CalculatorMode>(
                                    tooltip: 'Choose calculator mode',
                                    icon: const Icon(Icons.menu_rounded),
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    color: colorScheme.surfaceContainerHighest,
                                    onSelected: (mode) {
                                      onModeSelected(mode);
                                    },
                                    itemBuilder: (context) => [
                                      _modeMenuItem(
                                        title: 'Standard calculator',
                                        icon: Icons.calculate_outlined,
                                        mode: CalculatorMode.standard,
                                      ),
                                      _modeMenuItem(
                                        title: 'Scientific mode',
                                        icon: Icons.functions_rounded,
                                        mode: CalculatorMode.scientific,
                                      ),
                                      _modeMenuItem(
                                        title: 'Currency converter',
                                        icon: Icons.currency_exchange_rounded,
                                        mode: CalculatorMode.currency,
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Recent calculations',
                                    onPressed: onHistoryPressed,
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
                                    onPressed: onSettingsPressed,
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
                                      if (mode == CalculatorMode.currency) ...[
                                        _buildCurrencyControls(
                                          context,
                                          keypadWidth,
                                        ),
                                        const SizedBox(height: 4),
                                        _buildExchangeRateStatus(context),
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
                                      if (convertedFromAmount != null)
                                        SizedBox(
                                          height: 22,
                                          child: Text(
                                            '$convertedFromAmount $fromCurrency =',
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
                                            if (justEvaluated && !hasError)
                                              IconButton(
                                                tooltip: 'Copy result',
                                                onPressed: onCopyResult,
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
                        if (mode == CalculatorMode.scientific)
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
                    ? (useDegrees ? 'DEG' : 'RAD')
                    : key.label,
                style: key.style,
                height: height,
                icon: key.icon,
                onPressed: () => onKeyPressed(key.action),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrencyControls(BuildContext context, double width) {
    if (isLoadingCurrencies || currencies.isEmpty) {
      return SizedBox(
        width: width,
        height: 40,
        child: Center(
          child: Text(
            isLoadingCurrencies
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
              context: context,
              value: fromCurrency,
              onChanged: (value) {
                if (value != null) onBaseCurrencyChanged(value);
              },
            ),
          ),
          IconButton(
            tooltip: 'Swap currencies',
            onPressed: onSwapCurrencies,
            icon: const Icon(Icons.swap_horiz_rounded),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: _currencyDropdown(
              context: context,
              value: toCurrency,
              onChanged: (value) {
                if (value != null) onQuoteCurrencyChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyDropdown({
    required BuildContext context,
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
          for (final currency in currencies)
            Align(
              alignment: Alignment.center,
              child: Text(currency.code, maxLines: 1),
            ),
        ],
        items: [
          for (final currency in currencies)
            DropdownMenuItem(
              value: currency.code,
              child: Text(
                '${currency.code} · ${currency.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: isLoadingRate ? null : onChanged,
      ),
    );
  }

  Widget _buildExchangeRateStatus(BuildContext context) {
    final error = currencyError;
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
            onPressed: onRetryCurrency,
            icon: const Icon(Icons.refresh_rounded),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }
    if (isLoadingRate || isLoadingCurrencies) {
      return Text(
        'Fetching reference rate…',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      );
    }
    final rate = exchangeRate;
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
                  '1 $fromCurrency = '
                  '${formatNumber(rate.rate)} $toCurrency',
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
            onPressed: onOpenFrankfurter,
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

  PopupMenuItem<CalculatorMode> _modeMenuItem({
    required String title,
    required IconData icon,
    required CalculatorMode mode,
  }) {
    return PopupMenuItem<CalculatorMode>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (this.mode == mode) const Icon(Icons.check_rounded, size: 16),
        ],
      ),
    );
  }
}

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
