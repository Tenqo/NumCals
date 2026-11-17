import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:numcals/features/currency/currency_service.dart';

void main() {
  test('parses currencies and excludes non-fiat entries', () async {
    final server = await _TestServer.start((request) async {
      await _respondJson(request, [
        {'type': 'crypto', 'iso_code': 'BTC', 'name': 'Bitcoin'},
        {'type': 'currency', 'iso_code': 'USD', 'name': 'US Dollar'},
        {'type': 'currency', 'iso_code': 'EUR', 'name': 'Euro'},
      ]);
    });
    addTearDown(server.close);

    final currencies = await CurrencyService.forTesting(baseUri: server.baseUri)
        .fetchCurrencies();

    expect(currencies.map((currency) => currency.code), ['USD', 'EUR']);
    expect(currencies.first.name, 'US Dollar');
  });

  test('rejects malformed JSON and malformed currency entries', () async {
    final malformedJsonServer = await _TestServer.start((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{not json');
      await request.response.close();
    });
    addTearDown(malformedJsonServer.close);

    await expectLater(
      CurrencyService.forTesting(baseUri: malformedJsonServer.baseUri)
          .fetchCurrencies(),
      throwsFormatException,
    );

    final malformedEntryServer = await _TestServer.start((request) async {
      await _respondJson(request, [
        {'type': 'currency', 'iso_code': 'USDX', 'name': 'Invalid code'},
      ]);
    });
    addTearDown(malformedEntryServer.close);

    await expectLater(
      CurrencyService.forTesting(baseUri: malformedEntryServer.baseUri)
          .fetchCurrencies(),
      throwsFormatException,
    );
  });

  test('rejects duplicate currency codes', () async {
    final server = await _TestServer.start((request) async {
      await _respondJson(request, [
        {'type': 'currency', 'iso_code': 'USD', 'name': 'US Dollar'},
        {'type': 'currency', 'iso_code': 'USD', 'name': 'Duplicate'},
      ]);
    });
    addTearDown(server.close);

    await expectLater(
      CurrencyService.forTesting(baseUri: server.baseUri).fetchCurrencies(),
      throwsFormatException,
    );
  });

  test('rejects oversized streamed responses', () async {
    final server = await _TestServer.start((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(' ' * (300 * 1024));
      await request.response.close();
    });
    addTearDown(server.close);

    await expectLater(
      CurrencyService.forTesting(baseUri: server.baseUri).fetchCurrencies(),
      throwsFormatException,
    );
  });

  test('rejects HTTP errors and does not follow redirects', () async {
    var requestCount = 0;
    final server = await _TestServer.start((request) async {
      requestCount++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        'https://example.com/untrusted',
      );
      await request.response.close();
    });
    addTearDown(server.close);

    await expectLater(
      CurrencyService.forTesting(baseUri: server.baseUri).fetchCurrencies(),
      throwsA(isA<CurrencyServiceException>()),
    );
    expect(requestCount, 1);

    final errorServer = await _TestServer.start((request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
    });
    addTearDown(errorServer.close);

    await expectLater(
      CurrencyService.forTesting(baseUri: errorServer.baseUri)
          .fetchCurrencies(),
      throwsA(isA<CurrencyServiceException>()),
    );
  });

  test('bounds network timeouts', () async {
    final releaseResponse = Completer<void>();
    final server = await _TestServer.start((request) async {
      await releaseResponse.future;
    });
    addTearDown(() async {
      if (!releaseResponse.isCompleted) releaseResponse.complete();
      await server.close();
    });

    await expectLater(
      CurrencyService.forTesting(
        baseUri: server.baseUri,
        timeout: const Duration(milliseconds: 50),
      ).fetchCurrencies(),
      throwsA(isA<CurrencyServiceException>()),
    );
  });

  test('validates rate codes and returned rate data', () async {
    var requestCount = 0;
    final server = await _TestServer.start((request) async {
      requestCount++;
      await _respondJson(request, {
        'date': '2026-11-15',
        'base': 'USD',
        'quote': 'EUR',
        'rate': 0.9,
      });
    });
    addTearDown(server.close);
    final service = CurrencyService.forTesting(baseUri: server.baseUri);

    await expectLater(service.fetchRate('USDX', 'EUR'), throwsFormatException);
    expect(requestCount, 0);

    final rates = await Future.wait([
      service.fetchRate('USD', 'EUR'),
      service.fetchRate('USD', 'EUR'),
    ]);
    final rate = rates.first;
    expect(rate.rate, 0.9);
    expect(rate.date, DateTime.utc(2026, 11, 15));
    expect(rates.last.rate, rate.rate);
    await service.fetchRate('USD', 'EUR');
    expect(requestCount, 1);

    final invalidDateServer = await _TestServer.start((request) async {
      await _respondJson(request, {
        'date': '2026-02-31',
        'base': 'USD',
        'quote': 'EUR',
        'rate': 0.9,
      });
    });
    addTearDown(invalidDateServer.close);

    await expectLater(
      CurrencyService.forTesting(baseUri: invalidDateServer.baseUri)
          .fetchRate('USD', 'EUR'),
      throwsFormatException,
    );
  });
}

Future<void> _respondJson(HttpRequest request, Object value) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(value));
  await request.response.close();
}

class _TestServer {
  _TestServer(this._server, this._subscription);

  final HttpServer _server;
  final StreamSubscription<HttpRequest> _subscription;

  Uri get baseUri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: _server.port,
  );

  static Future<_TestServer> start(
    Future<void> Function(HttpRequest) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      unawaited(handler(request));
    });
    return _TestServer(server, subscription);
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }
}
