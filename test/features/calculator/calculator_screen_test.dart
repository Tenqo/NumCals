import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:numcals/features/calculator/calculator_engine.dart';
import 'package:numcals/features/currency/currency_service.dart';
import 'package:numcals/app/app.dart';

void main() {
  Future<void> tapKeys(WidgetTester tester, List<String> keys) async {
    for (final key in keys) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
  }

  Future<void> selectScientificMode(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Choose calculator mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scientific mode'));
    await tester.pumpAndSettle();
  }

  testWidgets('calculates basic arithmetic', (tester) async {
    await tester.pumpWidget(const CalculatorApp());

    await tapKeys(tester, ['8', '+', '4', '=']);

    expect(_display(tester), '12');
  });

  testWidgets('follows system light and dark appearance', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const CalculatorApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.scaffoldBackgroundColor, const Color(0xFFF3EFE6));
    expect(app.darkTheme?.scaffoldBackgroundColor, Colors.black);
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('app-toolbar'))))
          .brightness,
      Brightness.light,
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Change appearance'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpWidget(
      const CalculatorApp(key: ValueKey('dark-system-appearance')),
    );

    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('app-toolbar'))))
          .brightness,
      Brightness.dark,
    );
  });

  testWidgets('supports decimals and division', (tester) async {
    await tester.pumpWidget(const CalculatorApp());

    await tapKeys(tester, ['7', '.', '5', '÷', '2', '=']);

    expect(_display(tester), '3.75');
  });

  testWidgets('appearance choices update the app immediately', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const CalculatorApp());

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change appearance'));
    await tester.pumpAndSettle();
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('app-toolbar'))))
          .brightness,
      Brightness.light,
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System default'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('app-toolbar'))))
          .brightness,
      Brightness.dark,
    );
  });

  testWidgets('clears the display', (tester) async {
    await tester.pumpWidget(const CalculatorApp());

    await tapKeys(tester, ['9', 'AC']);

    expect(_display(tester), '0');
  });

  testWidgets('rejects overlong input and recovers on the next key', (
    tester,
  ) async {
    await tester.pumpWidget(const CalculatorApp());

    for (
      var index = 0;
      index <= CalculatorEngine.maxExpressionLength;
      index++
    ) {
      await tester.tap(find.text('1').last);
      await tester.pump();
    }

    expect(_display(tester), 'Error');

    await tester.tap(find.text('2').last);
    await tester.pump();
    expect(_display(tester), '2');
  });

  testWidgets('shows an error when dividing by zero', (tester) async {
    await tester.pumpWidget(const CalculatorApp());

    await tapKeys(tester, ['8', '÷', '0', '=']);

    expect(_display(tester), 'Error');
  });

  testWidgets('accepts number-pad input', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await tester.pumpAndSettle();
    expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.numpad8);
    await tester.pump();
    expect(_display(tester), '8');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.pump();
    expect(_display(tester), '8+');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.pump();
    expect(_display(tester), '8+4');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump();

    expect(_display(tester), '12');
  });

  testWidgets('supports scientific functions and order of operations', (
    tester,
  ) async {
    await tester.pumpWidget(const CalculatorApp());

    await selectScientificMode(tester);
    await tapKeys(tester, ['2', '+', '3', '×', '4', '=']);

    expect(_display(tester), '14');
  });

  testWidgets('mode menu offers standard, scientific, and currency modes', (
    tester,
  ) async {
    await tester.pumpWidget(const CalculatorApp());

    expect(find.byKey(const ValueKey('app-toolbar')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byTooltip('Recent calculations'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Choose calculator mode'), findsOneWidget);
    await tester.tap(find.byTooltip('Choose calculator mode'));
    await tester.pumpAndSettle();
    expect(find.text('Standard calculator'), findsOneWidget);
    expect(find.text('Scientific mode'), findsOneWidget);
    expect(find.text('Currency converter'), findsOneWidget);
  });

  testWidgets('converts an entered amount using the selected rate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(350, 470);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeCurrencyService();
    await tester.pumpWidget(CalculatorApp(currencyService: service));

    await tester.tap(find.byTooltip('Choose calculator mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Currency converter'));
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('1 USD = 0.9 EUR'), findsOneWidget);
    expect(find.text('Updated 2026-11-12 · reference rate'), findsOneWidget);

    await tapKeys(tester, ['1', '0', '=']);
    expect(_display(tester), '9 EUR');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('currency-source-amount')))
          .data,
      '10 USD =',
    );
    expect(find.text('9 EUR'), findsOneWidget);
    expect(service.lastBase, 'USD');
    expect(service.lastQuote, 'EUR');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error when currency conversion overflows', (
    tester,
  ) async {
    final service = _FakeCurrencyService()..conversionRate = double.maxFinite;
    await tester.pumpWidget(CalculatorApp(currencyService: service));
    await tester.tap(find.byTooltip('Choose calculator mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Currency converter'));
    await tester.pumpAndSettle();

    await tapKeys(tester, ['2', '=']);

    expect(_display(tester), 'Error');
    expect(tester.takeException(), isNull);
  });

  testWidgets('currency pair can be changed from the dropdown', (tester) async {
    final service = _FakeCurrencyService();
    await tester.pumpWidget(CalculatorApp(currencyService: service));

    await tester.tap(find.byTooltip('Choose calculator mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Currency converter'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAD · Canadian Dollar'));
    await tester.pumpAndSettle();

    expect(service.lastBase, 'CAD');
    expect(find.text('1 CAD = 1.25 EUR'), findsOneWidget);
    await tapKeys(tester, ['1', '=']);
    expect(_display(tester), '1.25 EUR');
  });

  testWidgets('Frankfurter source link opens its website', (tester) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('numcals/window');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      CalculatorApp(currencyService: _FakeCurrencyService()),
    );
    await tester.tap(find.byTooltip('Choose calculator mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Currency converter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frankfurter ↗'));

    expect(calls.single.method, 'openFrankfurterWebsite');
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports parentheses and degree-mode trigonometry', (
    tester,
  ) async {
    await tester.pumpWidget(const CalculatorApp());

    await selectScientificMode(tester);
    await tapKeys(tester, ['sin', '3', '0', ')', '=']);

    expect(_display(tester), '0.5');
  });

  testWidgets('recent calculations can be recalled', (tester) async {
    await tester.pumpWidget(const CalculatorApp());

    await tapKeys(tester, ['8', '+', '4', '=']);
    await tester.tap(find.byTooltip('Recent calculations'));
    await tester.pumpAndSettle();

    expect(find.text('Recent calculations'), findsOneWidget);
    expect(find.text('8+4'), findsNWidgets(2));
    expect(find.text('12'), findsNWidgets(2));
    await tester.tap(find.text('8+4').last);
    await tester.pumpAndSettle();

    expect(_display(tester), '12');
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent calculations can be cleared', (tester) async {
    await tester.pumpWidget(const CalculatorApp());

    await tapKeys(tester, ['8', '+', '4', '=']);
    await tester.tap(find.byTooltip('Recent calculations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear history'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your recent calculations will appear here.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Clear history'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculation result can be copied', (tester) async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(const CalculatorApp());
    await tapKeys(tester, ['6', '×', '7', '=']);

    await tester.tap(find.byTooltip('Copy result'));
    await tester.pump();

    final clipboardCall = calls.firstWhere(
      (call) => call.method == 'Clipboard.setData',
    );
    expect(clipboardCall.arguments, {'text': '42'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard shortcuts are available in settings', (tester) async {
    await tester.pumpWidget(const CalculatorApp());

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keyboard shortcuts'));
    await tester.pumpAndSettle();

    expect(find.text('Enter  or  ='), findsOneWidget);
    expect(find.text('Delete the last key'), findsOneWidget);
  });

  testWidgets(
    'scientific controls shrink without overflowing at minimum size',
    (tester) async {
      tester.view.physicalSize = const Size(350, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const CalculatorApp());
      await selectScientificMode(tester);

      final exception = tester.takeException();
      expect(exception, isNull, reason: '$exception');
    },
  );

  testWidgets('scientific keypad uses the available window width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(350, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CalculatorApp());
    await selectScientificMode(tester);

    final firstKey = tester.getCenter(find.text('sin'));
    final lastKey = tester.getCenter(find.text('√'));
    expect(lastKey.dx - firstKey.dx, greaterThan(150));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keys stay grouped when the window is wide', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CalculatorApp());

    final sevenCenter = tester.getCenter(find.text('7'));
    final eightCenter = tester.getCenter(find.text('8'));
    expect(eightCenter.dx - sevenCenter.dx, lessThan(100));
  });

  testWidgets('settings can pin the window above other windows', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('numcals/window');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const CalculatorApp());
    final settingsButton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.settings_outlined),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(
      settingsButton.color,
      Theme.of(tester.element(find.byTooltip('Settings')))
          .colorScheme
          .onSurfaceVariant,
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'setAlwaysOnTop');
    expect(calls.single.arguments, true);
  });

  testWidgets(
    'settings diagnostics check the calculator and currency service',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('numcals/window');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(
        CalculatorApp(currencyService: _FakeCurrencyService()),
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('App diagnostics'));
      await tester.pumpAndSettle();

      expect(find.text('User interface'), findsOneWidget);
      expect(find.text('Calculator'), findsOneWidget);
      expect(find.text('Working'), findsNWidgets(2));
      expect(find.text('Working · daily, not live'), findsOneWidget);
      final statusColor = tester
          .widget<Text>(find.text('Working · daily, not live'))
          .style
          ?.color;
      expect(
        statusColor,
        anyOf(const Color(0xFF30D158), const Color(0xFF287840)),
      );
      expect(find.text('Currency:'), findsOneWidget);
      expect(find.text('Stock license'), findsOneWidget);
      await tester.tap(find.text('Stock license'));
      expect(calls.single.method, 'openFrankfurterWebsite');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('diagnostics report when the currency service is unavailable', (
    tester,
  ) async {
    final service = _FakeCurrencyService()
      ..rateError = const CurrencyServiceException('offline');
    await tester.pumpWidget(CalculatorApp(currencyService: service));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Unavailable — offline'), findsOneWidget);
  });
}

class _FakeCurrencyService extends CurrencyService {
  Object? rateError;
  double conversionRate = 0.9;

  @override
  Future<List<CurrencyInfo>> fetchCurrencies() async => const [
    CurrencyInfo(code: 'USD', name: 'US Dollar'),
    CurrencyInfo(code: 'EUR', name: 'Euro'),
    CurrencyInfo(code: 'CAD', name: 'Canadian Dollar'),
  ];

  String? lastBase;
  String? lastQuote;

  @override
  Future<ExchangeRate> fetchRate(String base, String quote) async {
    lastBase = base;
    lastQuote = quote;
    final error = rateError;
    if (error != null) throw error;
    return ExchangeRate(
      rate: base == 'CAD' ? 1.25 : conversionRate,
      date: DateTime.utc(2026, 11, 12),
    );
  }
}

String _display(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const ValueKey('calculator-display')))
      .data!;
}
