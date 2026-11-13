import 'package:flutter_test/flutter_test.dart';

import 'package:sys_calculator/calculator_engine.dart';

void main() {
  const engine = CalculatorEngine();

  test('uses standard arithmetic precedence and parentheses', () {
    expect(engine.evaluate('2+3×4'), 14);
    expect(engine.evaluate('(2+3)×4'), 20);
  });

  test('supports powers and scientific functions', () {
    expect(engine.evaluate('2^3^2'), 512);
    expect(engine.evaluate('sqrt(81)+sin(30)'), closeTo(9.5, 1e-10));
    expect(engine.evaluate('log(1000)'), closeTo(3, 1e-10));
    expect(engine.evaluate('ln(e)'), closeTo(1, 1e-10));
  });

  test('supports constants and implicit multiplication', () {
    expect(engine.evaluate('2π'), closeTo(2 * 3.141592653589793, 1e-10));
    expect(engine.evaluate('5!'), 120);
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
  });
}
