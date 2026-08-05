import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

final _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

Response jsonResponse(
  int statusCode,
  Object? data, {
  Map<String, String>? headers,
}) {
  return Response(
    statusCode,
    body: jsonEncode(
      data,
      toEncodable: (value) {
        if (value is DateTime) return value.toIso8601String();
        if (value is UndecodedBytes) return value.asString;
        return (value as dynamic).toJson();
      },
    ),
    headers: {..._jsonHeaders, ...?headers},
  );
}

Response ok(Object? data) => jsonResponse(200, data);
Response created(Object? data) => jsonResponse(201, data);
Response noContent() => Response(204);

Future<Map<String, dynamic>> readJsonObject(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('O corpo deve ser um objeto JSON.');
  }
  return decoded;
}

int parsePositiveInt(String? value, {required int fallback, int max = 100}) {
  final parsed = int.tryParse(value ?? '') ?? fallback;
  return parsed.clamp(1, max).toInt();
}
