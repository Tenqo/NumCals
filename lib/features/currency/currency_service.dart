import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  CurrencyService() : _testBaseUri = null, _timeout = _defaultTimeout;

  CurrencyService.forTesting({
    required Uri baseUri,
    Duration timeout = _defaultTimeout,
  }) : _testBaseUri = baseUri,
       _timeout = timeout {
    const loopbackHosts = {'127.0.0.1', 'localhost', '::1'};
    if (baseUri.scheme != 'http' ||
        !loopbackHosts.contains(baseUri.host) ||
        baseUri.port <= 0 ||
        baseUri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        'Test endpoints must use HTTP on loopback.',
      );
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }
  }

  static const _defaultTimeout = Duration(seconds: 12);
  static const _rateCacheDuration = Duration(minutes: 15);
  static const _maxResponseBytes = 256 * 1024;
  static const _maxCurrencyRecords = 500;
  static const _maxCachedRates = 64;
  static final _currencyCodePattern = RegExp(r'^[A-Z]{3}$');

  final Uri? _testBaseUri;
  final Duration _timeout;
  final Map<String, _CachedExchangeRate> _rateCache = {};
  final Map<String, Future<ExchangeRate>> _pendingRates = {};

  Future<List<CurrencyInfo>> fetchCurrencies() async {
    final response = await _fetchJson(_endpoint('/v2/currencies'));
    if (response is! List || response.length > _maxCurrencyRecords) {
      throw const FormatException('The currency list response was invalid.');
    }

    final currencies = <CurrencyInfo>[];
    final seenCodes = <String>{};
    for (final item in response) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('A currency entry was invalid.');
      }

      final type = item['type'];
      if (type == 'crypto') continue;
      if (type != 'currency') {
        throw const FormatException('A currency entry had an unknown type.');
      }

      final code = item['iso_code'];
      final name = item['name'];
      if (code is! String ||
          !_currencyCodePattern.hasMatch(code) ||
          name is! String ||
          name.trim().isEmpty ||
          name.length > 120) {
        throw const FormatException('A currency entry had invalid fields.');
      }
      if (!seenCodes.add(code)) {
        throw const FormatException('The currency list contained duplicates.');
      }
      currencies.add(CurrencyInfo(code: code, name: name.trim()));
    }

    if (currencies.isEmpty) {
      throw const FormatException('No supported currencies were returned.');
    }
    return List<CurrencyInfo>.unmodifiable(currencies);
  }

  Future<ExchangeRate> fetchRate(String base, String quote) async {
    if (!_currencyCodePattern.hasMatch(base) ||
        !_currencyCodePattern.hasMatch(quote)) {
      throw const FormatException('Currency codes must contain three letters.');
    }
    if (base == quote) {
      return ExchangeRate(rate: 1, date: DateTime.now().toUtc());
    }

    final cacheKey = '$base/$quote';
    final cached = _rateCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now().toUtc())) {
      _rateCache.remove(cacheKey);
      _rateCache[cacheKey] = cached;
      return cached.rate;
    }
    _rateCache.remove(cacheKey);

    final pending = _pendingRates[cacheKey];
    if (pending != null) return pending;

    final request = _fetchRate(base, quote);
    _pendingRates[cacheKey] = request;
    try {
      final rate = await request;
      if (_rateCache.length >= _maxCachedRates) {
        _rateCache.remove(_rateCache.keys.first);
      }
      _rateCache[cacheKey] = _CachedExchangeRate(
        rate: rate,
        expiresAt: DateTime.now().toUtc().add(_rateCacheDuration),
      );
      return rate;
    } finally {
      _pendingRates.remove(cacheKey);
    }
  }

  Future<ExchangeRate> _fetchRate(String base, String quote) async {
    final response = await _fetchJson(
      _endpoint(
        '/v2/rate/${Uri.encodeComponent(base)}/${Uri.encodeComponent(quote)}',
      ),
    );
    if (response is! Map<String, dynamic> ||
        response['base'] != base ||
        response['quote'] != quote) {
      throw const FormatException('The exchange-rate response was invalid.');
    }

    final rateValue = response['rate'];
    final rate = rateValue is num ? rateValue.toDouble() : null;
    final date = _parseDate(response['date']);
    if (rate == null || !rate.isFinite || rate <= 0 || date == null) {
      throw const FormatException('The exchange-rate response was incomplete.');
    }
    return ExchangeRate(rate: rate, date: date);
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }

    final date = DateTime.tryParse('${value}T00:00:00Z');
    if (date == null || date.toIso8601String().substring(0, 10) != value) {
      return null;
    }
    return date;
  }

  Uri _endpoint(String path) {
    final testBaseUri = _testBaseUri;
    return testBaseUri == null
        ? Uri.https('api.frankfurter.dev', path)
        : testBaseUri.resolve(path);
  }

  Future<dynamic> _fetchJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CurrencyServiceException(
          'Exchange-rate service returned HTTP ${response.statusCode}.',
        );
      }
      if (response.headers.contentType?.mimeType != 'application/json') {
        throw const FormatException(
          'The currency service response was not JSON.',
        );
      }
      if (response.contentLength > _maxResponseBytes) {
        throw const FormatException(
          'The currency service response was too large.',
        );
      }

      final bytes = await _readResponse(response).timeout(_timeout);
      return jsonDecode(utf8.decode(bytes));
    } on CurrencyServiceException {
      rethrow;
    } on TimeoutException {
      throw const CurrencyServiceException(
        'The currency service timed out. Check your internet connection.',
      );
    } on IOException {
      throw const CurrencyServiceException(
        'Could not reach the currency service. Check your internet connection.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> _readResponse(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (builder.length + chunk.length > _maxResponseBytes) {
        throw const FormatException(
          'The currency service response was too large.',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

class _CachedExchangeRate {
  const _CachedExchangeRate({required this.rate, required this.expiresAt});

  final ExchangeRate rate;
  final DateTime expiresAt;
}
