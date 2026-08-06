import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import '../core/api_exception.dart';
import '../core/database.dart';

class UsuarioRepository {
  UsuarioRepository(this._database);

  final Database _database;

  Future<Map<String, dynamic>?> findAccountByEmail(String email) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT u.id AS usuario_id, u.nome, u.email, u.senha_hash,
               u.perfil::text AS perfil, u.ativo,
               a.id AS aluno_id,
               COALESCE(a.escola_id, e.id) AS escola_id
        FROM usuario u
        LEFT JOIN aluno a
          ON a.usuario_id = u.id AND a.ativo = TRUE
        LEFT JOIN escola e
          ON e.usuario_id = u.id AND e.ativa = TRUE
        WHERE LOWER(u.email) = LOWER(@email)
        LIMIT 1
      '''),
      parameters: {'email': email.trim().toLowerCase()},
    );
    return result.isEmpty ? null : result.single.toColumnMap();
  }

  Future<void> recordLastAccess(String userId) async {
    await _database.pool.execute(
      Sql.named('''
        UPDATE usuario
        SET ultimo_acesso = NOW(), atualizado_em = NOW()
        WHERE id = @id
      '''),
      parameters: {'id': userId},
    );
  }

  Future<PasswordRecoveryData?> createPasswordRecovery(
    String email, {
    String? requesterIp,
  }) async {
    final account = await findAccountByEmail(email);

    // A resposta pública é sempre genérica para não revelar se o e-mail existe.
    if (account == null || account['ativo'] != true) return null;

    final code = _generateCode();
    final hash = _hashCode(code);
    final userId = account['usuario_id'].toString();

    await _database.pool.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          UPDATE recuperacao_senha
          SET usado_em = NOW()
          WHERE usuario_id = @usuarioId AND usado_em IS NULL
        '''),
        parameters: {'usuarioId': userId},
      );

      await tx.execute(
        Sql.named('''
          INSERT INTO recuperacao_senha
            (usuario_id, codigo_hash, expira_em, ip_solicitante)
          VALUES
            (@usuarioId, @codigoHash, NOW() + INTERVAL '15 minutes',
             CAST(@ip AS inet))
        '''),
        parameters: {
          'usuarioId': userId,
          'codigoHash': hash,
          'ip': requesterIp,
        },
      );
    });

    return PasswordRecoveryData(
      email: account['email'].toString(),
      name: account['nome'].toString(),
      code: code,
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String passwordHash,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final codeHash = _hashCode(code.trim());

    await _database.pool.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
          SELECT r.id, r.usuario_id
          FROM recuperacao_senha r
          JOIN usuario u ON u.id = r.usuario_id
          WHERE LOWER(u.email) = LOWER(@email)
            AND r.codigo_hash = @codigoHash
            AND r.usado_em IS NULL
            AND r.expira_em > NOW()
            AND u.ativo = TRUE
          ORDER BY r.solicitado_em DESC
          LIMIT 1
          FOR UPDATE
        '''),
        parameters: {'email': normalizedEmail, 'codigoHash': codeHash},
      );

      if (result.isEmpty) {
        throw const ApiException(400, 'Código inválido ou expirado.');
      }

      final row = result.single.toColumnMap();
      await tx.execute(
        Sql.named('''
          UPDATE usuario
          SET senha_hash = @senhaHash, atualizado_em = NOW()
          WHERE id = @usuarioId
        '''),
        parameters: {'senhaHash': passwordHash, 'usuarioId': row['usuario_id']},
      );

      await tx.execute(
        Sql.named('''
          UPDATE recuperacao_senha
          SET usado_em = NOW()
          WHERE id = @id
        '''),
        parameters: {'id': row['id']},
      );
    });
  }

  String _generateCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _hashCode(String code) => sha256.convert(utf8.encode(code)).toString();
}

class PasswordRecoveryData {
  const PasswordRecoveryData({
    required this.email,
    required this.name,
    required this.code,
  });

  final String email;
  final String name;
  final String code;
}
