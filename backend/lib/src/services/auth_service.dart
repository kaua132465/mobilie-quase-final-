import 'dart:io';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../core/api_exception.dart';
import '../repositories/usuario_repository.dart';
import 'email_service.dart';

class AuthService {
  AuthService(this._usuarios, this._email);

  final UsuarioRepository _usuarios;
  final EmailService _email;

  String hashPassword(String password) {
    if (password.length < 8) {
      throw const ApiException(
        400,
        'A senha deve possuir no mínimo 8 caracteres.',
      );
    }
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  String generateTemporaryPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    final body = List.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'Ae@${body}';
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final account = await _usuarios.findAccountByEmail(
      email.trim().toLowerCase(),
    );
    if (account == null || account['ativo'] != true) {
      throw const ApiException(401, 'E-mail ou senha incorretos.');
    }

    final hash = account['senha_hash']?.toString() ?? '';
    if (!BCrypt.checkpw(password, hash)) {
      throw const ApiException(401, 'E-mail ou senha incorretos.');
    }

    final secret = Platform.environment['JWT_SECRET'];
    if (secret == null || secret.length < 16) {
      throw StateError('JWT_SECRET não configurado.');
    }

    final jwt = JWT({
      'sub': account['usuario_id'].toString(),
      'alunoId': account['aluno_id']?.toString(),
      'escolaId': account['escola_id']?.toString(),
      'perfil': account['perfil'].toString(),
    }, issuer: 'aether-api');

    final token = jwt.sign(
      SecretKey(secret),
      expiresIn: const Duration(hours: 8),
    );

    await _usuarios.recordLastAccess(account['usuario_id'].toString());

    return {
      'token': token,
      'tipo': 'Bearer',
      'expiraEmSegundos': 28800,
      'usuario': {
        'id': account['usuario_id'],
        'alunoId': account['aluno_id'],
        'escolaId': account['escola_id'],
        'nome': account['nome'],
        'email': account['email'],
        'perfil': account['perfil'],
      },
    };
  }

  Future<Map<String, dynamic>> requestPasswordRecovery(
    String email, {
    String? requesterIp,
  }) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw const ApiException(400, 'Informe um e-mail válido.');
    }
    final recovery = await _usuarios.createPasswordRecovery(
      email,
      requesterIp: requesterIp,
    );

    if (recovery != null && _email.isConfigured) {
      await _email.sendPasswordResetCode(
        recipientEmail: recovery.email,
        recipientName: recovery.name,
        code: recovery.code,
      );
    }

    final production =
        (Platform.environment['APP_ENV'] ?? '').toLowerCase() == 'production';
    return {
      'mensagem': 'Se o e-mail estiver cadastrado, um código será enviado.',
      'expiraEmMinutos': 15,
      if (!production && recovery != null && !_email.isConfigured)
        'codigoDesenvolvimento': recovery.code,
    };
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (email.trim().isEmpty || code.trim().length != 6) {
      throw const ApiException(400, 'Informe e-mail e código de seis dígitos.');
    }
    await _usuarios.resetPassword(
      email: email,
      code: code,
      passwordHash: hashPassword(newPassword),
    );
  }
}
