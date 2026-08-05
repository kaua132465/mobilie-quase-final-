import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';

import '../core/api_exception.dart';
import '../core/database.dart';

class CompeticaoRepository {
  CompeticaoRepository(this._database);

  final Database _database;

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final name = data['nome']?.toString().trim() ?? '';
    final start = _date(data['dataInicio'], field: 'dataInicio');
    final end = _date(data['dataFim'], field: 'dataFim');
    if (name.length < 3) {
      throw const ApiException(400, 'Informe o nome da competição.');
    }
    if (start != null && end != null && end.isBefore(start)) {
      throw const ApiException(400, 'A data final não pode anteceder a inicial.');
    }

    return _database.pool.runTx((tx) async {
      final duplicate = await tx.execute(
        Sql.named('''
          SELECT 1
          FROM competicao
          WHERE ativo = TRUE
            AND LOWER(nome) = LOWER(@nome)
            AND (
              CAST(@inicio AS date) IS NULL OR CAST(@fim AS date) IS NULL OR
              daterange(data_inicio, data_fim, '[]') &&
              daterange(CAST(@inicio AS date), CAST(@fim AS date), '[]')
            )
          LIMIT 1
        '''),
        parameters: {'nome': name, 'inicio': start, 'fim': end},
      );
      if (duplicate.isNotEmpty) {
        throw const ApiException(409, 'Já existe uma competição semelhante no período.');
      }

      final result = await tx.execute(
        Sql.named('''
          INSERT INTO competicao
            (modalidade_id, categoria_id, organizador_id, nome, descricao,
             tipo, abrangencia, formato, status, limite_times, data_inicio,
             data_fim, data_limite_inscricao, ativo)
          VALUES
            (CAST(@modalidadeId AS uuid), CAST(@categoriaId AS uuid), @usuarioId,
             @nome, @descricao, @tipo, @abrangencia, @formato, 'PLANEJADA',
             @limiteTimes, CAST(@inicio AS date), CAST(@fim AS date),
             CAST(@limiteInscricao AS timestamptz), TRUE)
          RETURNING id, nome, descricao, tipo, abrangencia, formato, status,
                    limite_times, data_inicio, data_fim, data_limite_inscricao,
                    criado_em
        '''),
        parameters: {
          'modalidadeId': data['modalidadeId'],
          'categoriaId': data['categoriaId'],
          'usuarioId': actorUserId,
          'nome': name,
          'descricao': data['descricao'],
          'tipo': data['tipo']?.toString().trim().toUpperCase() ?? 'COMPETICAO',
          'abrangencia': data['abrangencia'],
          'formato': data['formato']?.toString().trim().toUpperCase() ?? 'PONTOS_CORRIDOS',
          'limiteTimes': int.tryParse(data['limiteTimes']?.toString() ?? ''),
          'inicio': start,
          'fim': end,
          'limiteInscricao': _dateTime(data['dataLimiteInscricao'], field: 'dataLimiteInscricao'),
        },
      );
      final competition = result.single.toColumnMap();
      final competitionId = competition['id'].toString();

      if (data['modalidadeId'] != null) {
        await tx.execute(
          Sql.named('''
            INSERT INTO competicao_modalidade
              (competicao_id, modalidade_id, limite_times)
            VALUES (@competicaoId, @modalidadeId, @limiteTimes)
            ON CONFLICT (competicao_id, modalidade_id) DO NOTHING
          '''),
          parameters: {
            'competicaoId': competitionId,
            'modalidadeId': data['modalidadeId'],
            'limiteTimes': data['limiteTimes'],
          },
        );
      }
      if (data['categoriaId'] != null) {
        await tx.execute(
          Sql.named('''
            INSERT INTO competicao_categoria (competicao_id, categoria_id)
            VALUES (@competicaoId, @categoriaId)
            ON CONFLICT (competicao_id, categoria_id) DO NOTHING
          '''),
          parameters: {
            'competicaoId': competitionId,
            'categoriaId': data['categoriaId'],
          },
        );
      }
      await _audit(tx, actorUserId, 'CRIAR_COMPETICAO', 'COMPETICAO', competitionId, competition);
      return competition;
    });
  }

  Future<List<Map<String, dynamic>>> list({
    String? search,
    String? status,
    String? modalityId,
    DateTime? from,
    DateTime? to,
    required int page,
    required int limit,
  }) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT c.id, c.nome, c.descricao, c.tipo, c.abrangencia, c.formato,
               c.status, c.data_inicio, c.data_fim, c.data_limite_inscricao,
               c.limite_times, c.criado_em,
               COUNT(DISTINCT i.time_id) FILTER (WHERE i.status = 'ATIVA')::int AS times_inscritos,
               COUNT(DISTINCT p.id)::int AS partidas
        FROM competicao c
        LEFT JOIN inscricao_competicao i ON i.competicao_id = c.id
        LEFT JOIN partida p ON p.competicao_id = c.id
        WHERE c.ativo = TRUE
          AND (CAST(@busca AS text) IS NULL OR
               c.nome ILIKE '%' || CAST(@busca AS text) || '%' OR
               c.descricao ILIKE '%' || CAST(@busca AS text) || '%')
          AND (CAST(@status AS status_competicao) IS NULL OR c.status = CAST(@status AS status_competicao))
          AND (
            CAST(@modalidadeId AS uuid) IS NULL OR
            c.modalidade_id = CAST(@modalidadeId AS uuid) OR EXISTS (
              SELECT 1 FROM competicao_modalidade cm
              WHERE cm.competicao_id = c.id AND cm.modalidade_id = CAST(@modalidadeId AS uuid)
                AND cm.ativa = TRUE
            )
          )
          AND (CAST(@de AS date) IS NULL OR c.data_fim >= CAST(@de AS date))
          AND (CAST(@ate AS date) IS NULL OR c.data_inicio <= CAST(@ate AS date))
        GROUP BY c.id
        ORDER BY c.data_inicio DESC NULLS LAST, c.nome
        LIMIT @limite OFFSET @deslocamento
      '''),
      parameters: {
        'busca': search?.trim().isEmpty == true ? null : search,
        'status': status?.trim().isEmpty == true ? null : status?.trim().toUpperCase(),
        'modalidadeId': modalityId,
        'de': from,
        'ate': to,
        'limite': limit,
        'deslocamento': (page - 1) * limit,
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> detail(String competitionId) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT c.*, u.nome AS organizador
        FROM competicao c
        JOIN usuario u ON u.id = c.organizador_id
        WHERE c.id = @id AND c.ativo = TRUE
      '''),
      parameters: {'id': competitionId},
    );
    if (result.isEmpty) {
      throw const ApiException(404, 'Competição não encontrada.');
    }

    final modalities = await _database.pool.execute(
      Sql.named('''
        SELECT cm.id, m.id AS modalidade_id, m.nome, cm.jogadores_min,
               cm.jogadores_max, cm.limite_times, cm.regras
        FROM competicao_modalidade cm
        JOIN modalidade m ON m.id = cm.modalidade_id
        WHERE cm.competicao_id = @id AND cm.ativa = TRUE
        ORDER BY m.nome
      '''),
      parameters: {'id': competitionId},
    );
    final categories = await _database.pool.execute(
      Sql.named('''
        SELECT cc.id, ca.id AS categoria_id, ca.nome, ca.idade_minima,
               ca.idade_maxima, ca.genero, cc.data_referencia,
               cc.serie_min, cc.serie_max, cc.criterios
        FROM competicao_categoria cc
        JOIN categoria ca ON ca.id = cc.categoria_id
        WHERE cc.competicao_id = @id AND cc.ativa = TRUE
        ORDER BY ca.nome
      '''),
      parameters: {'id': competitionId},
    );
    final phases = await _database.pool.execute(
      Sql.named('''
        SELECT id, nome, ordem, tipo, quantidade_grupos, classificados,
               configuracao
        FROM fase_competicao
        WHERE competicao_id = @id AND ativa = TRUE
        ORDER BY ordem
      '''),
      parameters: {'id': competitionId},
    );
    final editions = await _database.pool.execute(
      Sql.named('''
        SELECT id, ano, nome, data_inicio, data_fim, status, criado_em
        FROM edicao_jogos
        WHERE competicao_id = @id
        ORDER BY ano DESC
      '''),
      parameters: {'id': competitionId},
    );

    return {
      'competicao': result.single.toColumnMap(),
      'modalidades': modalities.map((row) => row.toColumnMap()).toList(),
      'categorias': categories.map((row) => row.toColumnMap()).toList(),
      'fases': phases.map((row) => row.toColumnMap()).toList(),
      'edicoes': editions.map((row) => row.toColumnMap()).toList(),
    };
  }

  Future<Map<String, dynamic>> update(
    String competitionId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final start = _date(data['dataInicio'], field: 'dataInicio');
    final end = _date(data['dataFim'], field: 'dataFim');
    if (start != null && end != null && end.isBefore(start)) {
      throw const ApiException(400, 'A data final não pode anteceder a inicial.');
    }

    return _database.pool.runTx((tx) async {
      final currentResult = await tx.execute(
        Sql.named('SELECT * FROM competicao WHERE id = @id AND ativo = TRUE FOR UPDATE'),
        parameters: {'id': competitionId},
      );
      if (currentResult.isEmpty) {
        throw const ApiException(404, 'Competição não encontrada.');
      }
      final current = currentResult.single.toColumnMap();
      if (current['status'].toString() == 'ENCERRADA') {
        throw const ApiException(409, 'Uma competição encerrada não pode ser editada.');
      }

      final closedMatches = await tx.execute(
        Sql.named('''
          SELECT COUNT(*)::int AS total
          FROM partida
          WHERE competicao_id = @id AND status = 'ENCERRADA'
        '''),
        parameters: {'id': competitionId},
      );
      final hasResults = closedMatches.single.toColumnMap()['total'] as int > 0;
      if (hasResults &&
          (data.containsKey('dataInicio') ||
              data.containsKey('dataFim') ||
              data.containsKey('formato') ||
              data.containsKey('modalidadeId'))) {
        throw const ApiException(
          409,
          'Período, formato e modalidade não podem mudar após partidas encerradas.',
        );
      }

      final result = await tx.execute(
        Sql.named('''
          UPDATE competicao
          SET nome = COALESCE(@nome, nome),
              descricao = COALESCE(@descricao, descricao),
              tipo = COALESCE(@tipo, tipo),
              abrangencia = COALESCE(@abrangencia, abrangencia),
              formato = COALESCE(@formato, formato),
              modalidade_id = COALESCE(CAST(@modalidadeId AS uuid), modalidade_id),
              categoria_id = COALESCE(CAST(@categoriaId AS uuid), categoria_id),
              limite_times = COALESCE(@limiteTimes, limite_times),
              data_inicio = COALESCE(CAST(@inicio AS date), data_inicio),
              data_fim = COALESCE(CAST(@fim AS date), data_fim),
              data_limite_inscricao = COALESCE(CAST(@limiteInscricao AS timestamptz), data_limite_inscricao),
              atualizado_em = NOW()
          WHERE id = @id AND ativo = TRUE
          RETURNING id, nome, descricao, tipo, abrangencia, formato, status,
                    modalidade_id, categoria_id, limite_times, data_inicio,
                    data_fim, data_limite_inscricao, atualizado_em
        '''),
        parameters: {
          'id': competitionId,
          'nome': _nullableText(data['nome']),
          'descricao': _nullableText(data['descricao']),
          'tipo': _nullableText(data['tipo'])?.toUpperCase(),
          'abrangencia': _nullableText(data['abrangencia']),
          'formato': _nullableText(data['formato'])?.toUpperCase(),
          'modalidadeId': data['modalidadeId'],
          'categoriaId': data['categoriaId'],
          'limiteTimes': int.tryParse(data['limiteTimes']?.toString() ?? ''),
          'inicio': start,
          'fim': end,
          'limiteInscricao': _dateTime(data['dataLimiteInscricao'], field: 'dataLimiteInscricao'),
        },
      );
      await _audit(
        tx,
        actorUserId,
        'EDITAR_COMPETICAO',
        'COMPETICAO',
        competitionId,
        {'anteriores': current, 'novos': data},
      );
      return result.single.toColumnMap();
    });
  }

  Future<Map<String, dynamic>> deleteLogical(
    String competitionId,
    String justification,
    String actorUserId,
  ) async {
    if (justification.trim().length < 5) {
      throw const ApiException(400, 'Informe a justificativa do cancelamento.');
    }

    return _database.pool.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
          UPDATE competicao
          SET status = 'CANCELADA', ativo = FALSE,
              justificativa_cancelamento = @justificativa,
              excluida_em = NOW(), atualizado_em = NOW()
          WHERE id = @id AND ativo = TRUE
          RETURNING id, nome, status, justificativa_cancelamento, excluida_em
        '''),
        parameters: {'id': competitionId, 'justificativa': justification.trim()},
      );
      if (result.isEmpty) {
        throw const ApiException(404, 'Competição não encontrada.');
      }
      await tx.execute(
        Sql.named('''
          UPDATE inscricao_competicao
          SET status = 'CANCELADA', cancelado_por = @usuarioId,
              cancelado_em = NOW()
          WHERE competicao_id = @id AND status = 'ATIVA'
        '''),
        parameters: {'id': competitionId, 'usuarioId': actorUserId},
      );
      await tx.execute(
        Sql.named('''
          UPDATE partida
          SET status = 'CANCELADA', atualizado_em = NOW()
          WHERE competicao_id = @id
            AND status IN ('PLANEJADA', 'AGENDADA')
        '''),
        parameters: {'id': competitionId},
      );
      await _audit(
        tx,
        actorUserId,
        'EXCLUIR_COMPETICAO',
        'COMPETICAO',
        competitionId,
        {'justificativa': justification.trim()},
      );
      return result.single.toColumnMap();
    });
  }

  Future<Map<String, dynamic>> createEdition(
    String competitionId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final year = int.tryParse(data['ano']?.toString() ?? '');
    final name = data['nome']?.toString().trim() ?? '';
    final start = _date(data['dataInicio'], field: 'dataInicio');
    final end = _date(data['dataFim'], field: 'dataFim');
    if (year == null || name.isEmpty || start == null || end == null) {
      throw const ApiException(400, 'Informe ano, nome, dataInicio e dataFim.');
    }
    if (end.isBefore(start)) {
      throw const ApiException(400, 'A data final não pode anteceder a inicial.');
    }

    return _database.pool.runTx((tx) async {
      final exists = await tx.execute(
        Sql.named('SELECT 1 FROM competicao WHERE id = @id AND ativo = TRUE'),
        parameters: {'id': competitionId},
      );
      if (exists.isEmpty) {
        throw const ApiException(404, 'Competição-base não encontrada.');
      }

      final copy = data['copiarConfiguracoes'] == true;
      Map<String, dynamic> snapshot = {};
      if (copy) {
        final modalities = await tx.execute(
          Sql.named('SELECT modalidade_id, jogadores_min, jogadores_max, limite_times, regras FROM competicao_modalidade WHERE competicao_id = @id AND ativa = TRUE'),
          parameters: {'id': competitionId},
        );
        final categories = await tx.execute(
          Sql.named('SELECT categoria_id, data_referencia, serie_min, serie_max, criterios FROM competicao_categoria WHERE competicao_id = @id AND ativa = TRUE'),
          parameters: {'id': competitionId},
        );
        final phases = await tx.execute(
          Sql.named('SELECT nome, ordem, tipo, quantidade_grupos, classificados, configuracao FROM fase_competicao WHERE competicao_id = @id AND ativa = TRUE ORDER BY ordem'),
          parameters: {'id': competitionId},
        );
        snapshot = {
          'modalidades': modalities.map((row) => row.toColumnMap()).toList(),
          'categorias': categories.map((row) => row.toColumnMap()).toList(),
          'fases': phases.map((row) => row.toColumnMap()).toList(),
        };
      }

      try {
        final result = await tx.execute(
          Sql.named('''
            INSERT INTO edicao_jogos
              (competicao_id, ano, nome, data_inicio, data_fim,
               configuracoes_copiadas, criada_por)
            VALUES
              (@competicaoId, @ano, @nome, @inicio, @fim,
               CAST(@configuracoes AS jsonb), @usuarioId)
            RETURNING id, competicao_id, ano, nome, data_inicio, data_fim,
                      status, configuracoes_copiadas, criado_em
          '''),
          parameters: {
            'competicaoId': competitionId,
            'ano': year,
            'nome': name,
            'inicio': start,
            'fim': end,
            'configuracoes': _json(snapshot),
            'usuarioId': actorUserId,
          },
        );
        await _audit(
          tx,
          actorUserId,
          'CRIAR_EDICAO',
          'EDICAO_JOGOS',
          result.single.toColumnMap()['id'].toString(),
          result.single.toColumnMap(),
        );
        return result.single.toColumnMap();
      } on ServerException catch (error) {
        if (error.code == '23505') {
          throw const ApiException(409, 'Já existe uma edição para esse ano.');
        }
        rethrow;
      }
    });
  }

  Future<Map<String, dynamic>> configureModality(
    String competitionId,
    String modalityId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    return _database.pool.runTx((tx) async {
      await _ensureConfigurable(tx, competitionId);
      final modality = await tx.execute(
        Sql.named('SELECT 1 FROM modalidade WHERE id = @id AND ativa = TRUE'),
        parameters: {'id': modalityId},
      );
      if (modality.isEmpty) {
        throw const ApiException(404, 'Modalidade não encontrada.');
      }
      final min = int.tryParse(data['jogadoresMin']?.toString() ?? '');
      final max = int.tryParse(data['jogadoresMax']?.toString() ?? '');
      if (min != null && max != null && max < min) {
        throw const ApiException(400, 'jogadoresMax deve ser maior ou igual a jogadoresMin.');
      }
      final result = await tx.execute(
        Sql.named('''
          INSERT INTO competicao_modalidade
            (competicao_id, modalidade_id, jogadores_min, jogadores_max,
             limite_times, regras, ativa)
          VALUES
            (@competicaoId, @modalidadeId, @min, @max, @limite,
             CAST(@regras AS jsonb), TRUE)
          ON CONFLICT (competicao_id, modalidade_id)
          DO UPDATE SET jogadores_min = EXCLUDED.jogadores_min,
                        jogadores_max = EXCLUDED.jogadores_max,
                        limite_times = EXCLUDED.limite_times,
                        regras = EXCLUDED.regras,
                        ativa = TRUE,
                        atualizado_em = NOW()
          RETURNING id, competicao_id, modalidade_id, jogadores_min,
                    jogadores_max, limite_times, regras, ativa
        '''),
        parameters: {
          'competicaoId': competitionId,
          'modalidadeId': modalityId,
          'min': min,
          'max': max,
          'limite': int.tryParse(data['limiteTimes']?.toString() ?? ''),
          'regras': _json(data['regras'] ?? <String, dynamic>{}),
        },
      );
      await tx.execute(
        Sql.named('UPDATE competicao SET modalidade_id = COALESCE(modalidade_id, @modalidadeId), atualizado_em = NOW() WHERE id = @id'),
        parameters: {'id': competitionId, 'modalidadeId': modalityId},
      );
      await _audit(tx, actorUserId, 'CONFIGURAR_MODALIDADE', 'COMPETICAO', competitionId, result.single.toColumnMap());
      return result.single.toColumnMap();
    });
  }

  Future<void> removeModality(
    String competitionId,
    String modalityId,
    String actorUserId,
  ) async {
    await _database.pool.runTx((tx) async {
      await _ensureConfigurable(tx, competitionId);
      final matches = await tx.execute(
        Sql.named('SELECT 1 FROM partida WHERE competicao_id = @id AND status IN (\'EM_ANDAMENTO\', \'ENCERRADA\') LIMIT 1'),
        parameters: {'id': competitionId},
      );
      if (matches.isNotEmpty) {
        throw const ApiException(409, 'A modalidade não pode ser removida após partidas iniciadas.');
      }
      final result = await tx.execute(
        Sql.named('''
          UPDATE competicao_modalidade
          SET ativa = FALSE, atualizado_em = NOW()
          WHERE competicao_id = @competicaoId
            AND modalidade_id = @modalidadeId
            AND ativa = TRUE
          RETURNING id
        '''),
        parameters: {'competicaoId': competitionId, 'modalidadeId': modalityId},
      );
      if (result.isEmpty) {
        throw const ApiException(404, 'Configuração de modalidade não encontrada.');
      }
      await _audit(tx, actorUserId, 'REMOVER_MODALIDADE', 'COMPETICAO', competitionId, {'modalidadeId': modalityId});
    });
  }

  Future<Map<String, dynamic>> configureCategory(
    String competitionId,
    String categoryId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    return _database.pool.runTx((tx) async {
      await _ensureConfigurable(tx, competitionId);
      final category = await tx.execute(
        Sql.named('SELECT 1 FROM categoria WHERE id = @id'),
        parameters: {'id': categoryId},
      );
      if (category.isEmpty) {
        throw const ApiException(404, 'Categoria não encontrada.');
      }
      final min = int.tryParse(data['serieMin']?.toString() ?? '');
      final max = int.tryParse(data['serieMax']?.toString() ?? '');
      if (min != null && max != null && max < min) {
        throw const ApiException(400, 'serieMax deve ser maior ou igual a serieMin.');
      }
      final result = await tx.execute(
        Sql.named('''
          INSERT INTO competicao_categoria
            (competicao_id, categoria_id, data_referencia, serie_min,
             serie_max, criterios, ativa)
          VALUES
            (@competicaoId, @categoriaId, CAST(@referencia AS date), @min,
             @max, CAST(@criterios AS jsonb), TRUE)
          ON CONFLICT (competicao_id, categoria_id)
          DO UPDATE SET data_referencia = EXCLUDED.data_referencia,
                        serie_min = EXCLUDED.serie_min,
                        serie_max = EXCLUDED.serie_max,
                        criterios = EXCLUDED.criterios,
                        ativa = TRUE,
                        atualizado_em = NOW()
          RETURNING id, competicao_id, categoria_id, data_referencia,
                    serie_min, serie_max, criterios, ativa
        '''),
        parameters: {
          'competicaoId': competitionId,
          'categoriaId': categoryId,
          'referencia': _date(data['dataReferencia'], field: 'dataReferencia'),
          'min': min,
          'max': max,
          'criterios': _json(data['criterios'] ?? <String, dynamic>{}),
        },
      );
      await tx.execute(
        Sql.named('UPDATE competicao SET categoria_id = COALESCE(categoria_id, @categoriaId), atualizado_em = NOW() WHERE id = @id'),
        parameters: {'id': competitionId, 'categoriaId': categoryId},
      );
      await _audit(tx, actorUserId, 'CONFIGURAR_CATEGORIA', 'COMPETICAO', competitionId, result.single.toColumnMap());
      return result.single.toColumnMap();
    });
  }

  Future<void> removeCategory(
    String competitionId,
    String categoryId,
    String actorUserId,
  ) async {
    await _database.pool.runTx((tx) async {
      await _ensureConfigurable(tx, competitionId);
      final enrolled = await tx.execute(
        Sql.named('''
          SELECT 1
          FROM inscricao_competicao i
          JOIN time_esportivo t ON t.id = i.time_id
          WHERE i.competicao_id = @competicaoId AND i.status = 'ATIVA'
            AND t.categoria_id = @categoriaId
          LIMIT 1
        '''),
        parameters: {'competicaoId': competitionId, 'categoriaId': categoryId},
      );
      if (enrolled.isNotEmpty) {
        throw const ApiException(409, 'Existem times inscritos nessa categoria.');
      }
      final result = await tx.execute(
        Sql.named('''
          UPDATE competicao_categoria
          SET ativa = FALSE, atualizado_em = NOW()
          WHERE competicao_id = @competicaoId
            AND categoria_id = @categoriaId
            AND ativa = TRUE
          RETURNING id
        '''),
        parameters: {'competicaoId': competitionId, 'categoriaId': categoryId},
      );
      if (result.isEmpty) {
        throw const ApiException(404, 'Configuração de categoria não encontrada.');
      }
      await _audit(tx, actorUserId, 'REMOVER_CATEGORIA', 'COMPETICAO', competitionId, {'categoriaId': categoryId});
    });
  }

  Future<List<Map<String, dynamic>>> savePhases(
    String competitionId,
    List<dynamic> phases,
    String actorUserId,
  ) async {
    if (phases.isEmpty) {
      throw const ApiException(400, 'Informe ao menos uma fase.');
    }

    return _database.pool.runTx((tx) async {
      await _ensureConfigurable(tx, competitionId);
      final started = await tx.execute(
        Sql.named('SELECT 1 FROM partida WHERE competicao_id = @id AND status IN (\'EM_ANDAMENTO\', \'ENCERRADA\') LIMIT 1'),
        parameters: {'id': competitionId},
      );
      if (started.isNotEmpty) {
        throw const ApiException(409, 'As fases não podem mudar após partidas iniciadas.');
      }

      await tx.execute(
        Sql.named('DELETE FROM partida WHERE competicao_id = @id AND status IN (\'PLANEJADA\', \'AGENDADA\')'),
        parameters: {'id': competitionId},
      );
      await tx.execute(
        Sql.named('DELETE FROM chaveamento_item WHERE chaveamento_id IN (SELECT id FROM chaveamento WHERE competicao_id = @id)'),
        parameters: {'id': competitionId},
      );
      await tx.execute(
        Sql.named('DELETE FROM chaveamento WHERE competicao_id = @id'),
        parameters: {'id': competitionId},
      );
      await tx.execute(
        Sql.named('DELETE FROM regra_classificacao WHERE fase_id IN (SELECT id FROM fase_competicao WHERE competicao_id = @id)'),
        parameters: {'id': competitionId},
      );
      await tx.execute(
        Sql.named('DELETE FROM grupo_competicao WHERE fase_id IN (SELECT id FROM fase_competicao WHERE competicao_id = @id)'),
        parameters: {'id': competitionId},
      );
      await tx.execute(
        Sql.named('DELETE FROM fase_competicao WHERE competicao_id = @id'),
        parameters: {'id': competitionId},
      );

      final created = <Map<String, dynamic>>[];
      for (var index = 0; index < phases.length; index++) {
        final raw = phases[index];
        if (raw is! Map) {
          throw const ApiException(400, 'Cada fase deve ser um objeto JSON.');
        }
        final phase = Map<String, dynamic>.from(raw);
        final name = phase['nome']?.toString().trim() ?? '';
        final type = phase['tipo']?.toString().trim().toUpperCase() ?? '';
        if (name.isEmpty || type.isEmpty) {
          throw const ApiException(400, 'Cada fase precisa de nome e tipo.');
        }
        final order = int.tryParse(phase['ordem']?.toString() ?? '') ?? index + 1;
        final result = await tx.execute(
          Sql.named('''
            INSERT INTO fase_competicao
              (competicao_id, nome, ordem, tipo, quantidade_grupos,
               classificados, configuracao)
            VALUES
              (@competicaoId, @nome, @ordem, @tipo, @grupos,
               @classificados, CAST(@configuracao AS jsonb))
            RETURNING id, competicao_id, nome, ordem, tipo,
                      quantidade_grupos, classificados, configuracao
          '''),
          parameters: {
            'competicaoId': competitionId,
            'nome': name,
            'ordem': order,
            'tipo': type,
            'grupos': int.tryParse(phase['quantidadeGrupos']?.toString() ?? ''),
            'classificados': int.tryParse(phase['classificados']?.toString() ?? ''),
            'configuracao': _json(phase['configuracao'] ?? <String, dynamic>{}),
          },
        );
        final item = result.single.toColumnMap();
        final phaseId = item['id'].toString();

        final groups = phase['grupos'];
        if (groups is List) {
          for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
            final groupName = groups[groupIndex].toString().trim();
            if (groupName.isEmpty) continue;
            await tx.execute(
              Sql.named('INSERT INTO grupo_competicao (fase_id, nome, ordem) VALUES (@faseId, @nome, @ordem)'),
              parameters: {'faseId': phaseId, 'nome': groupName, 'ordem': groupIndex + 1},
            );
          }
        }
        final rules = phase['regrasClassificacao'];
        if (rules is List) {
          for (var ruleIndex = 0; ruleIndex < rules.length; ruleIndex++) {
            final rule = rules[ruleIndex];
            if (rule is! Map || rule['criterio'] == null) continue;
            await tx.execute(
              Sql.named('''
                INSERT INTO regra_classificacao
                  (fase_id, ordem, criterio, direcao, configuracao)
                VALUES
                  (@faseId, @ordem, @criterio, @direcao,
                   CAST(@configuracao AS jsonb))
              '''),
              parameters: {
                'faseId': phaseId,
                'ordem': ruleIndex + 1,
                'criterio': rule['criterio'].toString().trim().toUpperCase(),
                'direcao': rule['direcao']?.toString().trim().toUpperCase() ?? 'DESC',
                'configuracao': _json(rule['configuracao'] ?? <String, dynamic>{}),
              },
            );
          }
        }
        created.add(item);
      }
      await _audit(tx, actorUserId, 'ORGANIZAR_FASES', 'COMPETICAO', competitionId, created);
      return created;
    });
  }

  Future<Map<String, dynamic>> generateBracket(
    String competitionId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final method = data['metodo']?.toString().trim().toUpperCase() ?? 'SORTEIO';
    final seed = int.tryParse(data['semente']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch;

    return _database.pool.runTx((tx) async {
      final competition = await tx.execute(
        Sql.named('SELECT id, status FROM competicao WHERE id = @id AND ativo = TRUE FOR UPDATE'),
        parameters: {'id': competitionId},
      );
      if (competition.isEmpty) {
        throw const ApiException(404, 'Competição não encontrada.');
      }
      final teamsResult = await tx.execute(
        Sql.named('''
          SELECT t.id, t.nome
          FROM inscricao_competicao i
          JOIN time_esportivo t ON t.id = i.time_id
          WHERE i.competicao_id = @id AND i.status = 'ATIVA' AND t.ativo = TRUE
          ORDER BY t.nome
        '''),
        parameters: {'id': competitionId},
      );
      if (teamsResult.length < 2) {
        throw const ApiException(409, 'São necessários ao menos dois times inscritos.');
      }
      final teams = teamsResult.map((row) => row.toColumnMap()).toList();
      if (method == 'SORTEIO') {
        teams.shuffle(Random(seed));
      } else if (method != 'ALFABETICO') {
        throw const ApiException(400, 'Método aceito: SORTEIO ou ALFABETICO.');
      }

      String? phaseId = data['faseId']?.toString();
      if (phaseId == null || phaseId.isEmpty) {
        final phase = await tx.execute(
          Sql.named('SELECT id FROM fase_competicao WHERE competicao_id = @id AND ativa = TRUE ORDER BY ordem LIMIT 1'),
          parameters: {'id': competitionId},
        );
        if (phase.isEmpty) {
          throw const ApiException(409, 'Configure as fases antes do chaveamento.');
        }
        phaseId = phase.single.toColumnMap()['id'].toString();
      }
      final groups = await tx.execute(
        Sql.named('SELECT id, nome FROM grupo_competicao WHERE fase_id = @faseId ORDER BY ordem, nome'),
        parameters: {'faseId': phaseId},
      );
      final versionResult = await tx.execute(
        Sql.named('SELECT COALESCE(MAX(versao), 0)::int + 1 AS versao FROM chaveamento WHERE competicao_id = @id'),
        parameters: {'id': competitionId},
      );
      final version = versionResult.single.toColumnMap()['versao'] as int;
      final bracket = await tx.execute(
        Sql.named('''
          INSERT INTO chaveamento
            (competicao_id, fase_id, versao, metodo, semente, status, criado_por)
          VALUES
            (@competicaoId, @faseId, @versao, @metodo, @semente,
             'CONFIRMADO', @usuarioId)
          RETURNING id, competicao_id, fase_id, versao, metodo, semente,
                    status, criado_em
        '''),
        parameters: {
          'competicaoId': competitionId,
          'faseId': phaseId,
          'versao': version,
          'metodo': method,
          'semente': seed,
          'usuarioId': actorUserId,
        },
      );
      final bracketMap = bracket.single.toColumnMap();
      final bracketId = bracketMap['id'].toString();
      final items = <Map<String, dynamic>>[];
      for (var index = 0; index < teams.length; index++) {
        final groupId = groups.isEmpty
            ? null
            : groups[index % groups.length].toColumnMap()['id'];
        final item = await tx.execute(
          Sql.named('''
            INSERT INTO chaveamento_item
              (chaveamento_id, fase_id, grupo_id, time_id, posicao, chave)
            VALUES
              (@chaveamentoId, @faseId, CAST(@grupoId AS uuid), @timeId,
               @posicao, @chave)
            RETURNING id, chaveamento_id, fase_id, grupo_id, time_id,
                      posicao, chave
          '''),
          parameters: {
            'chaveamentoId': bracketId,
            'faseId': phaseId,
            'grupoId': groupId,
            'timeId': teams[index]['id'],
            'posicao': index + 1,
            'chave': groups.isEmpty ? 'CHAVE_${index + 1}' : groups[index % groups.length].toColumnMap()['nome'],
          },
        );
        items.add({...item.single.toColumnMap(), 'time_nome': teams[index]['nome']});
      }
      await _audit(tx, actorUserId, 'GERAR_CHAVEAMENTO', 'CHAVEAMENTO', bracketId, {'semente': seed, 'metodo': method, 'itens': items});
      return {...bracketMap, 'itens': items};
    });
  }

  Future<Map<String, dynamic>> generateMatches(
    String competitionId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final mode = data['modo']?.toString().trim().toUpperCase() ?? 'TURNO_UNICO';
    if (!{'TURNO_UNICO', 'IDA_VOLTA'}.contains(mode)) {
      throw const ApiException(400, 'modo deve ser TURNO_UNICO ou IDA_VOLTA.');
    }
    final replace = data['substituir'] == true;

    return _database.pool.runTx((tx) async {
      final latest = await tx.execute(
        Sql.named('''
          SELECT id, fase_id
          FROM chaveamento
          WHERE competicao_id = @id AND status = 'CONFIRMADO'
          ORDER BY versao DESC
          LIMIT 1
        '''),
        parameters: {'id': competitionId},
      );
      if (latest.isEmpty) {
        throw const ApiException(409, 'Gere e confirme o chaveamento antes da tabela.');
      }
      final bracket = latest.single.toColumnMap();
      final bracketId = bracket['id'].toString();
      final phaseId = bracket['fase_id']?.toString();
      final teamsResult = await tx.execute(
        Sql.named('''
          SELECT ci.id AS item_id, ci.time_id
          FROM chaveamento_item ci
          WHERE ci.chaveamento_id = @id
          ORDER BY ci.posicao
        '''),
        parameters: {'id': bracketId},
      );
      if (teamsResult.length < 2) {
        throw const ApiException(409, 'O chaveamento não possui times suficientes.');
      }

      final existing = await tx.execute(
        Sql.named('SELECT COUNT(*)::int AS total FROM partida WHERE competicao_id = @id AND status <> \'CANCELADA\''),
        parameters: {'id': competitionId},
      );
      final totalExisting = existing.single.toColumnMap()['total'] as int;
      if (totalExisting > 0 && !replace) {
        throw const ApiException(409, 'Já existe uma tabela. Use substituir=true para recriar partidas futuras.');
      }
      if (replace) {
        final started = await tx.execute(
          Sql.named('SELECT 1 FROM partida WHERE competicao_id = @id AND status IN (\'EM_ANDAMENTO\', \'ENCERRADA\') LIMIT 1'),
          parameters: {'id': competitionId},
        );
        if (started.isNotEmpty) {
          throw const ApiException(409, 'Não é possível substituir uma tabela com partidas iniciadas.');
        }
        await tx.execute(
          Sql.named('DELETE FROM partida WHERE competicao_id = @id AND status IN (\'PLANEJADA\', \'AGENDADA\', \'CANCELADA\')'),
          parameters: {'id': competitionId},
        );
      }

      final teams = teamsResult.map((row) => row.toColumnMap()).toList();
      final rounds = _roundRobin(teams);
      final generated = <Map<String, dynamic>>[];
      var roundNumber = 1;
      for (final round in rounds) {
        for (final pair in round) {
          final result = await tx.execute(
            Sql.named('''
              INSERT INTO partida
                (competicao_id, fase_id, chaveamento_item_id,
                 time_casa_id, time_visitante_id, rodada, status)
              VALUES
                (@competicaoId, CAST(@faseId AS uuid), @itemId,
                 @casa, @visitante, @rodada, 'PLANEJADA')
              RETURNING id, competicao_id, fase_id, time_casa_id,
                        time_visitante_id, rodada, status
            '''),
            parameters: {
              'competicaoId': competitionId,
              'faseId': phaseId,
              'itemId': pair.$1['item_id'],
              'casa': pair.$1['time_id'],
              'visitante': pair.$2['time_id'],
              'rodada': roundNumber,
            },
          );
          generated.add(result.single.toColumnMap());
        }
        roundNumber++;
      }
      if (mode == 'IDA_VOLTA') {
        final firstLeg = List<Map<String, dynamic>>.from(generated);
        for (final match in firstLeg) {
          final result = await tx.execute(
            Sql.named('''
              INSERT INTO partida
                (competicao_id, fase_id, time_casa_id, time_visitante_id,
                 rodada, status)
              VALUES
                (@competicaoId, CAST(@faseId AS uuid), @casa, @visitante,
                 @rodada, 'PLANEJADA')
              RETURNING id, competicao_id, fase_id, time_casa_id,
                        time_visitante_id, rodada, status
            '''),
            parameters: {
              'competicaoId': competitionId,
              'faseId': phaseId,
              'casa': match['time_visitante_id'],
              'visitante': match['time_casa_id'],
              'rodada': (match['rodada'] as int) + rounds.length,
            },
          );
          generated.add(result.single.toColumnMap());
        }
      }
      await _audit(tx, actorUserId, 'GERAR_TABELA_PARTIDAS', 'COMPETICAO', competitionId, {'modo': mode, 'total': generated.length});
      return {'competicaoId': competitionId, 'modo': mode, 'total': generated.length, 'partidas': generated};
    });
  }

  Future<Map<String, dynamic>> scheduleMatch(
    String matchId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final dateTime = _dateTime(data['dataHora'], field: 'dataHora');
    if (dateTime == null) {
      throw const ApiException(400, 'Informe dataHora.');
    }
    return _database.pool.runTx((tx) => _scheduleWithTx(
          tx,
          matchId,
          dateTime,
          data['localId']?.toString(),
          data['motivo']?.toString(),
          actorUserId,
        ));
  }

  Future<List<Map<String, dynamic>>> scheduleCompetition(
    String competitionId,
    List<dynamic> entries,
    String actorUserId,
  ) async {
    if (entries.isEmpty) {
      throw const ApiException(400, 'Informe as partidas do calendário.');
    }
    return _database.pool.runTx((tx) async {
      final scheduled = <Map<String, dynamic>>[];
      for (final raw in entries) {
        if (raw is! Map) {
          throw const ApiException(400, 'Cada item do calendário deve ser um objeto.');
        }
        final item = Map<String, dynamic>.from(raw);
        final matchId = item['partidaId']?.toString();
        final dateTime = _dateTime(item['dataHora'], field: 'dataHora');
        if (matchId == null || dateTime == null) {
          throw const ApiException(400, 'Cada item precisa de partidaId e dataHora.');
        }
        final belongs = await tx.execute(
          Sql.named('SELECT 1 FROM partida WHERE id = @partidaId AND competicao_id = @competicaoId'),
          parameters: {'partidaId': matchId, 'competicaoId': competitionId},
        );
        if (belongs.isEmpty) {
          throw const ApiException(409, 'Uma partida não pertence à competição informada.');
        }
        scheduled.add(await _scheduleWithTx(
          tx,
          matchId,
          dateTime,
          item['localId']?.toString(),
          item['motivo']?.toString(),
          actorUserId,
        ));
      }
      return scheduled;
    });
  }

  Future<List<Map<String, dynamic>>> calendar({
    String? competitionId,
    String? teamId,
    String? locationId,
    DateTime? from,
    DateTime? to,
    required int page,
    required int limit,
  }) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT p.id, p.rodada, p.data_hora, p.status,
               c.id AS competicao_id, c.nome AS competicao,
               f.id AS fase_id, f.nome AS fase,
               tc.id AS time_casa_id, tc.nome AS time_casa,
               tv.id AS time_visitante_id, tv.nome AS time_visitante,
               l.id AS local_id, COALESCE(l.nome, p.local) AS local,
               l.cidade, l.estado
        FROM partida p
        JOIN competicao c ON c.id = p.competicao_id
        JOIN time_esportivo tc ON tc.id = p.time_casa_id
        JOIN time_esportivo tv ON tv.id = p.time_visitante_id
        LEFT JOIN fase_competicao f ON f.id = p.fase_id
        LEFT JOIN local_partida l ON l.id = p.local_partida_id
        WHERE p.status <> 'CANCELADA'
          AND (CAST(@competicaoId AS uuid) IS NULL OR p.competicao_id = CAST(@competicaoId AS uuid))
          AND (CAST(@localId AS uuid) IS NULL OR p.local_partida_id = CAST(@localId AS uuid))
          AND (CAST(@timeId AS uuid) IS NULL OR p.time_casa_id = CAST(@timeId AS uuid) OR p.time_visitante_id = CAST(@timeId AS uuid))
          AND (CAST(@de AS timestamptz) IS NULL OR p.data_hora >= CAST(@de AS timestamptz))
          AND (CAST(@ate AS timestamptz) IS NULL OR p.data_hora <= CAST(@ate AS timestamptz))
        ORDER BY p.data_hora NULLS LAST, c.nome, p.rodada
        LIMIT @limite OFFSET @deslocamento
      '''),
      parameters: {
        'competicaoId': competitionId,
        'timeId': teamId,
        'localId': locationId,
        'de': from,
        'ate': to,
        'limite': limit,
        'deslocamento': (page - 1) * limit,
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> createLocation(
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final name = data['nome']?.toString().trim() ?? '';
    final type = data['tipo']?.toString().trim().toUpperCase() ?? '';
    final city = data['cidade']?.toString().trim() ?? '';
    final state = data['estado']?.toString().trim().toUpperCase() ?? '';
    if (name.isEmpty || type.isEmpty || city.isEmpty || state.length != 2) {
      throw const ApiException(400, 'Informe nome, tipo, cidade e estado do local.');
    }

    return _database.pool.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
          INSERT INTO local_partida
            (nome, tipo, capacidade, logradouro, numero, complemento,
             bairro, cidade, estado, cep, instalacoes, criado_por)
          VALUES
            (@nome, @tipo, @capacidade, @logradouro, @numero, @complemento,
             @bairro, @cidade, @estado, @cep, CAST(@instalacoes AS jsonb),
             @usuarioId)
          RETURNING id, nome, tipo, capacidade, logradouro, numero,
                    complemento, bairro, cidade, estado, cep, instalacoes,
                    ativo, criado_em
        '''),
        parameters: {
          'nome': name,
          'tipo': type,
          'capacidade': int.tryParse(data['capacidade']?.toString() ?? ''),
          'logradouro': data['logradouro'],
          'numero': data['numero'],
          'complemento': data['complemento'],
          'bairro': data['bairro'],
          'cidade': city,
          'estado': state,
          'cep': data['cep']?.toString().replaceAll(RegExp(r'\D'), ''),
          'instalacoes': _json(data['instalacoes'] ?? <String, dynamic>{}),
          'usuarioId': actorUserId,
        },
      );
      final location = result.single.toColumnMap();
      final locationId = location['id'].toString();
      final modalityIds = data['modalidadeIds'];
      if (modalityIds is List) {
        for (final id in modalityIds) {
          await tx.execute(
            Sql.named('INSERT INTO local_modalidade (local_id, modalidade_id) VALUES (@localId, @modalidadeId) ON CONFLICT DO NOTHING'),
            parameters: {'localId': locationId, 'modalidadeId': id},
          );
        }
      }
      await _audit(tx, actorUserId, 'CADASTRAR_LOCAL', 'LOCAL_PARTIDA', locationId, location);
      return location;
    });
  }

  Future<List<Map<String, dynamic>>> listLocations({
    String? search,
    String? modalityId,
  }) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT l.id, l.nome, l.tipo, l.capacidade, l.logradouro, l.numero,
               l.bairro, l.cidade, l.estado, l.cep, l.instalacoes
        FROM local_partida l
        WHERE l.ativo = TRUE
          AND (CAST(@busca AS text) IS NULL OR
               l.nome ILIKE '%' || CAST(@busca AS text) || '%' OR
               l.cidade ILIKE '%' || CAST(@busca AS text) || '%')
          AND (
            CAST(@modalidadeId AS uuid) IS NULL OR
            NOT EXISTS (SELECT 1 FROM local_modalidade lm0 WHERE lm0.local_id = l.id) OR
            EXISTS (
              SELECT 1 FROM local_modalidade lm
              WHERE lm.local_id = l.id AND lm.modalidade_id = CAST(@modalidadeId AS uuid)
            )
          )
        ORDER BY l.cidade, l.nome
      '''),
      parameters: {'busca': search, 'modalidadeId': modalityId},
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> assignLocation(
    String matchId,
    String locationId,
    String actorUserId,
  ) async {
    return _database.pool.runTx((tx) async {
      final match = await tx.execute(
        Sql.named('''
          SELECT p.id, p.data_hora, p.local_partida_id, c.modalidade_id
          FROM partida p
          JOIN competicao c ON c.id = p.competicao_id
          WHERE p.id = @id AND p.status IN ('PLANEJADA', 'AGENDADA')
          FOR UPDATE
        '''),
        parameters: {'id': matchId},
      );
      if (match.isEmpty) {
        throw const ApiException(404, 'Partida disponível não encontrada.');
      }
      final current = match.single.toColumnMap();
      final location = await tx.execute(
        Sql.named('''
          SELECT 1
          FROM local_partida l
          WHERE l.id = @localId AND l.ativo = TRUE
            AND (
              NOT EXISTS (SELECT 1 FROM local_modalidade lm0 WHERE lm0.local_id = l.id) OR
              CAST(@modalidadeId AS uuid) IS NULL OR EXISTS (
                SELECT 1 FROM local_modalidade lm
                WHERE lm.local_id = l.id AND lm.modalidade_id = CAST(@modalidadeId AS uuid)
              )
            )
        '''),
        parameters: {'localId': locationId, 'modalidadeId': current['modalidade_id']},
      );
      if (location.isEmpty) {
        throw const ApiException(409, 'Local inexistente ou incompatível com a modalidade.');
      }
      if (current['data_hora'] != null) {
        final conflict = await tx.execute(
          Sql.named('''
            SELECT 1 FROM partida
            WHERE local_partida_id = @localId
              AND id <> @partidaId
              AND status IN ('AGENDADA', 'EM_ANDAMENTO')
              AND data_hora BETWEEN CAST(@dataHora AS timestamptz) - INTERVAL '90 minutes'
                                AND CAST(@dataHora AS timestamptz) + INTERVAL '90 minutes'
            LIMIT 1
          '''),
          parameters: {'localId': locationId, 'partidaId': matchId, 'dataHora': current['data_hora']},
        );
        if (conflict.isNotEmpty) {
          throw const ApiException(409, 'O local já está ocupado nesse horário.');
        }
      }
      final result = await tx.execute(
        Sql.named('''
          UPDATE partida
          SET local_partida_id = @localId, atualizado_em = NOW()
          WHERE id = @id
          RETURNING id, local_partida_id, data_hora, status
        '''),
        parameters: {'id': matchId, 'localId': locationId},
      );
      await tx.execute(
        Sql.named('''
          INSERT INTO calendario_alteracao
            (partida_id, data_hora_anterior, data_hora_nova,
             local_anterior_id, local_novo_id, motivo, alterado_por)
          VALUES
            (@partidaId, @dataHora, @dataHora,
             CAST(@localAnterior AS uuid), @localNovo,
             'Definição de local', @usuarioId)
        '''),
        parameters: {
          'partidaId': matchId,
          'dataHora': current['data_hora'],
          'localAnterior': current['local_partida_id'],
          'localNovo': locationId,
          'usuarioId': actorUserId,
        },
      );
      await _audit(tx, actorUserId, 'REGISTRAR_LOCAL_PARTIDA', 'PARTIDA', matchId, {'localId': locationId});
      return result.single.toColumnMap();
    });
  }

  Future<Map<String, dynamic>> enrollTeam(
    String competitionId,
    String teamId,
    String actorUserId,
  ) async {
    return _database.pool.runTx((tx) async {
      final competitionResult = await tx.execute(
        Sql.named('''
          SELECT id, modalidade_id, status, limite_times, data_limite_inscricao
          FROM competicao
          WHERE id = @id AND ativo = TRUE
          FOR UPDATE
        '''),
        parameters: {'id': competitionId},
      );
      if (competitionResult.isEmpty) {
        throw const ApiException(404, 'Competição não encontrada.');
      }
      final competition = competitionResult.single.toColumnMap();
      if (competition['status'] != 'INSCRICOES_ABERTAS') {
        throw const ApiException(409, 'A competição não está com inscrições abertas.');
      }
      final deadline = competition['data_limite_inscricao'];
      if (deadline is DateTime && DateTime.now().isAfter(deadline)) {
        throw const ApiException(409, 'O prazo de inscrição terminou.');
      }

      final teamResult = await tx.execute(
        Sql.named('''
          SELECT id, modalidade_id, categoria_id, ativo
          FROM time_esportivo
          WHERE id = @id
        '''),
        parameters: {'id': teamId},
      );
      if (teamResult.isEmpty || teamResult.single.toColumnMap()['ativo'] != true) {
        throw const ApiException(404, 'Time ativo não encontrado.');
      }
      final team = teamResult.single.toColumnMap();
      final compatible = await tx.execute(
        Sql.named('''
          SELECT 1
          FROM competicao c
          WHERE c.id = @competicaoId
            AND (
              c.modalidade_id = @modalidadeId OR EXISTS (
                SELECT 1 FROM competicao_modalidade cm
                WHERE cm.competicao_id = c.id
                  AND cm.modalidade_id = @modalidadeId
                  AND cm.ativa = TRUE
              )
            )
            AND (
              c.categoria_id IS NULL OR c.categoria_id = CAST(@categoriaId AS uuid) OR EXISTS (
                SELECT 1 FROM competicao_categoria cc
                WHERE cc.competicao_id = c.id
                  AND cc.categoria_id = CAST(@categoriaId AS uuid)
                  AND cc.ativa = TRUE
              )
            )
        '''),
        parameters: {
          'competicaoId': competitionId,
          'modalidadeId': team['modalidade_id'],
          'categoriaId': team['categoria_id'],
        },
      );
      if (compatible.isEmpty) {
        throw const ApiException(409, 'Modalidade ou categoria do time é incompatível com a competição.');
      }

      final countResult = await tx.execute(
        Sql.named('''
          SELECT COUNT(*)::int AS total
          FROM inscricao_competicao
          WHERE competicao_id = @competicaoId AND status = 'ATIVA'
        '''),
        parameters: {'competicaoId': competitionId},
      );
      final total = countResult.single.toColumnMap()['total'] as int;
      final limit = competition['limite_times'] as int?;
      if (limit != null && total >= limit) {
        throw const ApiException(409, 'O limite de times da competição foi atingido.');
      }

      final result = await tx.execute(
        Sql.named('''
          INSERT INTO inscricao_competicao
            (competicao_id, time_id, status, inscrito_por)
          VALUES
            (@competicaoId, @timeId, 'ATIVA', @usuarioId)
          ON CONFLICT (competicao_id, time_id)
          DO UPDATE SET status = 'ATIVA',
                        inscrito_por = EXCLUDED.inscrito_por,
                        inscrito_em = NOW(),
                        cancelado_por = NULL,
                        cancelado_em = NULL
          WHERE inscricao_competicao.status <> 'ATIVA'
          RETURNING id, competicao_id, time_id, status, inscrito_em
        '''),
        parameters: {
          'competicaoId': competitionId,
          'timeId': teamId,
          'usuarioId': actorUserId,
        },
      );
      if (result.isEmpty) {
        throw const ApiException(409, 'O time já está inscrito nessa competição.');
      }
      await _audit(tx, actorUserId, 'INSCREVER_TIME', 'COMPETICAO', competitionId, {'timeId': teamId});
      return result.single.toColumnMap();
    });
  }

  Future<void> cancelEnrollment(
    String competitionId,
    String teamId,
    String actorUserId,
  ) async {
    final result = await _database.pool.execute(
      Sql.named('''
        UPDATE inscricao_competicao ic
        SET status = 'CANCELADA', cancelado_em = NOW(), cancelado_por = @usuarioId
        FROM competicao c
        WHERE ic.competicao_id = c.id
          AND ic.competicao_id = @competicaoId
          AND ic.time_id = @timeId
          AND ic.status = 'ATIVA'
          AND c.status IN ('INSCRICOES_ABERTAS', 'PLANEJADA')
        RETURNING ic.id
      '''),
      parameters: {
        'competicaoId': competitionId,
        'timeId': teamId,
        'usuarioId': actorUserId,
      },
    );
    if (result.isEmpty) {
      throw const ApiException(409, 'Inscrição ativa não encontrada ou cancelamento não permitido.');
    }
  }

  Future<Map<String, dynamic>> closeCompetition(
    String competitionId,
    String actorUserId,
  ) async {
    return _database.pool.runTx((tx) async {
      final pending = await tx.execute(
        Sql.named('''
          SELECT COUNT(*)::int AS total
          FROM partida
          WHERE competicao_id = @id
            AND status NOT IN ('ENCERRADA', 'CANCELADA')
        '''),
        parameters: {'id': competitionId},
      );
      final totalPending = pending.single.toColumnMap()['total'] as int;
      if (totalPending > 0) {
        throw ApiException(409, 'Há $totalPending partida(s) pendente(s).');
      }

      final result = await tx.execute(
        Sql.named('''
          UPDATE competicao
          SET status = 'ENCERRADA', encerrada_em = NOW(), encerrada_por = @usuarioId,
              atualizado_em = NOW()
          WHERE id = @id AND status <> 'ENCERRADA' AND ativo = TRUE
          RETURNING id, nome, status, encerrada_em
        '''),
        parameters: {'id': competitionId, 'usuarioId': actorUserId},
      );
      if (result.isEmpty) {
        throw const ApiException(404, 'Competição não encontrada ou já encerrada.');
      }
      await _audit(tx, actorUserId, 'ENCERRAR_COMPETICAO', 'COMPETICAO', competitionId, result.single.toColumnMap());
      return result.single.toColumnMap();
    });
  }

  Future<List<Map<String, dynamic>>> standings(String competitionId) async {
    final exists = await _database.pool.execute(
      Sql.named('SELECT 1 FROM competicao WHERE id = @id AND ativo = TRUE'),
      parameters: {'id': competitionId},
    );
    if (exists.isEmpty) {
      throw const ApiException(404, 'Competição não encontrada.');
    }

    final result = await _database.pool.execute(
      Sql.named('''
        SELECT *
        FROM fn_classificacao_competicao(@competicaoId)
        ORDER BY pontos DESC, saldo_gols DESC, gols_pro DESC, time_nome
      '''),
      parameters: {'competicaoId': competitionId},
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> _scheduleWithTx(
    Session tx,
    String matchId,
    DateTime dateTime,
    String? locationId,
    String? reason,
    String actorUserId,
  ) async {
    final matchResult = await tx.execute(
      Sql.named('''
        SELECT p.id, p.competicao_id, p.time_casa_id, p.time_visitante_id,
               p.data_hora, p.local_partida_id, p.status,
               c.data_inicio, c.data_fim, c.modalidade_id
        FROM partida p
        JOIN competicao c ON c.id = p.competicao_id
        WHERE p.id = @id AND p.status IN ('PLANEJADA', 'AGENDADA')
        FOR UPDATE
      '''),
      parameters: {'id': matchId},
    );
    if (matchResult.isEmpty) {
      throw const ApiException(404, 'Partida planejada não encontrada.');
    }
    final match = matchResult.single.toColumnMap();
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final start = match['data_inicio'] as DateTime?;
    final end = match['data_fim'] as DateTime?;
    if ((start != null && day.isBefore(DateTime(start.year, start.month, start.day))) ||
        (end != null && day.isAfter(DateTime(end.year, end.month, end.day)))) {
      throw const ApiException(409, 'A data está fora do período da competição.');
    }

    final teamConflict = await tx.execute(
      Sql.named('''
        SELECT 1
        FROM partida p
        WHERE p.id <> @id
          AND p.status IN ('AGENDADA', 'EM_ANDAMENTO')
          AND (p.time_casa_id IN (@casa, @visitante) OR p.time_visitante_id IN (@casa, @visitante))
          AND p.data_hora BETWEEN @dataHora - INTERVAL '90 minutes'
                              AND @dataHora + INTERVAL '90 minutes'
        LIMIT 1
      '''),
      parameters: {
        'id': matchId,
        'casa': match['time_casa_id'],
        'visitante': match['time_visitante_id'],
        'dataHora': dateTime,
      },
    );
    if (teamConflict.isNotEmpty) {
      throw const ApiException(409, 'Um dos times já possui partida em horário conflitante.');
    }

    final selectedLocation = locationId ?? match['local_partida_id']?.toString();
    if (selectedLocation != null) {
      final location = await tx.execute(
        Sql.named('SELECT 1 FROM local_partida WHERE id = @id AND ativo = TRUE'),
        parameters: {'id': selectedLocation},
      );
      if (location.isEmpty) {
        throw const ApiException(404, 'Local não encontrado.');
      }
      final locationConflict = await tx.execute(
        Sql.named('''
          SELECT 1 FROM partida
          WHERE id <> @id AND local_partida_id = @localId
            AND status IN ('AGENDADA', 'EM_ANDAMENTO')
            AND data_hora BETWEEN @dataHora - INTERVAL '90 minutes'
                              AND @dataHora + INTERVAL '90 minutes'
          LIMIT 1
        '''),
        parameters: {'id': matchId, 'localId': selectedLocation, 'dataHora': dateTime},
      );
      if (locationConflict.isNotEmpty) {
        throw const ApiException(409, 'O local já está ocupado nesse horário.');
      }
    }

    final result = await tx.execute(
      Sql.named('''
        UPDATE partida
        SET data_hora = @dataHora,
            local_partida_id = CAST(@localId AS uuid),
            status = 'AGENDADA',
            atualizado_em = NOW()
        WHERE id = @id
        RETURNING id, competicao_id, time_casa_id, time_visitante_id,
                  data_hora, local_partida_id, rodada, status
      '''),
      parameters: {'id': matchId, 'dataHora': dateTime, 'localId': selectedLocation},
    );
    await tx.execute(
      Sql.named('''
        INSERT INTO calendario_alteracao
          (partida_id, data_hora_anterior, data_hora_nova,
           local_anterior_id, local_novo_id, motivo, alterado_por)
        VALUES
          (@partidaId, CAST(@anterior AS timestamptz), @nova,
           CAST(@localAnterior AS uuid), CAST(@localNovo AS uuid),
           @motivo, @usuarioId)
      '''),
      parameters: {
        'partidaId': matchId,
        'anterior': match['data_hora'],
        'nova': dateTime,
        'localAnterior': match['local_partida_id'],
        'localNovo': selectedLocation,
        'motivo': reason,
        'usuarioId': actorUserId,
      },
    );
    await _audit(tx, actorUserId, 'REGISTRAR_CALENDARIO', 'PARTIDA', matchId, result.single.toColumnMap());
    return result.single.toColumnMap();
  }

  Future<void> _ensureConfigurable(Session tx, String competitionId) async {
    final result = await tx.execute(
      Sql.named('''
        SELECT 1 FROM competicao
        WHERE id = @id AND ativo = TRUE
          AND status IN ('PLANEJADA', 'INSCRICOES_ABERTAS')
      '''),
      parameters: {'id': competitionId},
    );
    if (result.isEmpty) {
      throw const ApiException(409, 'A competição não está em fase de configuração.');
    }
  }

  List<List<(Map<String, dynamic>, Map<String, dynamic>)>> _roundRobin(
    List<Map<String, dynamic>> original,
  ) {
    final teams = List<Map<String, dynamic>?>.from(original);
    if (teams.length.isOdd) teams.add(null);
    final rounds = <List<(Map<String, dynamic>, Map<String, dynamic>)>>[];
    final size = teams.length;
    for (var round = 0; round < size - 1; round++) {
      final pairs = <(Map<String, dynamic>, Map<String, dynamic>)>[];
      for (var index = 0; index < size ~/ 2; index++) {
        final home = teams[index];
        final away = teams[size - 1 - index];
        if (home != null && away != null) {
          pairs.add(round.isEven ? (home, away) : (away, home));
        }
      }
      rounds.add(pairs);
      final last = teams.removeLast();
      teams.insert(1, last);
    }
    return rounds;
  }

  DateTime? _date(Object? value, {required String field}) {
    if (value == null || value.toString().trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) throw ApiException(400, '$field é inválida.');
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime? _dateTime(Object? value, {required String field}) {
    if (value == null || value.toString().trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) throw ApiException(400, '$field é inválida.');
    return parsed;
  }

  String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _json(Object? value) {
    return jsonEncode(
      value,
      toEncodable: (object) {
        if (object is DateTime) return object.toIso8601String();
        return object.toString();
      },
    );
  }

  Future<void> _audit(
    Session executor,
    String actorUserId,
    String action,
    String entity,
    String entityId,
    Object? data,
  ) async {
    await executor.execute(
      Sql.named('''
        INSERT INTO log_auditoria
          (usuario_id, acao, entidade, entidade_id, dados_novos)
        VALUES
          (@usuarioId, @acao, @entidade, @entidadeId, CAST(@dados AS jsonb))
      '''),
      parameters: {
        'usuarioId': actorUserId,
        'acao': action,
        'entidade': entity,
        'entidadeId': entityId,
        'dados': _json(data),
      },
    );
  }
}
