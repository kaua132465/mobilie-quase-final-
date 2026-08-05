import 'dart:convert';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../core/api_exception.dart';
import '../core/database.dart';

class AlunoRepository {
  AlunoRepository(this._database);

  final Database _database;
  final Uuid _uuid = const Uuid();

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data,
    String passwordHash,
    String actorUserId,
  ) async {
    final required = ['nome', 'email', 'cpf', 'dataNascimento', 'escolaId'];
    for (final field in required) {
      if (data[field] == null || data[field].toString().trim().isEmpty) {
        throw ApiException(400, 'Campo obrigatório não informado: $field.');
      }
    }

    final userId = _uuid.v4();
    final athleteId = _uuid.v4();
    final normalizedEmail = data['email'].toString().trim().toLowerCase();
    final normalizedCpf = data['cpf'].toString().replaceAll(RegExp(r'\D'), '');
    final birthDate = DateTime.tryParse(data['dataNascimento'].toString());
    final photo = _decodePhoto(data);

    if (!normalizedEmail.contains('@') || normalizedEmail.startsWith('@')) {
      throw const ApiException(400, 'Informe um e-mail válido.');
    }
    if (normalizedCpf.length != 11) {
      throw const ApiException(400, 'O CPF deve possuir 11 dígitos.');
    }
    if (birthDate == null || birthDate.isAfter(DateTime.now())) {
      throw const ApiException(400, 'Informe uma data de nascimento válida.');
    }

    try {
      return await _database.pool.runTx((tx) async {
        await tx.execute(
          Sql.named('''
            INSERT INTO usuario
              (id, nome, email, senha_hash, perfil, ativo)
            VALUES
              (@id, @nome, @email, @senhaHash, 'ALUNO', TRUE)
          '''),
          parameters: {
            'id': userId,
            'nome': data['nome'].toString().trim(),
            'email': normalizedEmail,
            'senhaHash': passwordHash,
          },
        );

        final result = await tx.execute(
          Sql.named('''
            INSERT INTO aluno
              (id, usuario_id, escola_id, cpf, data_nascimento, matricula,
               genero, telefone, foto, foto_mime_type, status_documentacao, ativo)
            VALUES
              (@id, @usuarioId, @escolaId, @cpf, @dataNascimento,
               @matricula, @genero, @telefone, @foto, @fotoMimeType, 'PENDENTE', TRUE)
            RETURNING id, usuario_id, escola_id, cpf, data_nascimento,
                      matricula, genero, telefone, status_documentacao, ativo,
                      criado_em
          '''),
          parameters: {
            'id': athleteId,
            'usuarioId': userId,
            'escolaId': data['escolaId'],
            'cpf': normalizedCpf,
            'dataNascimento': birthDate,
            'matricula': data['matricula'],
            'genero': data['genero'],
            'telefone': data['telefone'],
            'foto': photo,
            'fotoMimeType': photo == null ? null : data['fotoMimeType'],
          },
        );

        await tx.execute(
          Sql.named('''
            INSERT INTO log_auditoria
              (usuario_id, acao, entidade, entidade_id, dados_novos)
            VALUES
              (@usuarioId, 'CADASTRAR', 'ALUNO', @alunoId, CAST(@dados AS jsonb))
          '''),
          parameters: {
            'usuarioId': actorUserId,
            'alunoId': athleteId,
            'dados': jsonEncode({
              'email': normalizedEmail,
              'cpf': normalizedCpf,
            }),
          },
        );

        return result.single.toColumnMap();
      });
    } on ServerException catch (error) {
      if (error.code == '23505') {
        throw const ApiException(409, 'CPF ou e-mail já cadastrado.');
      }
      if (error.code == '23503') {
        throw const ApiException(409, 'A escola informada não existe.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> findAccountByEmail(String email) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT u.id AS usuario_id, a.id AS aluno_id, u.nome, u.email,
               u.senha_hash, u.perfil, u.ativo
        FROM usuario u
        LEFT JOIN aluno a ON a.usuario_id = u.id
        WHERE LOWER(u.email) = LOWER(@email)
          AND (a.id IS NULL OR a.ativo = TRUE)
        LIMIT 1
      '''),
      parameters: {'email': email},
    );
    return result.isEmpty ? null : result.single.toColumnMap();
  }

  Future<void> recordLastAccess(String userId) async {
    await _database.pool.execute(
      Sql.named('UPDATE usuario SET ultimo_acesso = NOW() WHERE id = @id'),
      parameters: {'id': userId},
    );
  }

  Future<List<Map<String, dynamic>>> list({
    String? search,
    String? schoolId,
    required int page,
    required int limit,
  }) async {
    final offset = (page - 1) * limit;
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT a.id, u.nome, u.email, a.cpf, a.data_nascimento,
               a.matricula, a.genero, a.telefone, a.status_documentacao,
               e.id AS escola_id, e.nome AS escola_nome,
               e.codigo_unidade AS escola_codigo, a.criado_em,
               replace(encode(a.foto, 'base64'), chr(10), '') AS foto_base64,
               a.foto_mime_type
        FROM aluno a
        JOIN usuario u ON u.id = a.usuario_id
        JOIN escola e ON e.id = a.escola_id
        WHERE a.ativo = TRUE
          AND (
            CAST(@busca AS text) IS NULL OR
            u.nome ILIKE '%' || CAST(@busca AS text) || '%' OR
            u.email ILIKE '%' || CAST(@busca AS text) || '%' OR
            a.cpf ILIKE '%' || CAST(@busca AS text) || '%'
          )
          AND (CAST(@escolaId AS uuid) IS NULL OR a.escola_id = CAST(@escolaId AS uuid))
        ORDER BY u.nome
        LIMIT @limite OFFSET @deslocamento
      '''),
      parameters: {
        'busca': search?.trim().isEmpty == true ? null : search,
        'escolaId': schoolId?.trim().isEmpty == true ? null : schoolId,
        'limite': limit,
        'deslocamento': offset,
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> detail(String athleteId) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT a.id, a.usuario_id, u.nome, u.email, a.cpf,
               a.data_nascimento, a.matricula, a.genero, a.telefone,
               a.status_documentacao, a.ativo, a.criado_em, a.atualizado_em,
               e.id AS escola_id, e.nome AS escola_nome,
               e.codigo_unidade AS escola_codigo,
               replace(encode(a.foto, 'base64'), chr(10), '') AS foto_base64,
               a.foto_mime_type
        FROM aluno a
        JOIN usuario u ON u.id = a.usuario_id
        JOIN escola e ON e.id = a.escola_id
        WHERE a.id = @id AND a.ativo = TRUE
      '''),
      parameters: {'id': athleteId},
    );
    if (result.isEmpty) {
      throw const ApiException(404, 'Aluno não encontrado.');
    }
    return result.single.toColumnMap();
  }

  Future<Map<String, dynamic>> update(
    String athleteId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final current = await detail(athleteId);
    final email = data['email']?.toString().trim().toLowerCase();
    if (email != null && (email.isEmpty || !email.contains('@'))) {
      throw const ApiException(400, 'Informe um e-mail válido.');
    }
    final cpf = data.containsKey('cpf')
        ? data['cpf']?.toString().replaceAll(RegExp(r'\D'), '')
        : null;
    if (cpf != null && cpf.length != 11) {
      throw const ApiException(400, 'O CPF deve possuir 11 dígitos.');
    }
    final birthDate = data.containsKey('dataNascimento')
        ? DateTime.tryParse(data['dataNascimento']?.toString() ?? '')
        : null;
    final photo = data.containsKey('fotoBase64') ? _decodePhoto(data) : null;
    if (data.containsKey('dataNascimento') &&
        (birthDate == null || birthDate.isAfter(DateTime.now()))) {
      throw const ApiException(400, 'Informe uma data de nascimento válida.');
    }
    try {
      return await _database.pool.runTx((tx) async {
        await tx.execute(
          Sql.named('''
            UPDATE usuario
            SET nome = COALESCE(@nome, nome),
                email = COALESCE(@email, email),
                atualizado_em = NOW()
            WHERE id = @usuarioId
          '''),
          parameters: {
            'nome': data['nome'],
            'email': email,
            'usuarioId': current['usuario_id'],
          },
        );

        final result = await tx.execute(
          Sql.named('''
            UPDATE aluno
            SET escola_id = COALESCE(CAST(@escolaId AS uuid), escola_id),
                cpf = COALESCE(@cpf, cpf),
                data_nascimento = COALESCE(CAST(@dataNascimento AS date), data_nascimento),
                matricula = COALESCE(@matricula, matricula),
                genero = COALESCE(@genero, genero),
                telefone = COALESCE(@telefone, telefone),
                foto = CASE WHEN @alterarFoto THEN @foto ELSE foto END,
                foto_mime_type = CASE WHEN @alterarFoto THEN @fotoMimeType ELSE foto_mime_type END,
                atualizado_em = NOW()
            WHERE id = @id AND ativo = TRUE
            RETURNING id, usuario_id, escola_id, cpf, data_nascimento,
                      matricula, genero, telefone, status_documentacao,
                      ativo, atualizado_em
          '''),
          parameters: {
            'id': athleteId,
            'escolaId': data['escolaId'],
            'cpf': cpf,
            'dataNascimento': birthDate,
            'matricula': data['matricula'],
            'genero': data['genero'],
            'telefone': data['telefone'],
            'alterarFoto': data.containsKey('fotoBase64'),
            'foto': photo,
            'fotoMimeType': photo == null ? null : data['fotoMimeType'],
          },
        );

        if (result.isEmpty) {
          throw const ApiException(404, 'Aluno não encontrado.');
        }

        await tx.execute(
          Sql.named('''
            INSERT INTO log_auditoria
              (usuario_id, acao, entidade, entidade_id, dados_anteriores, dados_novos)
            VALUES
              (@usuarioId, 'EDITAR', 'ALUNO', @alunoId,
               CAST(@anteriores AS jsonb), CAST(@novos AS jsonb))
          '''),
          parameters: {
            'usuarioId': actorUserId,
            'alunoId': athleteId,
            'anteriores': _jsonSafe(current),
            'novos': _jsonSafe(data),
          },
        );

        return result.single.toColumnMap();
      });
    } on ServerException catch (error) {
      if (error.code == '23505') {
        throw const ApiException(
          409,
          'O CPF ou e-mail informado já está em uso.',
        );
      }
      if (error.code == '23503') {
        throw const ApiException(409, 'A escola informada não existe.');
      }
      rethrow;
    }
  }

  Future<void> softDelete(String athleteId, String actorUserId) async {
    final current = await detail(athleteId);
    await _database.pool.runTx((tx) async {
      final activeEnrollment = await tx.execute(
        Sql.named('''
          SELECT 1
          FROM time_aluno ta
          JOIN time_esportivo t ON t.id = ta.time_id
          WHERE ta.aluno_id = @id
            AND ta.ativo = TRUE
            AND t.ativo = TRUE
          LIMIT 1
        '''),
        parameters: {'id': athleteId},
      );
      if (activeEnrollment.isNotEmpty) {
        throw const ApiException(
          409,
          'O aluno está vinculado a um time ativo. Remova o vínculo antes da exclusão.',
        );
      }

      await tx.execute(
        Sql.named(
          'UPDATE aluno SET ativo = FALSE, atualizado_em = NOW() WHERE id = @id',
        ),
        parameters: {'id': athleteId},
      );
      await tx.execute(
        Sql.named(
          'UPDATE usuario SET ativo = FALSE, atualizado_em = NOW() WHERE id = @usuarioId',
        ),
        parameters: {'usuarioId': current['usuario_id']},
      );

      await tx.execute(
        Sql.named('''
          INSERT INTO log_auditoria
            (usuario_id, acao, entidade, entidade_id, dados_anteriores)
          VALUES
            (@usuarioId, 'EXCLUIR', 'ALUNO', @alunoId, CAST(@dados AS jsonb))
        '''),
        parameters: {
          'usuarioId': actorUserId,
          'alunoId': athleteId,
          'dados': _jsonSafe(current),
        },
      );
    });
  }

  Future<List<Map<String, dynamic>>> history(String athleteId) async {
    await detail(athleteId);
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT p.id AS partida_id, c.nome AS competicao, m.nome AS modalidade,
               p.data_hora, p.status, tc.nome AS time_casa, tv.nome AS time_visitante,
               p.placar_casa, p.placar_visitante,
               COALESCE(pa.pontos, 0) AS pontos_do_atleta,
               COALESCE(pa.assistencias, 0) AS assistencias,
               COALESCE(pa.faltas, 0) AS faltas
        FROM participacao_atleta pa
        JOIN partida p ON p.id = pa.partida_id
        JOIN competicao c ON c.id = p.competicao_id
        LEFT JOIN modalidade m ON m.id = c.modalidade_id
        JOIN time_esportivo tc ON tc.id = p.time_casa_id
        JOIN time_esportivo tv ON tv.id = p.time_visitante_id
        WHERE pa.aluno_id = @alunoId
        ORDER BY p.data_hora DESC
      '''),
      parameters: {'alunoId': athleteId},
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> statistics(String athleteId) async {
    await detail(athleteId);
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT COUNT(DISTINCT pa.partida_id)::int AS partidas,
               COALESCE(SUM(pa.pontos), 0)::int AS pontos,
               COALESCE(SUM(pa.assistencias), 0)::int AS assistencias,
               COALESCE(SUM(pa.faltas), 0)::int AS faltas,
               COALESCE(SUM(pa.cartoes_amarelos), 0)::int AS cartoes_amarelos,
               COALESCE(SUM(pa.cartoes_vermelhos), 0)::int AS cartoes_vermelhos,
               COALESCE(ROUND(AVG(pa.nota)::numeric, 2), 0) AS media_nota
        FROM participacao_atleta pa
        WHERE pa.aluno_id = @alunoId
      '''),
      parameters: {'alunoId': athleteId},
    );
    return result.single.toColumnMap();
  }

  Future<List<Map<String, dynamic>>> ranking({
    String? competitionId,
    String? modalityId,
    required int limit,
  }) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT a.id AS aluno_id, u.nome AS atleta, e.nome AS escola,
               COUNT(DISTINCT pa.partida_id)::int AS partidas,
               COALESCE(SUM(pa.pontos), 0)::int AS pontos,
               COALESCE(SUM(pa.assistencias), 0)::int AS assistencias,
               COALESCE(ROUND(AVG(pa.nota)::numeric, 2), 0) AS media_nota,
               DENSE_RANK() OVER (
                 ORDER BY COALESCE(SUM(pa.pontos), 0) DESC,
                          COALESCE(AVG(pa.nota), 0) DESC,
                          u.nome ASC
               )::int AS posicao
        FROM aluno a
        JOIN usuario u ON u.id = a.usuario_id
        JOIN escola e ON e.id = a.escola_id
        JOIN participacao_atleta pa ON pa.aluno_id = a.id
        JOIN partida p ON p.id = pa.partida_id
        JOIN competicao c ON c.id = p.competicao_id
        WHERE a.ativo = TRUE
          AND (CAST(@competicaoId AS uuid) IS NULL OR c.id = CAST(@competicaoId AS uuid))
          AND (CAST(@modalidadeId AS uuid) IS NULL OR c.modalidade_id = CAST(@modalidadeId AS uuid))
        GROUP BY a.id, u.nome, e.nome
        ORDER BY posicao
        LIMIT @limite
      '''),
      parameters: {
        'competicaoId': competitionId,
        'modalidadeId': modalityId,
        'limite': limit,
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  String _jsonSafe(Object? value) {
    return jsonEncode(
      value,
      toEncodable: (object) {
        if (object is DateTime) return object.toIso8601String();
        return object.toString();
      },
    );
  }

  Uint8List? _decodePhoto(Map<String, dynamic> data) {
    final encoded = data['fotoBase64']?.toString();
    if (encoded == null || encoded.isEmpty) return null;
    final mimeType = data['fotoMimeType']?.toString().toLowerCase();
    if (mimeType != 'image/jpeg' && mimeType != 'image/png') {
      throw const ApiException(400, 'A foto deve estar no formato JPG ou PNG.');
    }
    try {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
        throw const ApiException(400, 'A foto deve ter no máximo 4 MB.');
      }
      return bytes;
    } on FormatException {
      throw const ApiException(400, 'A foto enviada é inválida.');
    }
  }
}
