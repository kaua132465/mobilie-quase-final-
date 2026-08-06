import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../core/api_exception.dart';
import '../core/database.dart';

class PartidaRepository {
  PartidaRepository(this._database);

  final Database _database;

  Future<Map<String, dynamic>> assignReferee(
    String matchId,
    String refereeId,
    String role,
    String actorUserId,
  ) async {
    final normalizedRole = role.trim().isEmpty
        ? 'PRINCIPAL'
        : role.trim().toUpperCase();

    return _database.pool.runTx((tx) async {
      final validation = await tx.execute(
        Sql.named('''
          SELECT p.id
          FROM partida p
          WHERE p.id = @partidaId
            AND p.status IN ('AGENDADA', 'EM_ANDAMENTO')
            AND EXISTS (
              SELECT 1 FROM arbitro a
              WHERE a.id = @arbitroId AND a.ativo = TRUE
            )
          FOR UPDATE
        '''),
        parameters: {'partidaId': matchId, 'arbitroId': refereeId},
      );
      if (validation.isEmpty) {
        throw const ApiException(
          409,
          'Partida ou árbitro inválido para a operação.',
        );
      }

      final conflict = await tx.execute(
        Sql.named('''
          SELECT 1
          FROM arbitragem_partida ap
          JOIN partida outra ON outra.id = ap.partida_id
          JOIN partida atual ON atual.id = @partidaId
          WHERE ap.arbitro_id = @arbitroId
            AND ap.ativo = TRUE
            AND ap.partida_id <> @partidaId
            AND outra.status IN ('AGENDADA', 'EM_ANDAMENTO')
            AND outra.data_hora BETWEEN atual.data_hora - INTERVAL '2 hours'
                                    AND atual.data_hora + INTERVAL '2 hours'
          LIMIT 1
        '''),
        parameters: {'partidaId': matchId, 'arbitroId': refereeId},
      );
      if (conflict.isNotEmpty) {
        throw const ApiException(
          409,
          'O árbitro já possui uma partida no mesmo horário.',
        );
      }

      await tx.execute(
        Sql.named('''
          UPDATE arbitragem_partida
          SET ativo = FALSE, encerrado_em = NOW()
          WHERE partida_id = @partidaId
            AND funcao = @funcao
            AND ativo = TRUE
        '''),
        parameters: {'partidaId': matchId, 'funcao': normalizedRole},
      );

      final result = await tx.execute(
        Sql.named('''
          INSERT INTO arbitragem_partida
            (partida_id, arbitro_id, funcao, designado_por)
          VALUES
            (@partidaId, @arbitroId, @funcao, @usuarioId)
          RETURNING id, partida_id, arbitro_id, funcao, ativo, designado_em
        '''),
        parameters: {
          'partidaId': matchId,
          'arbitroId': refereeId,
          'funcao': normalizedRole,
          'usuarioId': actorUserId,
        },
      );

      if (normalizedRole == 'PRINCIPAL') {
        await tx.execute(
          Sql.named(
            'UPDATE partida SET arbitro_id = @arbitroId, atualizado_em = NOW() WHERE id = @partidaId',
          ),
          parameters: {'partidaId': matchId, 'arbitroId': refereeId},
        );
      }

      await _auditWithTx(tx, actorUserId, 'REGISTRAR_ARBITRAGEM', matchId, {
        'arbitroId': refereeId,
        'funcao': normalizedRole,
      });
      return result.single.toColumnMap();
    });
  }

  Future<Map<String, dynamic>> registerResult(
    String matchId,
    int homeScore,
    int awayScore,
    String actorUserId,
  ) async {
    if (homeScore < 0 || awayScore < 0) {
      throw const ApiException(
        400,
        'O placar não pode possuir valores negativos.',
      );
    }

    return _database.pool.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
          UPDATE partida
          SET placar_casa = @placarCasa,
              placar_visitante = @placarVisitante,
              status = 'ENCERRADA',
              encerrada_em = NOW(),
              atualizado_em = NOW()
          WHERE id = @id AND status IN ('AGENDADA', 'EM_ANDAMENTO')
          RETURNING id, competicao_id, time_casa_id, time_visitante_id,
                    placar_casa, placar_visitante, status, encerrada_em
        '''),
        parameters: {
          'id': matchId,
          'placarCasa': homeScore,
          'placarVisitante': awayScore,
        },
      );
      if (result.isEmpty) {
        throw const ApiException(
          409,
          'Partida não encontrada ou já encerrada.',
        );
      }
      await _auditWithTx(tx, actorUserId, 'REGISTRAR_RESULTADO', matchId, {
        'placarCasa': homeScore,
        'placarVisitante': awayScore,
      });
      return result.single.toColumnMap();
    });
  }

  Future<Map<String, dynamic>> registerScore(
    String matchId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final athleteId = data['alunoId']?.toString();
    final teamId = data['timeId']?.toString();
    final points = int.tryParse(data['pontos']?.toString() ?? '');
    if (teamId == null || points == null || points <= 0) {
      throw const ApiException(400, 'Informe timeId e pontos positivos.');
    }

    return _database.pool.runTx((tx) async {
      final event = await tx.execute(
        Sql.named('''
          INSERT INTO evento_partida
            (partida_id, tipo, time_id, aluno_id, minuto, valor, observacao, registrado_por)
          SELECT @partidaId, 'PONTUACAO', @timeId, CAST(@alunoId AS uuid),
                 @minuto, @pontos, @observacao, @usuarioId
          FROM partida p
          WHERE p.id = @partidaId
            AND p.status = 'EM_ANDAMENTO'
            AND CAST(@timeId AS uuid) IN (p.time_casa_id, p.time_visitante_id)
            AND (
              CAST(@alunoId AS uuid) IS NULL OR EXISTS (
                SELECT 1 FROM time_aluno ta
                WHERE ta.time_id = @timeId
                  AND ta.aluno_id = CAST(@alunoId AS uuid)
                  AND ta.ativo = TRUE
              )
            )
          RETURNING id, partida_id, tipo, time_id, aluno_id, minuto, valor, criado_em
        '''),
        parameters: {
          'partidaId': matchId,
          'timeId': teamId,
          'alunoId': athleteId,
          'minuto': data['minuto'],
          'pontos': points,
          'observacao': data['observacao'],
          'usuarioId': actorUserId,
        },
      );
      if (event.isEmpty) {
        throw const ApiException(
          409,
          'Partida, time ou atleta inválido para registrar a pontuação.',
        );
      }

      if (athleteId != null && athleteId.isNotEmpty) {
        await tx.execute(
          Sql.named('''
            INSERT INTO participacao_atleta (partida_id, aluno_id, time_id, pontos)
            VALUES (@partidaId, @alunoId, @timeId, @pontos)
            ON CONFLICT (partida_id, aluno_id)
            DO UPDATE SET pontos = participacao_atleta.pontos + EXCLUDED.pontos,
                          atualizado_em = NOW()
          '''),
          parameters: {
            'partidaId': matchId,
            'alunoId': athleteId,
            'timeId': teamId,
            'pontos': points,
          },
        );
      }

      final score = await tx.execute(
        Sql.named('''
          UPDATE partida
          SET placar_casa = COALESCE(placar_casa, 0) +
                CASE WHEN time_casa_id = @timeId THEN @pontos ELSE 0 END,
              placar_visitante = COALESCE(placar_visitante, 0) +
                CASE WHEN time_visitante_id = @timeId THEN @pontos ELSE 0 END,
              atualizado_em = NOW()
          WHERE id = @partidaId
          RETURNING placar_casa, placar_visitante
        '''),
        parameters: {'partidaId': matchId, 'timeId': teamId, 'pontos': points},
      );

      await _auditWithTx(tx, actorUserId, 'REGISTRAR_PONTUACAO', matchId, {
        'timeId': teamId,
        'alunoId': athleteId,
        'pontos': points,
        'minuto': data['minuto'],
      });
      return {
        'evento': event.single.toColumnMap(),
        'placar': score.single.toColumnMap(),
      };
    });
  }

  Future<Map<String, dynamic>> registerPenalty(
    String matchId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final type = data['tipo']?.toString().toUpperCase();
    const allowed = {
      'FALTA',
      'CARTAO_AMARELO',
      'CARTAO_VERMELHO',
      'PENALIDADE',
    };
    if (type == null || !allowed.contains(type)) {
      throw const ApiException(400, 'Tipo de penalidade inválido.');
    }
    final teamId = data['timeId']?.toString();
    if (teamId == null || teamId.isEmpty) {
      throw const ApiException(400, 'Informe timeId.');
    }

    return _database.pool.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
          INSERT INTO evento_partida
            (partida_id, tipo, time_id, aluno_id, minuto, valor, observacao, registrado_por)
          SELECT @partidaId, @tipo, @timeId, CAST(@alunoId AS uuid),
                 @minuto, 1, @observacao, @usuarioId
          FROM partida p
          WHERE p.id = @partidaId
            AND p.status = 'EM_ANDAMENTO'
            AND CAST(@timeId AS uuid) IN (p.time_casa_id, p.time_visitante_id)
            AND (
              CAST(@alunoId AS uuid) IS NULL OR EXISTS (
                SELECT 1 FROM time_aluno ta
                WHERE ta.time_id = @timeId
                  AND ta.aluno_id = CAST(@alunoId AS uuid)
                  AND ta.ativo = TRUE
              )
            )
          RETURNING id, partida_id, tipo, time_id, aluno_id, minuto, observacao, criado_em
        '''),
        parameters: {
          'partidaId': matchId,
          'tipo': type,
          'timeId': teamId,
          'alunoId': data['alunoId'],
          'minuto': data['minuto'],
          'observacao': data['observacao'],
          'usuarioId': actorUserId,
        },
      );
      if (result.isEmpty) {
        throw const ApiException(
          409,
          'Não foi possível registrar a falta ou penalidade.',
        );
      }

      final athleteId = data['alunoId']?.toString();
      if (athleteId != null && athleteId.isNotEmpty) {
        final field = switch (type) {
          'FALTA' => 'faltas',
          'CARTAO_AMARELO' => 'cartoes_amarelos',
          'CARTAO_VERMELHO' => 'cartoes_vermelhos',
          _ => null,
        };
        if (field != null) {
          await tx.execute(
            Sql.named('''
              INSERT INTO participacao_atleta
                (partida_id, aluno_id, time_id, $field)
              VALUES
                (@partidaId, @alunoId, @timeId, 1)
              ON CONFLICT (partida_id, aluno_id)
              DO UPDATE SET $field = participacao_atleta.$field + 1,
                            atualizado_em = NOW()
            '''),
            parameters: {
              'partidaId': matchId,
              'alunoId': athleteId,
              'timeId': teamId,
            },
          );
        }
      }
      await _auditWithTx(tx, actorUserId, 'REGISTRAR_PENALIDADE', matchId, {
        'timeId': teamId,
        'alunoId': data['alunoId'],
        'tipo': type,
        'minuto': data['minuto'],
      });
      return result.single.toColumnMap();
    });
  }

  Future<Map<String, dynamic>> matchReport(String matchId) async {
    final match = await _database.pool.execute(
      Sql.named('''
        SELECT p.id, p.data_hora, COALESCE(lp.nome, p.local) AS local, p.status,
               p.placar_casa, p.placar_visitante,
               c.nome AS competicao, m.nome AS modalidade,
               tc.nome AS time_casa, tv.nome AS time_visitante
        FROM partida p
        JOIN competicao c ON c.id = p.competicao_id
        LEFT JOIN modalidade m ON m.id = c.modalidade_id
        LEFT JOIN local_partida lp ON lp.id = p.local_partida_id
        JOIN time_esportivo tc ON tc.id = p.time_casa_id
        JOIN time_esportivo tv ON tv.id = p.time_visitante_id
        WHERE p.id = @id
      '''),
      parameters: {'id': matchId},
    );
    if (match.isEmpty) {
      throw const ApiException(404, 'Partida não encontrada.');
    }

    final arbitration = await _database.pool.execute(
      Sql.named('''
        SELECT ap.id, ap.funcao, ap.designado_em,
               a.id AS arbitro_id, u.nome AS arbitro
        FROM arbitragem_partida ap
        JOIN arbitro a ON a.id = ap.arbitro_id
        JOIN usuario u ON u.id = a.usuario_id
        WHERE ap.partida_id = @id AND ap.ativo = TRUE
        ORDER BY CASE WHEN ap.funcao = 'PRINCIPAL' THEN 0 ELSE 1 END, ap.funcao
      '''),
      parameters: {'id': matchId},
    );

    final events = await _database.pool.execute(
      Sql.named('''
        SELECT ep.id, ep.tipo, ep.minuto, ep.valor, ep.observacao,
               t.nome AS time, u.nome AS atleta, ep.criado_em
        FROM evento_partida ep
        LEFT JOIN time_esportivo t ON t.id = ep.time_id
        LEFT JOIN aluno a ON a.id = ep.aluno_id
        LEFT JOIN usuario u ON u.id = a.usuario_id
        WHERE ep.partida_id = @id
        ORDER BY ep.minuto NULLS LAST, ep.criado_em
      '''),
      parameters: {'id': matchId},
    );

    return {
      'partida': match.single.toColumnMap(),
      'arbitragem': arbitration.map((row) => row.toColumnMap()).toList(),
      'eventos': events.map((row) => row.toColumnMap()).toList(),
    };
  }

  Future<Map<String, dynamic>> issueMatchReport(
    String matchId,
    String actorUserId,
  ) async {
    final report = await matchReport(matchId);
    final match = Map<String, dynamic>.from(report['partida'] as Map);
    if (match['status']?.toString() != 'ENCERRADA') {
      throw const ApiException(
        409,
        'A súmula definitiva exige uma partida encerrada.',
      );
    }

    return _database.pool.runTx((tx) async {
      final locked = await tx.execute(
        Sql.named(
          "SELECT id FROM partida WHERE id = @id AND status = 'ENCERRADA' FOR UPDATE",
        ),
        parameters: {'id': matchId},
      );
      if (locked.isEmpty) {
        throw const ApiException(
          409,
          'A partida não está disponível para emissão da súmula.',
        );
      }
      final result = await tx.execute(
        Sql.named('''
          INSERT INTO sumula_partida (partida_id, versao, conteudo, emitida_por)
          SELECT @partidaId,
                 COALESCE(MAX(s.versao), 0) + 1,
                 CAST(@conteudo AS jsonb),
                 @usuarioId
          FROM sumula_partida s
          WHERE s.partida_id = @partidaId
          RETURNING id, partida_id, versao, emitida_por, emitida_em
        '''),
        parameters: {
          'partidaId': matchId,
          'conteudo': _jsonSafe(report),
          'usuarioId': actorUserId,
        },
      );
      await _auditWithTx(tx, actorUserId, 'EMITIR_SUMULA', matchId, {
        'versao': result.single.toColumnMap()['versao'],
      });
      return {...result.single.toColumnMap(), 'conteudo': report};
    });
  }

  Future<List<Map<String, dynamic>>> history({
    String? competitionId,
    String? teamId,
    DateTime? from,
    DateTime? to,
    required int page,
    required int limit,
  }) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT p.id, p.data_hora, COALESCE(lp.nome, p.local) AS local, p.status,
               p.placar_casa, p.placar_visitante,
               c.id AS competicao_id, c.nome AS competicao,
               tc.id AS time_casa_id, tc.nome AS time_casa,
               tv.id AS time_visitante_id, tv.nome AS time_visitante
        FROM partida p
        JOIN competicao c ON c.id = p.competicao_id
        LEFT JOIN local_partida lp ON lp.id = p.local_partida_id
        JOIN time_esportivo tc ON tc.id = p.time_casa_id
        JOIN time_esportivo tv ON tv.id = p.time_visitante_id
        WHERE p.status = 'ENCERRADA'
          AND (CAST(@competicaoId AS uuid) IS NULL OR p.competicao_id = CAST(@competicaoId AS uuid))
          AND (
            CAST(@timeId AS uuid) IS NULL OR
            p.time_casa_id = CAST(@timeId AS uuid) OR
            p.time_visitante_id = CAST(@timeId AS uuid)
          )
          AND (CAST(@de AS timestamptz) IS NULL OR p.data_hora >= CAST(@de AS timestamptz))
          AND (CAST(@ate AS timestamptz) IS NULL OR p.data_hora <= CAST(@ate AS timestamptz))
        ORDER BY p.data_hora DESC
        LIMIT @limite OFFSET @deslocamento
      '''),
      parameters: {
        'competicaoId': competitionId,
        'timeId': teamId,
        'de': from,
        'ate': to,
        'limite': limit,
        'deslocamento': (page - 1) * limit,
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<void> _auditWithTx(
    Session executor,
    String actorUserId,
    String action,
    String matchId,
    Map<String, dynamic> data,
  ) async {
    await executor.execute(
      Sql.named('''
        INSERT INTO log_auditoria
          (usuario_id, acao, entidade, entidade_id, dados_novos)
        VALUES
          (@usuarioId, @acao, 'PARTIDA', @partidaId, CAST(@dados AS jsonb))
      '''),
      parameters: {
        'usuarioId': actorUserId,
        'acao': action,
        'partidaId': matchId,
        'dados': _jsonSafe(data),
      },
    );
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
}
