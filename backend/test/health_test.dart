import 'dart:convert';
import 'dart:typed_data';

import 'package:aether_backend/src/core/api_exception.dart';
import 'package:aether_backend/src/core/http_helpers.dart';
import 'package:aether_backend/src/middleware/error_handler.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('http_helpers', () {
    test('parsePositiveInt aplica fallback e limites', () {
      expect(parsePositiveInt(null, fallback: 20), 20);
      expect(parsePositiveInt('0', fallback: 20), 1);
      expect(parsePositiveInt('999', fallback: 20, max: 100), 100);
      expect(parsePositiveInt('15', fallback: 20), 15);
    });

    test('readJsonObject lê objeto JSON', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/teste'),
        body: jsonEncode({'nome': 'Aether'}),
      );
      expect(await readJsonObject(request), {'nome': 'Aether'});
    });

    test('readJsonObject rejeita array JSON', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/teste'),
        body: jsonEncode([1, 2, 3]),
      );
      await expectLater(
        readJsonObject(request),
        throwsA(isA<FormatException>()),
      );
    });

    test('jsonResponse converte datas para ISO 8601', () async {
      final date = DateTime.utc(2026, 7, 28, 17, 30);
      final response = jsonResponse(200, {
        'itens': [
          {'data': date},
        ],
      });
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect((body['itens'] as List).first, {
        'data': '2026-07-28T17:30:00.000Z',
      });
    });

    test(
      'jsonResponse decodifica tipos personalizados do PostgreSQL',
      () async {
        final value = UndecodedBytes(
          typeOid: 12345,
          isBinary: false,
          bytes: Uint8List.fromList(utf8.encode('EM_ANDAMENTO')),
          encoding: utf8,
        );
        final response = jsonResponse(200, {'status': value});
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['status'], 'EM_ANDAMENTO');
      },
    );
  });

  test('errorHandler converte ApiException em resposta JSON', () async {
    final handler = errorHandler()((request) async {
      throw const ApiException(409, 'Conflito de teste.');
    });
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/teste')),
    );
    expect(response.statusCode, 409);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['erro'], 'Conflito de teste.');
  });
}
