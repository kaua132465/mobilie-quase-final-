import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/api_exception.dart';
import '../core/http_helpers.dart';
import '../middleware/auth.dart';
import '../repositories/aluno_repository.dart';
import '../repositories/competicao_repository.dart';
import '../repositories/documento_repository.dart';
import '../repositories/partida_repository.dart';
import '../services/auth_service.dart';

class ApiRouter {
  ApiRouter({
    required AlunoRepository alunos,
    required DocumentoRepository documentos,
    required CompeticaoRepository competicoes,
    required PartidaRepository partidas,
    required AuthService auth,
  }) : _alunos = alunos,
       _documentos = documentos,
       _competicoes = competicoes,
       _partidas = partidas,
       _auth = auth;

  final AlunoRepository _alunos;
  final DocumentoRepository _documentos;
  final CompeticaoRepository _competicoes;
  final PartidaRepository _partidas;
  final AuthService _auth;

  Handler get handler {
    final public = Router()
      ..get('/saude', _health)
      ..post('/auth/login', _login)
      ..post('/auth/alunos/login', _login);

    final protected = Router()
      // Rotas fixas ficam antes das rotas com parâmetros.
      ..get('/documentos/tipos', _documentTypes)
      ..get('/documentos/pendentes', _pendingDocuments)
      ..get('/partidas/calendario', _calendar)
      ..get('/partidas/historico', _matchHistory)
      ..get('/rankings/individual', _individualRanking)
      ..get('/locais', _listLocations)
      ..post('/locais', _createLocation)
      ..get('/alunos', _listStudents)
      ..post('/alunos', _createStudent)
      ..get('/competicoes', _listCompetitions)
      ..post('/competicoes', _createCompetition)
      ..get('/documentos/<id>/arquivo', _documentFile)
      ..patch('/documentos/<id>/validacao', _validateDocument)
      ..get('/alunos/<id>', _studentDetail)
      ..put('/alunos/<id>', _updateStudent)
      ..delete('/alunos/<id>', _deleteStudent)
      ..get('/alunos/<id>/historico', _studentHistory)
      ..get('/alunos/<id>/estatisticas', _studentStatistics)
      ..get('/alunos/<id>/documentos', _studentDocuments)
      ..post('/alunos/<id>/documentos', _saveStudentDocument)
      ..put('/alunos/<id>/documentos/<documentoId>', _replaceStudentDocument)
      ..delete('/alunos/<id>/documentos/<documentoId>', _removeStudentDocument)
      ..get('/competicoes/<id>', _competitionDetail)
      ..put('/competicoes/<id>', _updateCompetition)
      ..delete('/competicoes/<id>', _deleteCompetition)
      ..post('/competicoes/<id>/edicoes', _createEdition)
      ..put('/competicoes/<id>/modalidades/<modalidadeId>', _configureModality)
      ..delete('/competicoes/<id>/modalidades/<modalidadeId>', _removeModality)
      ..put('/competicoes/<id>/categorias/<categoriaId>', _configureCategory)
      ..delete('/competicoes/<id>/categorias/<categoriaId>', _removeCategory)
      ..put('/competicoes/<id>/fases', _savePhases)
      ..post('/competicoes/<id>/chaveamentos', _generateBracket)
      ..post('/competicoes/<id>/partidas/gerar', _generateMatches)
      ..put('/competicoes/<id>/calendario', _scheduleCompetition)
      ..post('/competicoes/<id>/inscricoes', _enrollTeam)
      ..delete('/competicoes/<id>/inscricoes/<timeId>', _cancelEnrollment)
      ..patch('/competicoes/<id>/encerrar', _closeCompetition)
      ..get('/competicoes/<id>/classificacao', _standings)
      ..put('/partidas/<id>/calendario', _scheduleMatch)
      ..put('/partidas/<id>/local', _assignLocation)
      ..post('/partidas/<id>/arbitragem', _assignReferee)
      ..put('/partidas/<id>/resultado', _registerResult)
      ..post('/partidas/<id>/pontuacoes', _registerScore)
      ..post('/partidas/<id>/penalidades', _registerPenalty)
      ..post('/partidas/<id>/sumula', _issueMatchReport)
      ..get('/partidas/<id>/sumula', _matchReport);

    return Cascade()
        .add(public.call)
        .add(
          Pipeline()
              .addMiddleware(jwtAuthentication())
              .addHandler(protected.call),
        )
        .handler;
  }

  Response _health(Request request) =>
      ok({'status': 'ok', 'servico': 'ACE API'});

  Future<Response> _login(Request request) async {
    final body = await readJsonObject(request);
    final email = body['email']?.toString() ?? '';
    final password = body['senha']?.toString() ?? '';
    if (email.isEmpty || password.isEmpty) {
      throw const ApiException(400, 'Informe e-mail e senha.');
    }
    return ok(await _auth.login(email, password));
  }

  Future<Response> _createStudent(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ESCOLA'});
    final body = await readJsonObject(request);
    final password = body.remove('senha')?.toString() ?? '';
    final result = await _alunos.create(
      body,
      _auth.hashPassword(password),
      _userId(request),
    );
    return created(result);
  }

  Future<Response> _listStudents(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ESCOLA', 'ORGANIZADOR'});
    final query = request.url.queryParameters;
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 20, max: 100);
    final items = await _alunos.list(
      search: query['busca'],
      schoolId: query['escolaId'],
      page: page,
      limit: limit,
    );
    return ok({'pagina': page, 'limite': limit, 'itens': items});
  }

  Future<Response> _studentDetail(Request request, String id) async {
    _requireStudentAccess(request, id);
    return ok(await _alunos.detail(id));
  }

  Future<Response> _updateStudent(Request request, String id) async {
    _requireStudentAccess(request, id, allowStudent: true);
    final body = await readJsonObject(request);
    if (request.context['perfil']?.toString().toUpperCase() == 'ALUNO') {
      const restricted = {'escolaId', 'cpf', 'dataNascimento', 'matricula'};
      if (body.keys.any(restricted.contains)) {
        throw const ApiException(
          403,
          'O aluno não pode alterar escola, CPF, nascimento ou matrícula.',
        );
      }
    }
    return ok(await _alunos.update(id, body, _userId(request)));
  }

  Future<Response> _deleteStudent(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ESCOLA'});
    await _alunos.softDelete(id, _userId(request));
    return noContent();
  }

  Future<Response> _studentHistory(Request request, String id) async {
    _requireStudentAccess(request, id);
    return ok(await _alunos.history(id));
  }

  Future<Response> _studentStatistics(Request request, String id) async {
    _requireStudentAccess(request, id);
    return ok(await _alunos.statistics(id));
  }

  Future<Response> _individualRanking(Request request) async {
    final query = request.url.queryParameters;
    return ok(
      await _alunos.ranking(
        competitionId: query['competicaoId'],
        modalityId: query['modalidadeId'],
        limit: parsePositiveInt(query['limite'], fallback: 50, max: 200),
      ),
    );
  }

  Future<Response> _documentTypes(Request request) async =>
      ok(await _documentos.listTypes());

  Future<Response> _studentDocuments(Request request, String id) async {
    _requireStudentAccess(request, id);
    return ok(await _documentos.listForStudent(id));
  }

  Future<Response> _saveStudentDocument(Request request, String id) async {
    _requireStudentAccess(request, id, allowStudent: true);
    return created(
      await _documentos.save(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _replaceStudentDocument(
    Request request,
    String id,
    String documentoId,
  ) async {
    _requireStudentAccess(request, id, allowStudent: true);
    return ok(
      await _documentos.save(
        id,
        await readJsonObject(request),
        _userId(request),
        documentId: documentoId,
      ),
    );
  }

  Future<Response> _removeStudentDocument(
    Request request,
    String id,
    String documentoId,
  ) async {
    _requireStudentAccess(request, id, allowStudent: true);
    await _documentos.remove(id, documentoId, _userId(request));
    return noContent();
  }

  Future<Response> _pendingDocuments(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ESCOLA'});
    final query = request.url.queryParameters;
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 20, max: 100);
    final items = await _documentos.pending(
      schoolId: query['escolaId'],
      status: query['status'],
      page: page,
      limit: limit,
    );
    return ok({'pagina': page, 'limite': limit, 'itens': items});
  }

  Future<Response> _validateDocument(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ESCOLA'});
    return ok(
      await _documentos.validate(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _documentFile(Request request, String id) async {
    final file = await _documentos.file(id);
    _requireStudentAccess(request, file['aluno_id'].toString());
    final url = file['url_arquivo']?.toString();
    final content = file['arquivo_conteudo'];
    if (content == null && url != null && url.isNotEmpty) {
      return Response(302, headers: {'location': url});
    }
    if (content is! List<int>) {
      throw const ApiException(404, 'Conteúdo do documento indisponível.');
    }
    final fileName = file['nome_arquivo'].toString().replaceAll('"', '');
    return Response.ok(
      content,
      headers: {
        'content-type': file['mime_type'].toString(),
        'content-length': content.length.toString(),
        'content-disposition': 'attachment; filename="$fileName"',
        'cache-control': 'private, no-store',
      },
    );
  }

  Future<Response> _createCompetition(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    return created(
      await _competicoes.create(
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _listCompetitions(Request request) async {
    final query = request.url.queryParameters;
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 20, max: 100);
    final items = await _competicoes.list(
      search: query['busca'],
      status: query['status'],
      modalityId: query['modalidadeId'],
      from: _optionalDate(query['de']),
      to: _optionalDate(query['ate']),
      page: page,
      limit: limit,
    );
    return ok({'pagina': page, 'limite': limit, 'itens': items});
  }

  Future<Response> _competitionDetail(Request request, String id) async =>
      ok(await _competicoes.detail(id));

  Future<Response> _updateCompetition(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    return ok(
      await _competicoes.update(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _deleteCompetition(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    final body = await readJsonObject(request);
    final justification = body['justificativa']?.toString() ?? '';
    return ok(
      await _competicoes.deleteLogical(id, justification, _userId(request)),
    );
  }

  Future<Response> _createEdition(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    return created(
      await _competicoes.createEdition(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _configureModality(
    Request request,
    String id,
    String modalidadeId,
  ) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    return ok(
      await _competicoes.configureModality(
        id,
        modalidadeId,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _removeModality(
    Request request,
    String id,
    String modalidadeId,
  ) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    await _competicoes.removeModality(id, modalidadeId, _userId(request));
    return noContent();
  }

  Future<Response> _configureCategory(
    Request request,
    String id,
    String categoriaId,
  ) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    return ok(
      await _competicoes.configureCategory(
        id,
        categoriaId,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _removeCategory(
    Request request,
    String id,
    String categoriaId,
  ) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    await _competicoes.removeCategory(id, categoriaId, _userId(request));
    return noContent();
  }

  Future<Response> _savePhases(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    final body = await readJsonObject(request);
    final phases = body['fases'];
    if (phases is! List) {
      throw const ApiException(400, 'Informe o array fases.');
    }
    return ok(await _competicoes.savePhases(id, phases, _userId(request)));
  }

  Future<Response> _generateBracket(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    return created(
      await _competicoes.generateBracket(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _generateMatches(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    return created(
      await _competicoes.generateMatches(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _scheduleCompetition(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR'});
    final body = await readJsonObject(request);
    final matches = body['partidas'];
    if (matches is! List) {
      throw const ApiException(400, 'Informe o array partidas.');
    }
    return ok(
      await _competicoes.scheduleCompetition(id, matches, _userId(request)),
    );
  }

  Future<Response> _calendar(Request request) async {
    final query = request.url.queryParameters;
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 20, max: 100);
    final items = await _competicoes.calendar(
      competitionId: query['competicaoId'],
      teamId: query['timeId'],
      locationId: query['localId'],
      from: _optionalDateTime(query['de']),
      to: _optionalDateTime(query['ate']),
      page: page,
      limit: limit,
    );
    return ok({'pagina': page, 'limite': limit, 'itens': items});
  }

  Future<Response> _scheduleMatch(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR'});
    return ok(
      await _competicoes.scheduleMatch(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _createLocation(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR'});
    return created(
      await _competicoes.createLocation(
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _listLocations(Request request) async {
    final query = request.url.queryParameters;
    return ok(
      await _competicoes.listLocations(
        search: query['busca'],
        modalityId: query['modalidadeId'],
      ),
    );
  }

  Future<Response> _assignLocation(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR'});
    final body = await readJsonObject(request);
    final locationId = body['localId']?.toString();
    if (locationId == null || locationId.isEmpty) {
      throw const ApiException(400, 'Informe localId.');
    }
    return ok(
      await _competicoes.assignLocation(id, locationId, _userId(request)),
    );
  }

  Future<Response> _enrollTeam(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR', 'ESCOLA'});
    final body = await readJsonObject(request);
    final teamId = body['timeId']?.toString();
    if (teamId == null || teamId.isEmpty) {
      throw const ApiException(400, 'Informe timeId.');
    }
    return created(await _competicoes.enrollTeam(id, teamId, _userId(request)));
  }

  Future<Response> _cancelEnrollment(
    Request request,
    String id,
    String timeId,
  ) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR', 'ESCOLA'});
    await _competicoes.cancelEnrollment(id, timeId, _userId(request));
    return noContent();
  }

  Future<Response> _closeCompetition(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR'});
    return ok(await _competicoes.closeCompetition(id, _userId(request)));
  }

  Future<Response> _standings(Request request, String id) async =>
      ok(await _competicoes.standings(id));

  Future<Response> _assignReferee(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR'});
    final body = await readJsonObject(request);
    final refereeId = body['arbitroId']?.toString();
    if (refereeId == null || refereeId.isEmpty) {
      throw const ApiException(400, 'Informe arbitroId.');
    }
    return ok(
      await _partidas.assignReferee(
        id,
        refereeId,
        body['funcao']?.toString() ?? 'PRINCIPAL',
        _userId(request),
      ),
    );
  }

  Future<Response> _registerResult(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR', 'ARBITRO'});
    final body = await readJsonObject(request);
    final home = int.tryParse(body['placarCasa']?.toString() ?? '');
    final away = int.tryParse(body['placarVisitante']?.toString() ?? '');
    if (home == null || away == null) {
      throw const ApiException(400, 'Informe placarCasa e placarVisitante.');
    }
    return ok(await _partidas.registerResult(id, home, away, _userId(request)));
  }

  Future<Response> _registerScore(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR', 'ARBITRO'});
    return created(
      await _partidas.registerScore(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _registerPenalty(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR', 'ARBITRO'});
    return created(
      await _partidas.registerPenalty(
        id,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _matchReport(Request request, String id) async =>
      ok(await _partidas.matchReport(id));

  Future<Response> _issueMatchReport(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR', 'ARBITRO'});
    return created(await _partidas.issueMatchReport(id, _userId(request)));
  }

  Future<Response> _matchHistory(Request request) async {
    final query = request.url.queryParameters;
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 20, max: 100);
    final items = await _partidas.history(
      competitionId: query['competicaoId'],
      teamId: query['timeId'],
      from: _optionalDateTime(query['de']),
      to: _optionalDateTime(query['ate']),
      page: page,
      limit: limit,
    );
    return ok({'pagina': page, 'limite': limit, 'itens': items});
  }

  String _userId(Request request) {
    final id = request.context['usuarioId']?.toString();
    if (id == null || id.isEmpty) {
      throw const ApiException(401, 'Usuário não identificado.');
    }
    return id;
  }

  void _requireProfile(Request request, Set<String> allowed) {
    final profile = request.context['perfil']?.toString().toUpperCase();
    if (profile == null || !allowed.contains(profile)) {
      throw const ApiException(403, 'Perfil sem permissão para esta operação.');
    }
  }

  void _requireStudentAccess(
    Request request,
    String studentId, {
    bool allowStudent = true,
  }) {
    final profile = request.context['perfil']?.toString().toUpperCase();
    final ownStudentId = request.context['alunoId']?.toString();
    final privileged = {
      'ADMINISTRADOR',
      'ESCOLA',
      'ORGANIZADOR',
    }.contains(profile);
    final ownsRecord =
        allowStudent && profile == 'ALUNO' && ownStudentId == studentId;
    if (!privileged && !ownsRecord) {
      throw const ApiException(
        403,
        'Sem permissão para consultar ou alterar este aluno.',
      );
    }
  }

  DateTime? _optionalDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null)
      throw const ApiException(400, 'Data de filtro inválida.');
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime? _optionalDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null)
      throw const ApiException(400, 'Data e hora de filtro inválida.');
    return parsed;
  }
}
