import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../core/api_exception.dart';
import '../core/database.dart';

class MobileRepository {
  MobileRepository(this._database);

  final Database _database;

  Future<Map<String, dynamic>> dashboard({String? schoolId}) async {
    final counters = await _database.pool.execute(
      Sql.named('''
        SELECT
          (SELECT COUNT(*)::int FROM partida p
             JOIN time_esportivo tc ON tc.id = p.time_casa_id
             JOIN time_esportivo tv ON tv.id = p.time_visitante_id
            WHERE p.status <> 'CANCELADA'
              AND p.data_hora::date = CURRENT_DATE
              AND (CAST(@escolaId AS uuid) IS NULL OR
                   tc.escola_id = CAST(@escolaId AS uuid) OR
                   tv.escola_id = CAST(@escolaId AS uuid))) AS jogos_hoje,
          (SELECT COUNT(*)::int FROM competicao c
            WHERE c.ativo = TRUE AND c.status IN ('INSCRICOES_ABERTAS', 'EM_ANDAMENTO')) AS competicoes,
          (SELECT COUNT(*)::int FROM time_esportivo t
            WHERE t.ativo = TRUE
              AND (CAST(@escolaId AS uuid) IS NULL OR t.escola_id = CAST(@escolaId AS uuid))) AS times,
          (SELECT COUNT(*)::int FROM aluno a
            WHERE a.ativo = TRUE
              AND (CAST(@escolaId AS uuid) IS NULL OR a.escola_id = CAST(@escolaId AS uuid))) AS atletas
      '''),
      parameters: {'escolaId': _nullable(schoolId)},
    );

    final live = await liveMatches(schoolId: schoolId, limit: 4);
    final upcoming = await _database.pool.execute(
      Sql.named('''
        SELECT p.id, p.data_hora, p.status,
               c.id AS competicao_id, c.nome AS competicao,
               tc.id AS time_casa_id, tc.nome AS time_casa,
               tv.id AS time_visitante_id, tv.nome AS time_visitante,
               COALESCE(lp.nome, p.local) AS local
        FROM partida p
        JOIN competicao c ON c.id = p.competicao_id
        JOIN time_esportivo tc ON tc.id = p.time_casa_id
        JOIN time_esportivo tv ON tv.id = p.time_visitante_id
        LEFT JOIN local_partida lp ON lp.id = p.local_partida_id
        WHERE p.status IN ('PLANEJADA', 'AGENDADA')
          AND p.data_hora >= NOW()
          AND (CAST(@escolaId AS uuid) IS NULL OR
               tc.escola_id = CAST(@escolaId AS uuid) OR
               tv.escola_id = CAST(@escolaId AS uuid))
        ORDER BY p.data_hora
        LIMIT 5
      '''),
      parameters: {'escolaId': _nullable(schoolId)},
    );

    final ranking = await schoolRanking(limit: 5);
    return {
      'resumo': counters.single.toColumnMap(),
      'partidasAoVivo': live,
      'proximosJogos': upcoming.map((row) => row.toColumnMap()).toList(),
      'rankingEscolas': ranking,
      'atualizadoEm': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> liveMatches({
    String? schoolId,
    String? competitionId,
    int limit = 20,
  }) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT p.id, p.data_hora, p.status, p.placar_casa, p.placar_visitante,
               p.atualizado_em,
               c.id AS competicao_id, c.nome AS competicao,
               f.id AS fase_id, f.nome AS fase,
               tc.id AS time_casa_id, tc.nome AS time_casa,
               tv.id AS time_visitante_id, tv.nome AS time_visitante,
               COALESCE(lp.nome, p.local) AS local,
               EXISTS (
                 SELECT 1 FROM resultado_publicado rp
                 WHERE rp.partida_id = p.id AND rp.revogado_em IS NULL
               ) AS publicado
        FROM partida p
        JOIN competicao c ON c.id = p.competicao_id
        JOIN time_esportivo tc ON tc.id = p.time_casa_id
        JOIN time_esportivo tv ON tv.id = p.time_visitante_id
        LEFT JOIN fase_competicao f ON f.id = p.fase_id
        LEFT JOIN local_partida lp ON lp.id = p.local_partida_id
        WHERE p.status = 'EM_ANDAMENTO'
          AND (CAST(@competicaoId AS uuid) IS NULL OR p.competicao_id = CAST(@competicaoId AS uuid))
          AND (CAST(@escolaId AS uuid) IS NULL OR
               tc.escola_id = CAST(@escolaId AS uuid) OR
               tv.escola_id = CAST(@escolaId AS uuid))
        ORDER BY p.data_hora DESC NULLS LAST, p.atualizado_em DESC
        LIMIT @limite
      '''),
      parameters: {
        'escolaId': _nullable(schoolId),
        'competicaoId': _nullable(competitionId),
        'limite': limit,
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> liveMatchDetail(String matchId) async {
    final match = await _database.pool.execute(
      Sql.named('''
        SELECT p.id, p.data_hora, p.status, p.placar_casa, p.placar_visitante,
               p.observacoes, p.atualizado_em,
               c.id AS competicao_id, c.nome AS competicao,
               f.id AS fase_id, f.nome AS fase,
               tc.id AS time_casa_id, tc.nome AS time_casa,
               tv.id AS time_visitante_id, tv.nome AS time_visitante,
               COALESCE(lp.nome, p.local) AS local,
               EXISTS (
                 SELECT 1 FROM resultado_publicado rp
                 WHERE rp.partida_id = p.id AND rp.revogado_em IS NULL
               ) AS publicado
        FROM partida p
        JOIN competicao c ON c.id = p.competicao_id
        JOIN time_esportivo tc ON tc.id = p.time_casa_id
        JOIN time_esportivo tv ON tv.id = p.time_visitante_id
        LEFT JOIN fase_competicao f ON f.id = p.fase_id
        LEFT JOIN local_partida lp ON lp.id = p.local_partida_id
        WHERE p.id = @id AND p.status <> 'CANCELADA'
      '''),
      parameters: {'id': matchId},
    );
    if (match.isEmpty) {
      throw const ApiException(404, 'Partida não encontrada.');
    }

    final events = await _database.pool.execute(
      Sql.named('''
        SELECT ev.id, ev.tipo, ev.time_id, t.nome AS time,
               ev.aluno_id, u.nome AS atleta, ev.minuto,
               ev.valor, ev.observacao, ev.criado_em
        FROM evento_partida ev
        LEFT JOIN time_esportivo t ON t.id = ev.time_id
        LEFT JOIN aluno a ON a.id = ev.aluno_id
        LEFT JOIN usuario u ON u.id = a.usuario_id
        WHERE ev.partida_id = @id
        ORDER BY ev.criado_em, ev.minuto NULLS LAST
      '''),
      parameters: {'id': matchId},
    );

    final referees = await _database.pool.execute(
      Sql.named('''
        SELECT ap.funcao, ar.id AS arbitro_id, u.nome AS arbitro,
               ap.designado_em
        FROM arbitragem_partida ap
        JOIN arbitro ar ON ar.id = ap.arbitro_id
        JOIN usuario u ON u.id = ar.usuario_id
        WHERE ap.partida_id = @id AND ap.ativo = TRUE
        ORDER BY ap.funcao
      '''),
      parameters: {'id': matchId},
    );

    final data = match.single.toColumnMap();
    data['eventos'] = events.map((row) => row.toColumnMap()).toList();
    data['arbitragem'] = referees.map((row) => row.toColumnMap()).toList();
    return data;
  }

  Future<Map<String, dynamic>> startMatch(
    String matchId,
    String actorUserId,
  ) async {
    final result = await _database.pool.runTx((tx) async {
      final updated = await tx.execute(
        Sql.named('''
          UPDATE partida
          SET status = 'EM_ANDAMENTO',
              placar_casa = COALESCE(placar_casa, 0),
              placar_visitante = COALESCE(placar_visitante, 0),
              atualizado_em = NOW()
          WHERE id = @id AND status = 'AGENDADA'
          RETURNING id
        '''),
        parameters: {'id': matchId},
      );
      if (updated.isEmpty) {
        throw const ApiException(
          409,
          'A partida não está agendada ou já foi iniciada.',
        );
      }
      await tx.execute(
        Sql.named('''
          INSERT INTO log_auditoria
            (usuario_id, acao, entidade, entidade_id)
          VALUES
            (@usuarioId, 'INICIAR_PARTIDA', 'PARTIDA', @partidaId)
        '''),
        parameters: {
          'usuarioId': actorUserId,
          'partidaId': matchId,
        },
      );
      return updated.single.toColumnMap();
    });
    return {...result, 'partida': await liveMatchDetail(matchId)};
  }

  Future<Map<String, dynamic>> publishResult(
    String matchId,
    String actorUserId,
  ) async {
    await _database.pool.runTx((tx) async {
      final match = await tx.execute(
        Sql.named('''
          SELECT id, status, placar_casa, placar_visitante
          FROM partida
          WHERE id = @id AND status IN ('EM_ANDAMENTO', 'ENCERRADA')
          FOR UPDATE
        '''),
        parameters: {'id': matchId},
      );
      if (match.isEmpty) {
        throw const ApiException(
          409,
          'A partida precisa estar em andamento ou encerrada para publicação.',
        );
      }
      final row = match.single.toColumnMap();
      if (row['placar_casa'] == null || row['placar_visitante'] == null) {
        throw const ApiException(409, 'Registre o placar antes de publicar.');
      }

      await tx.execute(
        Sql.named('''
          INSERT INTO resultado_publicado (partida_id, publicado_por)
          VALUES (@partidaId, @usuarioId)
          ON CONFLICT (partida_id) DO UPDATE SET
            publicado_por = EXCLUDED.publicado_por,
            publicado_em = NOW(),
            revogado_em = NULL
        '''),
        parameters: {'partidaId': matchId, 'usuarioId': actorUserId},
      );

      await tx.execute(
        Sql.named('''
          INSERT INTO log_auditoria
            (usuario_id, acao, entidade, entidade_id, dados_novos)
          VALUES
            (@usuarioId, 'PUBLICAR_RESULTADO', 'PARTIDA', @partidaId,
             CAST(@dados AS jsonb))
        '''),
        parameters: {
          'usuarioId': actorUserId,
          'partidaId': matchId,
          'dados': jsonEncode({
            'placarCasa': row['placar_casa'],
            'placarVisitante': row['placar_visitante'],
          }),
        },
      );
    });
    return liveMatchDetail(matchId);
  }

  Future<List<Map<String, dynamic>>> schoolRanking({
    String? competitionId,
    String? modalityId,
    int limit = 50,
  }) async {
    final result = await _database.pool.execute(
      Sql.named('''
        WITH jogos AS (
          SELECT tc.escola_id,
                 CASE
                   WHEN p.placar_casa > p.placar_visitante THEN 3
                   WHEN p.placar_casa = p.placar_visitante THEN 1
                   ELSE 0
                 END AS pontos,
                 CASE WHEN p.placar_casa > p.placar_visitante THEN 1 ELSE 0 END AS vitoria,
                 p.placar_casa AS pro,
                 p.placar_visitante AS contra
          FROM partida p
          JOIN time_esportivo tc ON tc.id = p.time_casa_id
          JOIN competicao c ON c.id = p.competicao_id
          WHERE p.status = 'ENCERRADA'
            AND (CAST(@competicaoId AS uuid) IS NULL OR p.competicao_id = CAST(@competicaoId AS uuid))
            AND (CAST(@modalidadeId AS uuid) IS NULL OR c.modalidade_id = CAST(@modalidadeId AS uuid))
          UNION ALL
          SELECT tv.escola_id,
                 CASE
                   WHEN p.placar_visitante > p.placar_casa THEN 3
                   WHEN p.placar_visitante = p.placar_casa THEN 1
                   ELSE 0
                 END,
                 CASE WHEN p.placar_visitante > p.placar_casa THEN 1 ELSE 0 END,
                 p.placar_visitante,
                 p.placar_casa
          FROM partida p
          JOIN time_esportivo tv ON tv.id = p.time_visitante_id
          JOIN competicao c ON c.id = p.competicao_id
          WHERE p.status = 'ENCERRADA'
            AND (CAST(@competicaoId AS uuid) IS NULL OR p.competicao_id = CAST(@competicaoId AS uuid))
            AND (CAST(@modalidadeId AS uuid) IS NULL OR c.modalidade_id = CAST(@modalidadeId AS uuid))
        )
        SELECT e.id AS escola_id, e.nome AS escola,
               COUNT(j.escola_id)::int AS jogos,
               COALESCE(SUM(j.vitoria), 0)::int AS vitorias,
               COALESCE(SUM(j.pro), 0)::int AS pontos_pro,
               COALESCE(SUM(j.contra), 0)::int AS pontos_contra,
               COALESCE(SUM(j.pro - j.contra), 0)::int AS saldo,
               COALESCE(SUM(j.pontos), 0)::int AS pontos
        FROM escola e
        LEFT JOIN jogos j ON j.escola_id = e.id
        WHERE e.ativa = TRUE
        GROUP BY e.id, e.nome
        HAVING COUNT(j.escola_id) > 0
        ORDER BY pontos DESC, saldo DESC, pontos_pro DESC, e.nome
        LIMIT @limite
      '''),
      parameters: {
        'competicaoId': _nullable(competitionId),
        'modalidadeId': _nullable(modalityId),
        'limite': limit,
      },
    );
    return _withPositions(result.map((row) => row.toColumnMap()).toList());
  }

  Future<List<Map<String, dynamic>>> teamRanking({
    String? competitionId,
    String? modalityId,
    int limit = 50,
  }) async {
    if (competitionId != null && competitionId.trim().isNotEmpty) {
      final result = await _database.pool.execute(
        Sql.named('''
          SELECT f.time_id, f.time_nome AS time,
                 e.id AS escola_id, e.nome AS escola,
                 f.jogos::int, f.vitorias::int, f.empates::int,
                 f.derrotas::int, f.gols_pro::int AS pontos_pro,
                 f.gols_contra::int AS pontos_contra,
                 f.saldo_gols::int AS saldo, f.pontos::int
          FROM fn_classificacao_competicao(CAST(@competicaoId AS uuid)) f
          JOIN time_esportivo t ON t.id = f.time_id
          JOIN escola e ON e.id = t.escola_id
          WHERE (CAST(@modalidadeId AS uuid) IS NULL OR t.modalidade_id = CAST(@modalidadeId AS uuid))
          ORDER BY f.pontos DESC, f.saldo_gols DESC, f.gols_pro DESC, f.time_nome
          LIMIT @limite
        '''),
        parameters: {
          'competicaoId': competitionId,
          'modalidadeId': _nullable(modalityId),
          'limite': limit,
        },
      );
      return _withPositions(result.map((row) => row.toColumnMap()).toList());
    }

    final result = await _database.pool.execute(
      Sql.named('''
        WITH jogos AS (
          SELECT p.time_casa_id AS time_id,
                 CASE WHEN p.placar_casa > p.placar_visitante THEN 3
                      WHEN p.placar_casa = p.placar_visitante THEN 1 ELSE 0 END AS pontos,
                 CASE WHEN p.placar_casa > p.placar_visitante THEN 1 ELSE 0 END AS vitoria,
                 CASE WHEN p.placar_casa = p.placar_visitante THEN 1 ELSE 0 END AS empate,
                 p.placar_casa AS pro, p.placar_visitante AS contra
          FROM partida p JOIN competicao c ON c.id = p.competicao_id
          WHERE p.status = 'ENCERRADA'
            AND (CAST(@modalidadeId AS uuid) IS NULL OR c.modalidade_id = CAST(@modalidadeId AS uuid))
          UNION ALL
          SELECT p.time_visitante_id,
                 CASE WHEN p.placar_visitante > p.placar_casa THEN 3
                      WHEN p.placar_visitante = p.placar_casa THEN 1 ELSE 0 END,
                 CASE WHEN p.placar_visitante > p.placar_casa THEN 1 ELSE 0 END,
                 CASE WHEN p.placar_visitante = p.placar_casa THEN 1 ELSE 0 END,
                 p.placar_visitante, p.placar_casa
          FROM partida p JOIN competicao c ON c.id = p.competicao_id
          WHERE p.status = 'ENCERRADA'
            AND (CAST(@modalidadeId AS uuid) IS NULL OR c.modalidade_id = CAST(@modalidadeId AS uuid))
        )
        SELECT t.id AS time_id, t.nome AS time,
               e.id AS escola_id, e.nome AS escola,
               COUNT(j.time_id)::int AS jogos,
               COALESCE(SUM(j.vitoria), 0)::int AS vitorias,
               COALESCE(SUM(j.empate), 0)::int AS empates,
               (COUNT(j.time_id) - COALESCE(SUM(j.vitoria), 0) - COALESCE(SUM(j.empate), 0))::int AS derrotas,
               COALESCE(SUM(j.pro), 0)::int AS pontos_pro,
               COALESCE(SUM(j.contra), 0)::int AS pontos_contra,
               COALESCE(SUM(j.pro - j.contra), 0)::int AS saldo,
               COALESCE(SUM(j.pontos), 0)::int AS pontos
        FROM time_esportivo t
        JOIN escola e ON e.id = t.escola_id
        LEFT JOIN jogos j ON j.time_id = t.id
        WHERE t.ativo = TRUE
        GROUP BY t.id, e.id
        HAVING COUNT(j.time_id) > 0
        ORDER BY pontos DESC, saldo DESC, pontos_pro DESC, t.nome
        LIMIT @limite
      '''),
      parameters: {
        'modalidadeId': _nullable(modalityId),
        'limite': limit,
      },
    );
    return _withPositions(result.map((row) => row.toColumnMap()).toList());
  }

  Future<Map<String, dynamic>> tablesAndStandings(String competitionId) async {
    final competition = await _database.pool.execute(
      Sql.named('''
        SELECT id, nome, status, formato, data_inicio, data_fim
        FROM competicao
        WHERE id = @id AND ativo = TRUE
      '''),
      parameters: {'id': competitionId},
    );
    if (competition.isEmpty) {
      throw const ApiException(404, 'Competição não encontrada.');
    }

    final standings = await _database.pool.execute(
      Sql.named('''
        SELECT *
        FROM fn_classificacao_competicao(CAST(@id AS uuid))
        ORDER BY pontos DESC, saldo_gols DESC, gols_pro DESC, time_nome
      '''),
      parameters: {'id': competitionId},
    );

    final matches = await _database.pool.execute(
      Sql.named('''
        SELECT p.id, p.rodada, p.data_hora, p.status,
               f.nome AS fase,
               tc.nome AS time_casa, tv.nome AS time_visitante,
               p.placar_casa, p.placar_visitante,
               COALESCE(lp.nome, p.local) AS local
        FROM partida p
        JOIN time_esportivo tc ON tc.id = p.time_casa_id
        JOIN time_esportivo tv ON tv.id = p.time_visitante_id
        LEFT JOIN fase_competicao f ON f.id = p.fase_id
        LEFT JOIN local_partida lp ON lp.id = p.local_partida_id
        WHERE p.competicao_id = @id AND p.status <> 'CANCELADA'
        ORDER BY f.ordem NULLS LAST, p.rodada NULLS LAST, p.data_hora NULLS LAST
      '''),
      parameters: {'id': competitionId},
    );

    return {
      'competicao': competition.single.toColumnMap(),
      'classificacao': _withPositions(
        standings.map((row) => row.toColumnMap()).toList(),
      ),
      'partidas': matches.map((row) => row.toColumnMap()).toList(),
    };
  }

  List<Map<String, dynamic>> _withPositions(
    List<Map<String, dynamic>> items,
  ) {
    return [
      for (var index = 0; index < items.length; index++)
        {'posicao': index + 1, ...items[index]},
    ];
  }

  String? _nullable(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
