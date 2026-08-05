import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../core/api_exception.dart';
import '../core/database.dart';

class EscolaRepository {
  EscolaRepository(this._database);

  final Database _database;

  Future<List<Map<String, dynamic>>> list({String? search}) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT e.id, e.nome, e.cnpj, e.codigo_inep, e.codigo_unidade, e.telefone,
               e.logradouro, e.numero, e.complemento, e.bairro,
               e.cidade, e.estado, e.cep, e.ativa,
               u.email,
               COUNT(DISTINCT a.id)::int AS atletas,
               COUNT(DISTINCT t.id)::int AS times
        FROM escola e
        LEFT JOIN usuario u ON u.id = e.usuario_id
        LEFT JOIN aluno a ON a.escola_id = e.id AND a.ativo = TRUE
        LEFT JOIN time_esportivo t ON t.escola_id = e.id AND t.ativo = TRUE
        WHERE e.ativa = TRUE
          AND (
            CAST(@busca AS text) IS NULL OR
            e.nome ILIKE '%' || CAST(@busca AS text) || '%' OR
            e.cidade ILIKE '%' || CAST(@busca AS text) || '%' OR
            e.codigo_inep ILIKE '%' || CAST(@busca AS text) || '%'
          )
        GROUP BY e.id, u.email
        ORDER BY e.nome
      '''),
      parameters: {
        'busca': search == null || search.trim().isEmpty ? null : search.trim(),
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> detail(String schoolId) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT e.id, e.usuario_id, e.nome, e.cnpj, e.codigo_inep,
               e.codigo_unidade,
               e.telefone, e.logradouro, e.numero, e.complemento,
               e.bairro, e.cidade, e.estado, e.cep, e.ativa,
               u.email, e.criado_em, e.atualizado_em,
               (SELECT COUNT(*)::int FROM aluno a
                 WHERE a.escola_id = e.id AND a.ativo = TRUE) AS atletas,
               (SELECT COUNT(*)::int FROM time_esportivo t
                 WHERE t.escola_id = e.id AND t.ativo = TRUE) AS times
        FROM escola e
        LEFT JOIN usuario u ON u.id = e.usuario_id
        WHERE e.id = @id AND e.ativa = TRUE
      '''),
      parameters: {'id': schoolId},
    );
    if (result.isEmpty) {
      throw const ApiException(404, 'Escola não encontrada.');
    }
    return result.single.toColumnMap();
  }

  Future<Map<String, dynamic>> findByCode(String code) async {
    if (!RegExp(r'^\d{3}$').hasMatch(code)) {
      throw const ApiException(400, 'O código da escola deve ter 3 dígitos.');
    }
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT id, codigo_unidade, nome
        FROM escola
        WHERE codigo_unidade = @codigo AND ativa = TRUE
        LIMIT 1
      '''),
      parameters: {'codigo': code},
    );
    if (result.isEmpty) {
      throw const ApiException(404, 'Código de escola não encontrado.');
    }
    return result.single.toColumnMap();
  }

  Future<Map<String, dynamic>> updateProfile(
    String schoolId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    const schoolColumns = <String, String>{
      'nome': 'nome',
      'telefone': 'telefone',
      'logradouro': 'logradouro',
      'endereco': 'logradouro',
      'numero': 'numero',
      'complemento': 'complemento',
      'bairro': 'bairro',
      'cidade': 'cidade',
      'estado': 'estado',
      'cep': 'cep',
    };

    final values = <String, dynamic>{};
    final assignments = <String>[];
    final usedColumns = <String>{};
    var index = 0;

    for (final entry in data.entries) {
      final column = schoolColumns[entry.key];
      if (column == null || usedColumns.contains(column)) continue;
      final parameter = 'valor$index';
      var value = entry.value?.toString().trim();
      if (entry.key == 'cep') value = value?.replaceAll(RegExp(r'\D'), '');
      if (entry.key == 'estado') value = value?.toUpperCase();
      assignments.add('$column = @$parameter');
      values[parameter] = value == null || value.isEmpty ? null : value;
      usedColumns.add(column);
      index++;
    }

    final email = data['email']?.toString().trim().toLowerCase();
    if (assignments.isEmpty && (email == null || email.isEmpty)) {
      throw const ApiException(400, 'Nenhum campo válido foi informado.');
    }
    if (email != null && email.isNotEmpty && !email.contains('@')) {
      throw const ApiException(400, 'Informe um e-mail válido.');
    }

    await _database.pool.runTx((tx) async {
      final current = await tx.execute(
        Sql.named('''
          SELECT e.usuario_id
          FROM escola e
          WHERE e.id = @id AND e.ativa = TRUE
          FOR UPDATE
        '''),
        parameters: {'id': schoolId},
      );
      if (current.isEmpty) {
        throw const ApiException(404, 'Escola não encontrada.');
      }

      if (assignments.isNotEmpty) {
        await tx.execute(
          Sql.named('''
            UPDATE escola
            SET ${assignments.join(', ')}, atualizado_em = NOW()
            WHERE id = @id
          '''),
          parameters: {...values, 'id': schoolId},
        );
      }

      final userId = current.single.toColumnMap()['usuario_id']?.toString();
      if (email != null && email.isNotEmpty && userId != null) {
        await tx.execute(
          Sql.named('''
            UPDATE usuario
            SET email = @email, atualizado_em = NOW()
            WHERE id = @usuarioId
          '''),
          parameters: {'email': email, 'usuarioId': userId},
        );
      }

      await tx.execute(
        Sql.named('''
          INSERT INTO log_auditoria
            (usuario_id, acao, entidade, entidade_id, dados_novos)
          VALUES
            (@usuarioId, 'ATUALIZAR_PERFIL', 'ESCOLA', @escolaId,
             CAST(@dados AS jsonb))
        '''),
        parameters: {
          'usuarioId': actorUserId,
          'escolaId': schoolId,
          'dados': jsonEncode(data),
        },
      );
    });

    return detail(schoolId);
  }

  Future<List<Map<String, dynamic>>> modalities() async {
    final result = await _database.pool.execute('''
      SELECT id, nome, tipo_pontuacao
      FROM modalidade
      WHERE ativa = TRUE
      ORDER BY nome
    ''');
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<List<Map<String, dynamic>>> categories() async {
    final result = await _database.pool.execute('''
      SELECT id, nome, idade_minima, idade_maxima, genero
      FROM categoria
      ORDER BY nome
    ''');
    return result.map((row) => row.toColumnMap()).toList();
  }
}
