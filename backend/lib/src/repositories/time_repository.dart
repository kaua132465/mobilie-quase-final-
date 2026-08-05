import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../core/api_exception.dart';
import '../core/database.dart';

class TimeRepository {
  TimeRepository(this._database);

  final Database _database;
  final Uuid _uuid = const Uuid();

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data,
    String schoolId,
    String actorUserId,
  ) async {
    final name = data['nome']?.toString().trim() ?? '';
    if (name.isEmpty) {
      throw const ApiException(400, 'Informe o nome do time.');
    }

    final id = _uuid.v4();
    final result = await _database.pool.execute(
      Sql.named('''
        INSERT INTO time_esportivo
          (id, escola_id, modalidade_id, categoria_id, nome, treinador, ativo)
        VALUES
          (@id, @escolaId, CAST(@modalidadeId AS uuid),
           CAST(@categoriaId AS uuid), @nome, @treinador, @ativo)
        RETURNING id
      '''),
      parameters: {
        'id': id,
        'escolaId': schoolId,
        'modalidadeId': _nullable(data['modalidadeId']),
        'categoriaId': _nullable(data['categoriaId']),
        'nome': name,
        'treinador': _nullable(data['tecnico'] ?? data['treinador']),
        'ativo': data['ativo'] != false,
      },
    );

    await _audit(actorUserId, 'CADASTRAR', id, data);
    return detail(result.single.toColumnMap()['id'].toString());
  }

  Future<List<Map<String, dynamic>>> list({
    String? search,
    String? schoolId,
    String? modalityId,
    String? categoryId,
    int page = 1,
    int limit = 30,
  }) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT t.id, t.nome, t.treinador, t.ativo,
               e.id AS escola_id, e.nome AS escola,
               m.id AS modalidade_id, m.nome AS modalidade,
               c.id AS categoria_id, c.nome AS categoria,
               COUNT(ta.aluno_id) FILTER (WHERE ta.ativo = TRUE)::int AS atletas,
               COUNT(ta.aluno_id) FILTER (
                 WHERE ta.ativo = TRUE AND ta.titular = TRUE
               )::int AS titulares
        FROM time_esportivo t
        JOIN escola e ON e.id = t.escola_id
        LEFT JOIN modalidade m ON m.id = t.modalidade_id
        LEFT JOIN categoria c ON c.id = t.categoria_id
        LEFT JOIN time_aluno ta ON ta.time_id = t.id
        WHERE t.ativo = TRUE
          AND (CAST(@escolaId AS uuid) IS NULL OR t.escola_id = CAST(@escolaId AS uuid))
          AND (CAST(@modalidadeId AS uuid) IS NULL OR t.modalidade_id = CAST(@modalidadeId AS uuid))
          AND (CAST(@categoriaId AS uuid) IS NULL OR t.categoria_id = CAST(@categoriaId AS uuid))
          AND (
            CAST(@busca AS text) IS NULL OR
            t.nome ILIKE '%' || CAST(@busca AS text) || '%' OR
            e.nome ILIKE '%' || CAST(@busca AS text) || '%'
          )
        GROUP BY t.id, e.id, m.id, c.id
        ORDER BY t.nome
        LIMIT @limite OFFSET @deslocamento
      '''),
      parameters: {
        'busca': search == null || search.trim().isEmpty ? null : search.trim(),
        'escolaId': _nullable(schoolId),
        'modalidadeId': _nullable(modalityId),
        'categoriaId': _nullable(categoryId),
        'limite': limit,
        'deslocamento': (page - 1) * limit,
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> detail(String teamId) async {
    final team = await _database.pool.execute(
      Sql.named('''
        SELECT t.id, t.nome, t.treinador, t.ativo,
               e.id AS escola_id, e.nome AS escola,
               m.id AS modalidade_id, m.nome AS modalidade,
               c.id AS categoria_id, c.nome AS categoria,
               t.criado_em, t.atualizado_em
        FROM time_esportivo t
        JOIN escola e ON e.id = t.escola_id
        LEFT JOIN modalidade m ON m.id = t.modalidade_id
        LEFT JOIN categoria c ON c.id = t.categoria_id
        WHERE t.id = @id AND t.ativo = TRUE
      '''),
      parameters: {'id': teamId},
    );
    if (team.isEmpty) {
      throw const ApiException(404, 'Time não encontrado.');
    }

    final athletes = await _database.pool.execute(
      Sql.named('''
        SELECT a.id AS aluno_id, u.nome, a.telefone, a.matricula,
               ta.numero_camisa, ta.posicao, ta.funcao,
               ta.capitao, ta.titular, ta.vinculado_em
        FROM time_aluno ta
        JOIN aluno a ON a.id = ta.aluno_id AND a.ativo = TRUE
        JOIN usuario u ON u.id = a.usuario_id
        WHERE ta.time_id = @id AND ta.ativo = TRUE
        ORDER BY ta.capitao DESC, ta.titular DESC, u.nome
      '''),
      parameters: {'id': teamId},
    );

    final data = team.single.toColumnMap();
    data['atletas'] = athletes.map((row) => row.toColumnMap()).toList();
    return data;
  }

  Future<Map<String, dynamic>> update(
    String teamId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    const columns = <String, String>{
      'nome': 'nome',
      'modalidadeId': 'modalidade_id',
      'categoriaId': 'categoria_id',
      'tecnico': 'treinador',
      'treinador': 'treinador',
      'ativo': 'ativo',
    };
    final assignments = <String>[];
    final params = <String, dynamic>{'id': teamId};
    final used = <String>{};
    var index = 0;

    for (final entry in data.entries) {
      final column = columns[entry.key];
      if (column == null || used.contains(column)) continue;
      final parameter = 'valor$index';
      if (column == 'modalidade_id' || column == 'categoria_id') {
        assignments.add('$column = CAST(@$parameter AS uuid)');
        params[parameter] = _nullable(entry.value);
      } else {
        assignments.add('$column = @$parameter');
        params[parameter] = entry.value;
      }
      used.add(column);
      index++;
    }

    if (assignments.isEmpty) {
      throw const ApiException(400, 'Nenhum campo válido foi informado.');
    }

    final result = await _database.pool.execute(
      Sql.named('''
        UPDATE time_esportivo
        SET ${assignments.join(', ')}, atualizado_em = NOW()
        WHERE id = @id AND ativo = TRUE
        RETURNING id
      '''),
      parameters: params,
    );
    if (result.isEmpty) {
      throw const ApiException(404, 'Time não encontrado.');
    }

    await _audit(actorUserId, 'EDITAR', teamId, data);
    return detail(teamId);
  }

  Future<Map<String, dynamic>> linkAthlete(
    String teamId,
    String athleteId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    await _database.pool.runTx((tx) async {
      final valid = await tx.execute(
        Sql.named('''
          SELECT 1
          FROM time_esportivo t
          JOIN aluno a ON a.id = @alunoId
          WHERE t.id = @timeId
            AND t.ativo = TRUE
            AND a.ativo = TRUE
            AND t.escola_id = a.escola_id
        '''),
        parameters: {'timeId': teamId, 'alunoId': athleteId},
      );
      if (valid.isEmpty) {
        throw const ApiException(
          409,
          'O time e o atleta devem pertencer à mesma escola.',
        );
      }

      await tx.execute(
        Sql.named('''
          INSERT INTO time_aluno
            (time_id, aluno_id, numero_camisa, posicao, funcao,
             capitao, titular, ativo, atualizado_em)
          VALUES
            (@timeId, @alunoId, @numero, @posicao, @funcao,
             FALSE, @titular, TRUE, NOW())
          ON CONFLICT (time_id, aluno_id) DO UPDATE SET
            numero_camisa = EXCLUDED.numero_camisa,
            posicao = EXCLUDED.posicao,
            funcao = EXCLUDED.funcao,
            titular = EXCLUDED.titular,
            ativo = TRUE,
            atualizado_em = NOW()
        '''),
        parameters: {
          'timeId': teamId,
          'alunoId': athleteId,
          'numero': _intOrNull(data['numeroCamisa']),
          'posicao': _nullable(data['posicao']),
          'funcao': _nullable(data['funcao']),
          'titular': data['titular'] == true,
        },
      );
    });

    await _audit(actorUserId, 'VINCULAR_ATLETA', teamId, {
      'alunoId': athleteId,
      ...data,
    });
    return detail(teamId);
  }

  Future<void> unlinkAthlete(
    String teamId,
    String athleteId,
    String actorUserId,
  ) async {
    final result = await _database.pool.execute(
      Sql.named('''
        UPDATE time_aluno
        SET ativo = FALSE, capitao = FALSE, titular = FALSE,
            atualizado_em = NOW()
        WHERE time_id = @timeId AND aluno_id = @alunoId AND ativo = TRUE
        RETURNING aluno_id
      '''),
      parameters: {'timeId': teamId, 'alunoId': athleteId},
    );
    if (result.isEmpty) {
      throw const ApiException(404, 'Atleta não está vinculado ao time.');
    }
    await _audit(actorUserId, 'REMOVER_ATLETA', teamId, {'alunoId': athleteId});
  }

  Future<Map<String, dynamic>> updateAthleteRole(
    String teamId,
    String athleteId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final result = await _database.pool.execute(
      Sql.named('''
        UPDATE time_aluno
        SET numero_camisa = COALESCE(CAST(@numero AS smallint), numero_camisa),
            posicao = COALESCE(CAST(@posicao AS text), posicao),
            funcao = COALESCE(CAST(@funcao AS text), funcao),
            titular = COALESCE(CAST(@titular AS boolean), titular),
            atualizado_em = NOW()
        WHERE time_id = @timeId AND aluno_id = @alunoId AND ativo = TRUE
        RETURNING aluno_id
      '''),
      parameters: {
        'timeId': teamId,
        'alunoId': athleteId,
        'numero': _intOrNull(data['numeroCamisa']),
        'posicao': _nullable(data['posicao']),
        'funcao': _nullable(data['funcao']),
        'titular': data.containsKey('titular') ? data['titular'] == true : null,
      },
    );
    if (result.isEmpty) {
      throw const ApiException(404, 'Atleta não está vinculado ao time.');
    }
    await _audit(actorUserId, 'REGISTRAR_FUNCAO', teamId, {
      'alunoId': athleteId,
      ...data,
    });
    return detail(teamId);
  }

  Future<Map<String, dynamic>> defineCaptain(
    String teamId,
    String athleteId,
    String actorUserId,
  ) async {
    await _database.pool.runTx((tx) async {
      final membership = await tx.execute(
        Sql.named('''
          SELECT 1 FROM time_aluno
          WHERE time_id = @timeId AND aluno_id = @alunoId AND ativo = TRUE
          FOR UPDATE
        '''),
        parameters: {'timeId': teamId, 'alunoId': athleteId},
      );
      if (membership.isEmpty) {
        throw const ApiException(404, 'Atleta não está vinculado ao time.');
      }
      await tx.execute(
        Sql.named('''
          UPDATE time_aluno
          SET capitao = (aluno_id = @alunoId), atualizado_em = NOW()
          WHERE time_id = @timeId AND ativo = TRUE
        '''),
        parameters: {'timeId': teamId, 'alunoId': athleteId},
      );
    });
    await _audit(actorUserId, 'DEFINIR_CAPITAO', teamId, {'alunoId': athleteId});
    return detail(teamId);
  }

  Future<Map<String, dynamic>> saveLineup(
    String teamId,
    List<dynamic> athletes,
    String actorUserId,
  ) async {
    final ids = athletes
        .whereType<Map>()
        .map((item) => item['alunoId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    await _database.pool.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          UPDATE time_aluno
          SET titular = FALSE, atualizado_em = NOW()
          WHERE time_id = @timeId AND ativo = TRUE
        '''),
        parameters: {'timeId': teamId},
      );

      for (final item in athletes.whereType<Map>()) {
        final athleteId = item['alunoId']?.toString();
        if (athleteId == null || athleteId.isEmpty) continue;
        final result = await tx.execute(
          Sql.named('''
            UPDATE time_aluno
            SET titular = TRUE,
                numero_camisa = COALESCE(CAST(@numero AS smallint), numero_camisa),
                posicao = COALESCE(CAST(@posicao AS text), posicao),
                funcao = COALESCE(CAST(@funcao AS text), funcao),
                atualizado_em = NOW()
            WHERE time_id = @timeId AND aluno_id = @alunoId AND ativo = TRUE
            RETURNING aluno_id
          '''),
          parameters: {
            'timeId': teamId,
            'alunoId': athleteId,
            'numero': _intOrNull(item['numeroCamisa']),
            'posicao': _nullable(item['posicao']),
            'funcao': _nullable(item['funcao']),
          },
        );
        if (result.isEmpty) {
          throw ApiException(409, 'Atleta $athleteId não pertence ao time.');
        }
      }
    });

    await _audit(actorUserId, 'ATUALIZAR_ESCALACAO', teamId, {'atletas': ids});
    return detail(teamId);
  }

  Future<Map<String, dynamic>> ranking(String teamId) async {
    final team = await detail(teamId);
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT COUNT(DISTINCT p.id)::int AS jogos,
               COUNT(DISTINCT p.id) FILTER (
                 WHERE (p.time_casa_id = @timeId AND p.placar_casa > p.placar_visitante)
                    OR (p.time_visitante_id = @timeId AND p.placar_visitante > p.placar_casa)
               )::int AS vitorias,
               COUNT(DISTINCT p.id) FILTER (
                 WHERE p.placar_casa = p.placar_visitante
               )::int AS empates,
               COALESCE(SUM(ev.valor) FILTER (WHERE ev.tipo = 'PONTUACAO'), 0)::int AS pontos_eventos
        FROM partida p
        LEFT JOIN evento_partida ev
          ON ev.partida_id = p.id AND ev.time_id = @timeId
        WHERE p.status = 'ENCERRADA'
          AND (p.time_casa_id = @timeId OR p.time_visitante_id = @timeId)
      '''),
      parameters: {'timeId': teamId},
    );
    return {
      'time': team,
      'desempenho': result.single.toColumnMap(),
    };
  }

  Future<void> _audit(
    String actorUserId,
    String action,
    String teamId,
    Map<String, dynamic> data,
  ) async {
    await _database.pool.execute(
      Sql.named('''
        INSERT INTO log_auditoria
          (usuario_id, acao, entidade, entidade_id, dados_novos)
        VALUES
          (@usuarioId, @acao, 'TIME', @timeId, CAST(@dados AS jsonb))
      '''),
      parameters: {
        'usuarioId': actorUserId,
        'acao': action,
        'timeId': teamId,
        'dados': jsonEncode(data),
      },
    );
  }

  String? _nullable(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _intOrNull(Object? value) => int.tryParse(value?.toString() ?? '');
}
