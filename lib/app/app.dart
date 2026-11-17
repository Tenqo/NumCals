import 'package:material_ui/material_ui.dart';

import '../features/calculator/calculator_screen.dart';
import '../features/currency/currency_service.dart';
import 'theme/app_theme.dart';

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
      title: 'NumCals',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: _themeMode,
      home: CalculatorPage(
        currencyService: widget.currencyService,
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
