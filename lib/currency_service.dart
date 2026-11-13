import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CurrencyInfo {
  const CurrencyInfo({required this.code, required this.name});

  final String code;
  final String name;
}

class ExchangeRate {
  const ExchangeRate({required this.rate, required this.date});

  final double rate;
  final DateTime date;
}

class CurrencyServiceException implements Exception {
  const CurrencyServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CurrencyService {
  const CurrencyService();

  static const _timeout = Duration(seconds: 12);

  Future<List<CurrencyInfo>> fetchCurrencies() async {
    final response = await _fetchJson(
      Uri.https('api.frankfurter.dev', '/v2/currencies'),
    );
    if (response is! List) {
      throw const FormatException('The currency list response was invalid.');
    }

    final currencies = <CurrencyInfo>[];
    for (final item in response) {
      if (item is! Map<String, dynamic> || item['type'] != 'currency') {
        continue;
      }
      final code = item['iso_code'];
      final name = item['name'];
      if (code is String && name is String) {
        currencies.add(CurrencyInfo(code: code, name: name));
      }
    }
    if (currencies.isEmpty) {
      throw const FormatException('No supported currencies were returned.');
    }
    return currencies;
  }

  Future<ExchangeRate> fetchRate(String base, String quote) async {
    if (base == quote) {
      return ExchangeRate(rate: 1, date: DateTime.now().toUtc());
    }

    final response = await _fetchJson(
      Uri.https(
        'api.frankfurter.dev',
        '/v2/rate/${Uri.encodeComponent(base)}/${Uri.encodeComponent(quote)}',
      ),
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('The exchange-rate response was invalid.');
    }

    final rateValue = response['rate'];
    final rate = rateValue is num ? rateValue.toDouble() : null;
    final dateText = response['date'];
    final date = dateText is String ? DateTime.tryParse(dateText) : null;
    if (rate == null || !rate.isFinite || rate <= 0 || date == null) {
      throw const FormatException('The exchange-rate response was incomplete.');
    }
    return ExchangeRate(rate: rate, date: date);
  }

  Future<dynamic> _fetchJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CurrencyServiceException(
          'Exchange-rate service returned HTTP ${response.statusCode}.',
        );
      }
      return jsonDecode(body);
    } on CurrencyServiceException {
      rethrow;
    } on TimeoutException {
      throw const CurrencyServiceException(
        'The currency service timed out. Check your internet connection.',
      );
    } on IOException catch (error) {
      throw CurrencyServiceException(
        'Could not reach the currency service: $error',
      );
    } finally {
      client.close(force: true);
    }
  }
}
