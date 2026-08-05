import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../core/api_exception.dart';
import '../core/database.dart';

class DocumentoRepository {
  DocumentoRepository(this._database);

  final Database _database;

  Future<List<Map<String, dynamic>>> listTypes() async {
    final result = await _database.pool.execute('''
      SELECT id, nome, descricao, obrigatorio, extensoes_permitidas,
             tamanho_maximo_bytes
      FROM tipo_documento
      WHERE ativo = TRUE
      ORDER BY obrigatorio DESC, nome
    ''');
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<List<Map<String, dynamic>>> listForStudent(String studentId) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT d.id, d.aluno_id, d.tipo_documento_id,
               COALESCE(td.nome, d.tipo) AS tipo,
               d.nome_arquivo, d.mime_type, d.tamanho_bytes,
               d.url_arquivo, d.status, d.observacao,
               d.validado_por, d.validado_em, d.criado_em, d.atualizado_em
        FROM documento_atleta d
        LEFT JOIN tipo_documento td ON td.id = d.tipo_documento_id
        WHERE d.aluno_id = @alunoId AND d.ativo = TRUE
        ORDER BY td.obrigatorio DESC NULLS LAST, tipo, d.criado_em DESC
      '''),
      parameters: {'alunoId': studentId},
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> save(
    String studentId,
    Map<String, dynamic> data,
    String actorUserId, {
    String? documentId,
  }) async {
    final typeId = data['tipoDocumentoId']?.toString();
    final fileName = _safeFileName(data['nomeArquivo']?.toString() ?? '');
    final mimeType = data['mimeType']?.toString().trim().toLowerCase() ?? '';
    final base64Content = data['arquivoBase64']?.toString();
    final url = data['urlArquivo']?.toString().trim();

    if (typeId == null || typeId.isEmpty || fileName.isEmpty || mimeType.isEmpty) {
      throw const ApiException(
        400,
        'Informe tipoDocumentoId, nomeArquivo e mimeType.',
      );
    }
    if ((base64Content == null || base64Content.isEmpty) &&
        (url == null || url.isEmpty)) {
      throw const ApiException(400, 'Informe arquivoBase64 ou urlArquivo.');
    }

    List<int>? bytes;
    if (base64Content != null && base64Content.isNotEmpty) {
      try {
        bytes = base64Decode(base64Content);
      } on FormatException {
        throw const ApiException(400, 'O conteúdo Base64 do arquivo é inválido.');
      }
    }

    final typeResult = await _database.pool.execute(
      Sql.named('''
        SELECT id, nome, extensoes_permitidas, tamanho_maximo_bytes
        FROM tipo_documento
        WHERE id = @id AND ativo = TRUE
      '''),
      parameters: {'id': typeId},
    );
    if (typeResult.isEmpty) {
      throw const ApiException(404, 'Tipo de documento não encontrado.');
    }
    final type = typeResult.single.toColumnMap();
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final allowedExtensions = (type['extensoes_permitidas'] as List?)
            ?.map((item) => item.toString().toLowerCase())
            .toSet() ??
        <String>{};
    if (extension.isEmpty || !allowedExtensions.contains(extension)) {
      throw ApiException(
        400,
        'Extensão não permitida. Use: ${allowedExtensions.join(', ')}.',
      );
    }
    final size = bytes?.length ?? int.tryParse(data['tamanhoBytes']?.toString() ?? '');
    if (size == null || size < 0) {
      throw const ApiException(400, 'Informe tamanhoBytes para documentos por URL.');
    }
    final maxSize = int.parse(type['tamanho_maximo_bytes'].toString());
    if (size > maxSize) {
      throw ApiException(400, 'O arquivo excede o limite de $maxSize bytes.');
    }

    return _database.pool.runTx((tx) async {
      final studentExists = await tx.execute(
        Sql.named('SELECT 1 FROM aluno WHERE id = @id AND ativo = TRUE'),
        parameters: {'id': studentId},
      );
      if (studentExists.isEmpty) {
        throw const ApiException(404, 'Aluno não encontrado.');
      }

      late Result result;
      if (documentId == null) {
        result = await tx.execute(
          Sql.named('''
            INSERT INTO documento_atleta
              (aluno_id, tipo_documento_id, tipo, nome_arquivo, mime_type,
               tamanho_bytes, arquivo_conteudo, url_arquivo, status,
               observacao, enviado_por)
            VALUES
              (@alunoId, @tipoId, @tipo, @nomeArquivo, @mimeType,
               @tamanho, @conteudo, @url, 'PENDENTE', @observacao, @usuarioId)
            RETURNING id, aluno_id, tipo_documento_id, tipo, nome_arquivo,
                      mime_type, tamanho_bytes, url_arquivo, status, criado_em
          '''),
          parameters: {
            'alunoId': studentId,
            'tipoId': typeId,
            'tipo': type['nome'],
            'nomeArquivo': fileName,
            'mimeType': mimeType,
            'tamanho': size,
            'conteudo': bytes,
            'url': url,
            'observacao': data['observacao'],
            'usuarioId': actorUserId,
          },
        );
      } else {
        result = await tx.execute(
          Sql.named('''
            UPDATE documento_atleta
            SET tipo_documento_id = @tipoId,
                tipo = @tipo,
                nome_arquivo = @nomeArquivo,
                mime_type = @mimeType,
                tamanho_bytes = @tamanho,
                arquivo_conteudo = @conteudo,
                url_arquivo = @url,
                status = 'PENDENTE',
                observacao = @observacao,
                enviado_por = @usuarioId,
                validado_por = NULL,
                validado_em = NULL,
                atualizado_em = NOW()
            WHERE id = @documentoId
              AND aluno_id = @alunoId
              AND ativo = TRUE
            RETURNING id, aluno_id, tipo_documento_id, tipo, nome_arquivo,
                      mime_type, tamanho_bytes, url_arquivo, status, atualizado_em
          '''),
          parameters: {
            'documentoId': documentId,
            'alunoId': studentId,
            'tipoId': typeId,
            'tipo': type['nome'],
            'nomeArquivo': fileName,
            'mimeType': mimeType,
            'tamanho': size,
            'conteudo': bytes,
            'url': url,
            'observacao': data['observacao'],
            'usuarioId': actorUserId,
          },
        );
      }
      if (result.isEmpty) {
        throw const ApiException(404, 'Documento não encontrado.');
      }

      await _audit(
        tx,
        actorUserId,
        documentId == null ? 'ENVIAR_DOCUMENTO' : 'SUBSTITUIR_DOCUMENTO',
        result.single.toColumnMap()['id'].toString(),
        {'alunoId': studentId, 'nomeArquivo': fileName, 'tipoId': typeId},
      );
      return result.single.toColumnMap();
    });
  }

  Future<void> remove(
    String studentId,
    String documentId,
    String actorUserId,
  ) async {
    await _database.pool.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
          UPDATE documento_atleta
          SET ativo = FALSE,
              removido_por = @usuarioId,
              removido_em = NOW(),
              atualizado_em = NOW()
          WHERE id = @documentoId
            AND aluno_id = @alunoId
            AND ativo = TRUE
          RETURNING id, nome_arquivo, status
        '''),
        parameters: {
          'documentoId': documentId,
          'alunoId': studentId,
          'usuarioId': actorUserId,
        },
      );
      if (result.isEmpty) {
        throw const ApiException(404, 'Documento não encontrado.');
      }
      await _audit(
        tx,
        actorUserId,
        'REMOVER_DOCUMENTO',
        documentId,
        result.single.toColumnMap(),
      );
    });
  }

  Future<Map<String, dynamic>> file(String documentId) async {
    final result = await _database.pool.execute(
      Sql.named('''
        SELECT id, aluno_id, nome_arquivo, mime_type, tamanho_bytes,
               arquivo_conteudo, url_arquivo
        FROM documento_atleta
        WHERE id = @id AND ativo = TRUE
      '''),
      parameters: {'id': documentId},
    );
    if (result.isEmpty) {
      throw const ApiException(404, 'Documento não encontrado.');
    }
    return result.single.toColumnMap();
  }

  Future<List<Map<String, dynamic>>> pending({
    String? schoolId,
    String? status,
    required int page,
    required int limit,
  }) async {
    final normalizedStatus = status?.trim().toUpperCase();
    const valid = {
      'PENDENTE',
      'EM_ANALISE',
      'APROVADA',
      'REJEITADA',
      'CORRECAO_SOLICITADA',
    };
    if (normalizedStatus != null && !valid.contains(normalizedStatus)) {
      throw const ApiException(400, 'Status de documentação inválido.');
    }

    final result = await _database.pool.execute(
      Sql.named('''
        SELECT d.id, d.aluno_id, u.nome AS atleta, e.id AS escola_id,
               e.nome AS escola, COALESCE(td.nome, d.tipo) AS tipo,
               d.nome_arquivo, d.mime_type, d.tamanho_bytes,
               d.status, d.observacao, d.criado_em
        FROM documento_atleta d
        JOIN aluno a ON a.id = d.aluno_id
        JOIN usuario u ON u.id = a.usuario_id
        JOIN escola e ON e.id = a.escola_id
        LEFT JOIN tipo_documento td ON td.id = d.tipo_documento_id
        WHERE d.ativo = TRUE
          AND (CAST(@escolaId AS uuid) IS NULL OR a.escola_id = CAST(@escolaId AS uuid))
          AND (CAST(@status AS status_documentacao) IS NULL OR d.status = CAST(@status AS status_documentacao))
        ORDER BY CASE d.status
                   WHEN 'PENDENTE' THEN 0
                   WHEN 'EM_ANALISE' THEN 1
                   WHEN 'CORRECAO_SOLICITADA' THEN 2
                   ELSE 3
                 END,
                 d.criado_em
        LIMIT @limite OFFSET @deslocamento
      '''),
      parameters: {
        'escolaId': schoolId,
        'status': normalizedStatus ?? 'PENDENTE',
        'limite': limit,
        'deslocamento': (page - 1) * limit,
      },
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>> validate(
    String documentId,
    Map<String, dynamic> data,
    String actorUserId,
  ) async {
    final status = data['status']?.toString().trim().toUpperCase();
    const allowed = {'APROVADA', 'REJEITADA', 'CORRECAO_SOLICITADA'};
    if (status == null || !allowed.contains(status)) {
      throw const ApiException(400, 'Decisão de validação inválida.');
    }
    final justification = data['justificativa']?.toString().trim();
    if (status != 'APROVADA' && (justification == null || justification.isEmpty)) {
      throw const ApiException(400, 'Informe a justificativa da decisão.');
    }

    return _database.pool.runTx((tx) async {
      final updated = await tx.execute(
        Sql.named('''
          UPDATE documento_atleta
          SET status = CAST(@status AS status_documentacao),
              observacao = @justificativa,
              validado_por = @usuarioId,
              validado_em = NOW(),
              atualizado_em = NOW()
          WHERE id = @id AND ativo = TRUE
          RETURNING id, aluno_id, status, observacao, validado_por, validado_em
        '''),
        parameters: {
          'id': documentId,
          'status': status,
          'justificativa': justification,
          'usuarioId': actorUserId,
        },
      );
      if (updated.isEmpty) {
        throw const ApiException(404, 'Documento não encontrado.');
      }
      await tx.execute(
        Sql.named('''
          INSERT INTO validacao_documento
            (documento_id, status, justificativa, validado_por)
          VALUES
            (@id, CAST(@status AS status_documentacao), @justificativa, @usuarioId)
        '''),
        parameters: {
          'id': documentId,
          'status': status,
          'justificativa': justification,
          'usuarioId': actorUserId,
        },
      );
      await _audit(
        tx,
        actorUserId,
        'VALIDAR_DOCUMENTO',
        documentId,
        {'status': status, 'justificativa': justification},
      );
      return updated.single.toColumnMap();
    });
  }

  Future<void> _audit(
    Session executor,
    String actorUserId,
    String action,
    String documentId,
    Object? data,
  ) async {
    await executor.execute(
      Sql.named('''
        INSERT INTO log_auditoria
          (usuario_id, acao, entidade, entidade_id, dados_novos)
        VALUES
          (@usuarioId, @acao, 'DOCUMENTO_ATLETA', @documentoId,
           CAST(@dados AS jsonb))
      '''),
      parameters: {
        'usuarioId': actorUserId,
        'acao': action,
        'documentoId': documentId,
        'dados': jsonEncode(data),
      },
    );
  }

  String _safeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\\/]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '');
  }
}
