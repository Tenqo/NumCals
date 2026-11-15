import 'package:flutter_test/flutter_test.dart';

import 'package:numcals/features/calculator/calculator_engine.dart';

void main() {
  const engine = CalculatorEngine();

  test('uses standard arithmetic precedence and parentheses', () {
    expect(engine.evaluate('2+3×4'), 14);
    expect(engine.evaluate('(2+3)×4'), 20);
  });

  test('supports powers and scientific functions', () {
    expect(engine.evaluate('2^3^2'), 512);
    expect(engine.evaluate('-2^2'), -4);
    expect(engine.evaluate('2^-2'), 0.25);
    expect(engine.evaluate('sqrt(81)+sin(30)'), closeTo(9.5, 1e-10));
    expect(engine.evaluate('log(1000)'), closeTo(3, 1e-10));
    expect(engine.evaluate('ln(e)'), closeTo(1, 1e-10));
  });

  test('supports constants and implicit multiplication', () {
    expect(engine.evaluate('2π'), closeTo(2 * 3.141592653589793, 1e-10));
    expect(engine.evaluate('5!'), 120);
  });

  test('supports scientific notation without changing the e constant', () {
    expect(engine.evaluate('1e3 + 2'), 1002);
    expect(engine.evaluate('1.25E-3'), closeTo(0.00125, 1e-12));
    expect(engine.evaluate('2e'), closeTo(2 * 2.718281828459045, 1e-10));
  });

  test('respects radians mode', () {
    expect(
      engine.evaluate('sin(1.5707963267948966)', useDegrees: false),
      closeTo(1, 1e-10),
    );
  });

  test('rejects invalid expressions and division by zero', () {
    expect(() => engine.evaluate('1÷0'), throwsFormatException);
    expect(() => engine.evaluate('(-1)!'), throwsFormatException);
    expect(() => engine.evaluate('(2+3'), throwsFormatException);
    expect(() => engine.evaluate('1**2'), throwsFormatException);
    expect(() => engine.evaluate('sin()'), throwsFormatException);
  });

  test('bounds factorials and rejects non-finite intermediate results', () {
    expect(engine.evaluate('0!'), 1);
    expect(engine.evaluate('170!').isFinite, isTrue);
    expect(() => engine.evaluate('171!'), throwsFormatException);
    expect(() => engine.evaluate('1e999'), throwsFormatException);
    expect(() => engine.evaluate('10^400'), throwsFormatException);
    expect(() => engine.evaluate('sqrt(-1)'), throwsFormatException);
    expect(() => engine.evaluate('ln(0)'), throwsFormatException);
  });

  test('bounds expression length and recursive nesting', () {
    final longExpression = List<String>.filled(
      CalculatorEngine.maxExpressionLength + 1,
      '1',
    ).join();
    final nestedExpression =
        '${List<String>.filled(65, '(').join()}1'
        '${List<String>.filled(65, ')').join()}';
    final longPowerChain = List<String>.filled(66, '2').join('^');

    expect(() => engine.evaluate(longExpression), throwsFormatException);
    expect(() => engine.evaluate(nestedExpression), throwsFormatException);
    expect(() => engine.evaluate(longPowerChain), throwsFormatException);
  });
}
