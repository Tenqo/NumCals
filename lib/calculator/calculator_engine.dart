import 'dart:math' as math;

class CalculatorEngine {
  const CalculatorEngine();

  double evaluate(String expression, {bool useDegrees = true}) {
    final parser = _ExpressionParser(expression, useDegrees);
    final result = parser.parse();
    if (!result.isFinite) {
      throw const FormatException('Result is not a finite number.');
    }
    return result;
  }
}

class _ExpressionParser {
  _ExpressionParser(this.expression, this.useDegrees);

  final String expression;
  final bool useDegrees;
  int _position = 0;

  double parse() {
    final result = _parseExpression();
    _skipWhitespace();
    if (_position != expression.length) {
      throw const FormatException('Unexpected input.');
    }
    return result;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parseUnary();
    while (true) {
      if (_match('×') || _match('*')) {
        value *= _parseUnary();
      } else if (_match('÷') || _match('/')) {
        value /= _parseUnary();
      } else if (_startsPrimary()) {
        value *= _parseUnary();
      } else {
        return value;
      }
    }
  }

  double _parseUnary() {
    if (_match('+')) return _parseUnary();
    if (_match('-')) return -_parseUnary();
    return _parsePower();
  }

  double _parsePower() {
    final base = _parsePostfix();
    if (_match('^')) {
      return math.pow(base, _parseUnary()).toDouble();
    }
    return base;
  }

  double _parsePostfix() {
    var value = _parsePrimary();
    while (true) {
      if (_match('!')) {
        value = _factorial(value);
      } else if (_match('%')) {
        value /= 100;
      } else {
        return value;
      }
    }
  }

  double _parsePrimary() {
    _skipWhitespace();
    if (_match('(')) {
      final value = _parseExpression();
      _expect(')');
      return value;
    }

    if (_position < expression.length &&
        _isNumberStart(expression[_position])) {
      return _parseNumber();
    }

    final identifier = _parseIdentifier();
    if (identifier == 'π' || identifier == 'pi') return math.pi;
    if (identifier == 'e') return math.e;

    _expect('(');
    final argument = _parseExpression();
    _expect(')');
    switch (identifier) {
      case 'sin':
        return math.sin(_toRadians(argument));
      case 'cos':
        return math.cos(_toRadians(argument));
      case 'tan':
        return math.tan(_toRadians(argument));
      case 'sqrt':
        return math.sqrt(argument);
      case 'ln':
        return math.log(argument);
      case 'log':
        return math.log(argument) / math.ln10;
      default:
        throw FormatException('Unknown function: $identifier');
    }
  }

  double _parseNumber() {
    final start = _position;
    var foundDigit = false;
    var foundDecimal = false;
    while (_position < expression.length) {
      final character = expression[_position];
      if (_isDigit(character)) {
        foundDigit = true;
        _position++;
      } else if (character == '.' && !foundDecimal) {
        foundDecimal = true;
        _position++;
      } else {
        break;
      }
    }

    if (!foundDigit) {
      throw const FormatException('Enter a valid number.');
    }

    if (_position < expression.length &&
        (expression[_position] == 'e' || expression[_position] == 'E')) {
      var exponentEnd = _position + 1;
      if (exponentEnd < expression.length &&
          (expression[exponentEnd] == '+' || expression[exponentEnd] == '-')) {
        exponentEnd++;
      }
      final exponentDigitsStart = exponentEnd;
      while (exponentEnd < expression.length &&
          _isDigit(expression[exponentEnd])) {
        exponentEnd++;
      }
      if (exponentEnd > exponentDigitsStart) _position = exponentEnd;
    }

    return double.parse(expression.substring(start, _position));
  }

  String _parseIdentifier() {
    _skipWhitespace();
    final start = _position;
    if (_position < expression.length && expression[_position] == 'π') {
      _position++;
      return 'π';
    }
    while (_position < expression.length && _isLetter(expression[_position])) {
      _position++;
    }
    if (_position == start) {
      throw const FormatException('Expected a number or function.');
    }
    return expression.substring(start, _position).toLowerCase();
  }

  double _factorial(double value) {
    if (value < 0 || value != value.truncateToDouble() || value > 170) {
      throw const FormatException(
        'Factorial requires a whole number from 0 to 170.',
      );
    }
    var result = 1.0;
    for (var factor = 2; factor <= value; factor++) {
      result *= factor;
    }
    return result;
  }

  double _toRadians(double value) {
    return useDegrees ? value * math.pi / 180 : value;
  }

  bool _startsPrimary() {
    _skipWhitespace();
    if (_position >= expression.length) return false;
    final character = expression[_position];
    return _isNumberStart(character) ||
        character == '(' ||
        character == 'π' ||
        _isLetter(character);
  }

  bool _isNumberStart(String character) {
    return _isDigit(character) || character == '.';
  }

  bool _isDigit(String character) {
    return character.codeUnitAt(0) >= 48 && character.codeUnitAt(0) <= 57;
  }

  bool _isLetter(String character) {
    final code = character.toLowerCase().codeUnitAt(0);
    return code >= 97 && code <= 122;
  }

  bool _match(String expected) {
    _skipWhitespace();
    if (!expression.startsWith(expected, _position)) return false;
    _position += expected.length;
    return true;
  }

  void _expect(String expected) {
    if (!_match(expected)) {
      throw FormatException('Expected "$expected".');
    }
  }

  void _skipWhitespace() {
    while (_position < expression.length &&
        expression[_position].trim().isEmpty) {
      _position++;
    }
  }
}
