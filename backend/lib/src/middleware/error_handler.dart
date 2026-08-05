import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../core/api_exception.dart';

Middleware errorHandler() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on ApiException catch (error) {
        return _jsonError(error.statusCode, error.message, error.details);
      } on FormatException catch (error) {
        return _jsonError(400, 'Dados inválidos.', error.message);
      } on ServerException catch (error) {
        // Não devolve dados sensíveis do PostgreSQL ao aplicativo.
        print('PostgreSQL: ${error.message}');
        if (error.code == '22P02') {
          return _jsonError(400, 'Identificador ou valor informado é inválido.');
        }
        if (error.code == '23505') {
          return _jsonError(409, 'Já existe um registro com esses dados.');
        }
        if (error.code == '23503') {
          return _jsonError(409, 'A operação referencia um registro inexistente.');
        }
        return _jsonError(500, 'Falha ao acessar o banco de dados.');
      } catch (error, stackTrace) {
        print(error);
        print(stackTrace);
        return _jsonError(500, 'Erro interno inesperado.');
      }
    };
  };
}

Response _jsonError(int status, String message, [Object? details]) {
  return Response(
    status,
    body: jsonEncode({
      'erro': message,
      if (details != null) 'detalhes': details,
    }),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
