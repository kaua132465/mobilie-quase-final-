import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

import '../core/api_exception.dart';

Middleware jwtAuthentication() {
  final secret = Platform.environment['JWT_SECRET'];
  if (secret == null || secret.length < 16) {
    throw StateError('Defina JWT_SECRET com pelo menos 16 caracteres.');
  }

  return (Handler innerHandler) {
    return (Request request) async {
      final header = request.headers['authorization'];
      if (header == null || !header.startsWith('Bearer ')) {
        throw const ApiException(401, 'Token de acesso não informado.');
      }

      final token = header.substring(7).trim();
      try {
        final jwt = JWT.verify(token, SecretKey(secret));
        final payload = jwt.payload;
        if (payload is! Map) {
          throw const ApiException(401, 'Token inválido.');
        }
        final userId = payload['sub']?.toString();
        if (userId == null || userId.isEmpty) {
          throw const ApiException(401, 'Token sem identificação do usuário.');
        }
        return innerHandler(
          request.change(
            context: {
              'usuarioId': userId,
              'perfil': payload['perfil']?.toString(),
              'alunoId': payload['alunoId']?.toString(),
              'escolaId': payload['escolaId']?.toString(),
            },
          ),
        );
      } on JWTExpiredException {
        throw const ApiException(401, 'Token expirado.');
      } on JWTException {
        throw const ApiException(401, 'Token inválido.');
      }
    };
  };
}
