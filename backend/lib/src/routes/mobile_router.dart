import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/api_exception.dart';
import '../core/http_helpers.dart';
import '../middleware/auth.dart';
import '../repositories/aluno_repository.dart';
import '../repositories/competicao_repository.dart';
import '../repositories/escola_repository.dart';
import '../repositories/mobile_repository.dart';
import '../repositories/partida_repository.dart';
import '../repositories/time_repository.dart';
import '../services/auth_service.dart';

/// Rotas desenhadas a partir dos wireframes Mobile e dos casos classificados
/// como "Mobile e PC" ou "Apenas Mobile" no documento Divisão por Dispositivo.
class MobileRouter {
  MobileRouter({
    required AuthService auth,
    required EscolaRepository escolas,
    required AlunoRepository alunos,
    required TimeRepository times,
    required CompeticaoRepository competicoes,
    required PartidaRepository partidas,
    required MobileRepository mobile,
  }) : _auth = auth,
       _escolas = escolas,
       _alunos = alunos,
       _times = times,
       _competicoes = competicoes,
       _partidas = partidas,
       _mobile = mobile;

  final AuthService _auth;
  final EscolaRepository _escolas;
  final AlunoRepository _alunos;
  final TimeRepository _times;
  final CompeticaoRepository _competicoes;
  final PartidaRepository _partidas;
  final MobileRepository _mobile;

  Handler get handler {
    final public = Router()
      ..get('/saude', _health)
      ..post('/auth/login', _login)
      ..post('/auth/recuperacao/solicitar', _requestPasswordRecovery)
      ..post('/auth/recuperacao/confirmar', _confirmPasswordRecovery);

    final protected = Router()
      // Dashboard e dados auxiliares dos formulários.
      ..get('/dashboard', _dashboard)
      ..get('/modalidades', _modalities)
      ..get('/categorias', _categories)
      // Perfil e consulta de escolas.
      ..get('/perfil/escola', _ownSchoolProfile)
      ..put('/perfil/escola', _updateOwnSchoolProfile)
      ..get('/escolas', _listSchools)
      ..get('/escolas/codigo/<codigo>', _schoolByCode)
      ..get('/escolas/<id>', _schoolDetail)
      // Alunos/atletas.
      ..get('/alunos', _listStudents)
      ..post('/alunos', _createStudent)
      ..get('/rankings/individual', _individualRanking)
      ..get('/alunos/<id>/historico', _studentHistory)
      ..get('/alunos/<id>/estatisticas', _studentStatistics)
      ..get('/alunos/<id>', _studentDetail)
      ..put('/alunos/<id>', _updateStudent)
      // Times.
      ..get('/times', _listTeams)
      ..post('/times', _createTeam)
      ..get('/times/<id>/ranking', _teamPerformance)
      ..put('/times/<id>/capitao', _defineCaptain)
      ..put('/times/<id>/escalacao', _saveLineup)
      ..post('/times/<id>/atletas/<alunoId>', _linkAthlete)
      ..patch('/times/<id>/atletas/<alunoId>', _updateAthleteRole)
      ..delete('/times/<id>/atletas/<alunoId>', _unlinkAthlete)
      ..get('/times/<id>', _teamDetail)
      ..put('/times/<id>', _updateTeam)
      // Competições, calendário, local e inscrição.
      ..get('/competicoes', _listCompetitions)
      ..get('/competicoes/<id>/classificacao', _competitionStandings)
      ..get('/competicoes/<id>/tabela', _tablesAndStandings)
      ..post('/competicoes/<id>/inscricoes', _enrollTeam)
      ..get('/competicoes/<id>', _competitionDetail)
      ..get('/calendario', _calendar)
      ..put('/partidas/<id>/calendario', _scheduleMatch)
      ..get('/locais', _listLocations)
      ..post('/locais', _createLocation)
      ..put('/partidas/<id>/local', _assignLocation)
      // Operação de partidas e atualização em tempo real por polling.
      ..get('/partidas/ao-vivo', _liveMatches)
      ..get('/partidas/historico', _matchHistory)
      ..get('/partidas/<id>/ao-vivo', _liveMatchDetail)
      ..patch('/partidas/<id>/iniciar', _startMatch)
      ..post('/partidas/<id>/arbitragem', _assignReferee)
      ..put('/partidas/<id>/resultado', _registerResult)
      ..post('/partidas/<id>/pontuacoes', _registerScore)
      ..post('/partidas/<id>/penalidades', _registerPenalty)
      ..post('/partidas/<id>/publicar', _publishResult)
      // Rankings e acompanhamento.
      ..get('/rankings/escolas', _schoolRanking)
      ..get('/rankings/equipes', _teamRanking);

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
      ok({'status': 'ok', 'servico': 'ACE Mobile API', 'versao': '2.0.0'});

  Future<Response> _login(Request request) async {
    final body = await readJsonObject(request);
    final email = body['email']?.toString() ?? '';
    final password = body['senha']?.toString() ?? '';
    if (email.isEmpty || password.isEmpty) {
      throw const ApiException(400, 'Informe e-mail e senha.');
    }
    return ok(await _auth.login(email, password));
  }

  Future<Response> _requestPasswordRecovery(Request request) async {
    final body = await readJsonObject(request);
    final forwarded = request.headers['x-forwarded-for'];
    final ip = forwarded?.split(',').first.trim();
    return ok(
      await _auth.requestPasswordRecovery(
        body['email']?.toString() ?? '',
        requesterIp: ip,
      ),
    );
  }

  Future<Response> _confirmPasswordRecovery(Request request) async {
    final body = await readJsonObject(request);
    await _auth.resetPassword(
      email: body['email']?.toString() ?? '',
      code: body['codigo']?.toString() ?? '',
      newPassword: body['novaSenha']?.toString() ?? '',
    );
    return ok({'mensagem': 'Senha alterada com sucesso.'});
  }

  Future<Response> _dashboard(Request request) async {
    final profile = _profile(request);
    final schoolId = profile == 'ESCOLA' ? _schoolId(request) : null;
    return ok(await _mobile.dashboard(schoolId: schoolId));
  }

  Future<Response> _modalities(Request request) async =>
      ok(await _escolas.modalities());

  Future<Response> _categories(Request request) async =>
      ok(await _escolas.categories());

  Future<Response> _ownSchoolProfile(Request request) async {
    _requireProfile(request, {'ESCOLA'});
    return ok(await _escolas.detail(_schoolId(request)));
  }

  Future<Response> _updateOwnSchoolProfile(Request request) async {
    _requireProfile(request, {'ESCOLA'});
    return ok(
      await _escolas.updateProfile(
        _schoolId(request),
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _listSchools(Request request) async {
    return ok(
      await _escolas.list(search: request.url.queryParameters['busca']),
    );
  }

  Future<Response> _schoolByCode(Request request, String codigo) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR'});
    return ok(await _escolas.findByCode(codigo));
  }

  Future<Response> _schoolDetail(Request request, String id) async {
    final profile = _profile(request);
    if (profile == 'ESCOLA' && _schoolId(request) != id) {
      throw const ApiException(
        403,
        'A escola só pode acessar o próprio perfil.',
      );
    }
    return ok(await _escolas.detail(id));
  }

  Future<Response> _createStudent(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ESCOLA'});
    final body = await readJsonObject(request);
    if (_profile(request) == 'ESCOLA') {
      body['escolaId'] = _schoolId(request);
    }
    final informedPassword = body.remove('senha')?.toString().trim() ?? '';
    final temporaryPassword = informedPassword.isEmpty
        ? _auth.generateTemporaryPassword()
        : null;
    final result = await _alunos.create(
      body,
      _auth.hashPassword(temporaryPassword ?? informedPassword),
      _userId(request),
    );
    return created({
      ...result,
      if (temporaryPassword != null) 'senhaTemporaria': temporaryPassword,
      'requerTrocaDeSenha': temporaryPassword != null,
    });
  }

  Future<Response> _listStudents(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ESCOLA', 'ORGANIZADOR'});
    final query = request.url.queryParameters;
    final schoolId = _profile(request) == 'ESCOLA'
        ? _schoolId(request)
        : query['escolaId'];
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 30, max: 100);
    return ok({
      'pagina': page,
      'limite': limit,
      'itens': await _alunos.list(
        search: query['busca'],
        schoolId: schoolId,
        page: page,
        limit: limit,
      ),
    });
  }

  Future<Response> _studentDetail(Request request, String id) async {
    final student = await _alunos.detail(id);
    _ensureStudentAccess(request, id, student);
    return ok(student);
  }

  Future<Response> _updateStudent(Request request, String id) async {
    final student = await _alunos.detail(id);
    _ensureStudentAccess(request, id, student, allowStudent: true);
    final body = await readJsonObject(request);
    if (_profile(request) == 'ALUNO') {
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

  Future<Response> _studentHistory(Request request, String id) async {
    final student = await _alunos.detail(id);
    _ensureStudentAccess(request, id, student);
    return ok(await _alunos.history(id));
  }

  Future<Response> _studentStatistics(Request request, String id) async {
    final student = await _alunos.detail(id);
    _ensureStudentAccess(request, id, student);
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

  Future<Response> _listTeams(Request request) async {
    final query = request.url.queryParameters;
    final schoolId = _profile(request) == 'ESCOLA'
        ? _schoolId(request)
        : query['escolaId'];
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 30, max: 100);
    return ok({
      'pagina': page,
      'limite': limit,
      'itens': await _times.list(
        search: query['busca'],
        schoolId: schoolId,
        modalityId: query['modalidadeId'],
        categoryId: query['categoriaId'],
        page: page,
        limit: limit,
      ),
    });
  }

  Future<Response> _createTeam(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ESCOLA'});
    final body = await readJsonObject(request);
    final schoolId = _profile(request) == 'ESCOLA'
        ? _schoolId(request)
        : body['escolaId']?.toString();
    if (schoolId == null || schoolId.isEmpty) {
      throw const ApiException(400, 'Informe escolaId.');
    }
    return created(await _times.create(body, schoolId, _userId(request)));
  }

  Future<Response> _teamDetail(Request request, String id) async {
    final team = await _times.detail(id);
    _ensureTeamReadAccess(request, team);
    return ok(team);
  }

  Future<Response> _updateTeam(Request request, String id) async {
    final team = await _times.detail(id);
    _ensureTeamWriteAccess(request, team);
    return ok(
      await _times.update(id, await readJsonObject(request), _userId(request)),
    );
  }

  Future<Response> _linkAthlete(
    Request request,
    String id,
    String alunoId,
  ) async {
    final team = await _times.detail(id);
    _ensureTeamWriteAccess(request, team);
    return ok(
      await _times.linkAthlete(
        id,
        alunoId,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _updateAthleteRole(
    Request request,
    String id,
    String alunoId,
  ) async {
    final team = await _times.detail(id);
    _ensureTeamWriteAccess(request, team);
    return ok(
      await _times.updateAthleteRole(
        id,
        alunoId,
        await readJsonObject(request),
        _userId(request),
      ),
    );
  }

  Future<Response> _unlinkAthlete(
    Request request,
    String id,
    String alunoId,
  ) async {
    final team = await _times.detail(id);
    _ensureTeamWriteAccess(request, team);
    await _times.unlinkAthlete(id, alunoId, _userId(request));
    return noContent();
  }

  Future<Response> _defineCaptain(Request request, String id) async {
    final team = await _times.detail(id);
    _ensureTeamWriteAccess(request, team);
    final body = await readJsonObject(request);
    final athleteId = body['alunoId']?.toString();
    if (athleteId == null || athleteId.isEmpty) {
      throw const ApiException(400, 'Informe alunoId.');
    }
    return ok(await _times.defineCaptain(id, athleteId, _userId(request)));
  }

  Future<Response> _saveLineup(Request request, String id) async {
    final team = await _times.detail(id);
    _ensureTeamWriteAccess(request, team);
    final body = await readJsonObject(request);
    final athletes = body['atletas'];
    if (athletes is! List) {
      throw const ApiException(400, 'Informe o array atletas.');
    }
    return ok(await _times.saveLineup(id, athletes, _userId(request)));
  }

  Future<Response> _teamPerformance(Request request, String id) async {
    final team = await _times.detail(id);
    _ensureTeamReadAccess(request, team);
    return ok(await _times.ranking(id));
  }

  Future<Response> _listCompetitions(Request request) async {
    final query = request.url.queryParameters;
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 30, max: 100);
    return ok({
      'pagina': page,
      'limite': limit,
      'itens': await _competicoes.list(
        search: query['busca'],
        status: query['status'],
        modalityId: query['modalidadeId'],
        from: _optionalDate(query['de']),
        to: _optionalDate(query['ate']),
        page: page,
        limit: limit,
      ),
    });
  }

  Future<Response> _competitionDetail(Request request, String id) async =>
      ok(await _competicoes.detail(id));

  Future<Response> _calendar(Request request) async {
    final query = request.url.queryParameters;
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 30, max: 100);
    return ok({
      'pagina': page,
      'limite': limit,
      'itens': await _competicoes.calendar(
        competitionId: query['competicaoId'],
        teamId: query['timeId'],
        locationId: query['localId'],
        from: _optionalDateTime(query['de']),
        to: _optionalDateTime(query['ate']),
        page: page,
        limit: limit,
      ),
    });
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

  Future<Response> _listLocations(Request request) async {
    final query = request.url.queryParameters;
    return ok(
      await _competicoes.listLocations(
        search: query['busca'],
        modalityId: query['modalidadeId'],
      ),
    );
  }

  Future<Response> _createLocation(Request request) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR'});
    return created(
      await _competicoes.createLocation(
        await readJsonObject(request),
        _userId(request),
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
    if (_profile(request) == 'ESCOLA') {
      final team = await _times.detail(teamId);
      _ensureTeamWriteAccess(request, team);
    }
    return created(await _competicoes.enrollTeam(id, teamId, _userId(request)));
  }

  Future<Response> _competitionStandings(Request request, String id) async =>
      ok(await _competicoes.standings(id));

  Future<Response> _tablesAndStandings(Request request, String id) async =>
      ok(await _mobile.tablesAndStandings(id));

  Future<Response> _liveMatches(Request request) async {
    final query = request.url.queryParameters;
    final schoolId = _profile(request) == 'ESCOLA'
        ? _schoolId(request)
        : query['escolaId'];
    return ok(
      await _mobile.liveMatches(
        schoolId: schoolId,
        competitionId: query['competicaoId'],
        limit: parsePositiveInt(query['limite'], fallback: 20, max: 100),
      ),
    );
  }

  Future<Response> _liveMatchDetail(Request request, String id) async =>
      ok(await _mobile.liveMatchDetail(id));

  Future<Response> _startMatch(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR', 'ARBITRO'});
    return ok(await _mobile.startMatch(id, _userId(request)));
  }

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

  Future<Response> _publishResult(Request request, String id) async {
    _requireProfile(request, {'ADMINISTRADOR', 'ORGANIZADOR', 'ARBITRO'});
    return ok(await _mobile.publishResult(id, _userId(request)));
  }

  Future<Response> _matchHistory(Request request) async {
    final query = request.url.queryParameters;
    final page = parsePositiveInt(query['pagina'], fallback: 1, max: 100000);
    final limit = parsePositiveInt(query['limite'], fallback: 30, max: 100);
    return ok({
      'pagina': page,
      'limite': limit,
      'itens': await _partidas.history(
        competitionId: query['competicaoId'],
        teamId: query['timeId'],
        from: _optionalDateTime(query['de']),
        to: _optionalDateTime(query['ate']),
        page: page,
        limit: limit,
      ),
    });
  }

  Future<Response> _schoolRanking(Request request) async {
    final query = request.url.queryParameters;
    return ok(
      await _mobile.schoolRanking(
        competitionId: query['competicaoId'],
        modalityId: query['modalidadeId'],
        limit: parsePositiveInt(query['limite'], fallback: 50, max: 200),
      ),
    );
  }

  Future<Response> _teamRanking(Request request) async {
    final query = request.url.queryParameters;
    return ok(
      await _mobile.teamRanking(
        competitionId: query['competicaoId'],
        modalityId: query['modalidadeId'],
        limit: parsePositiveInt(query['limite'], fallback: 50, max: 200),
      ),
    );
  }

  String _profile(Request request) =>
      request.context['perfil']?.toString().toUpperCase() ?? '';

  String _userId(Request request) {
    final id = request.context['usuarioId']?.toString();
    if (id == null || id.isEmpty) {
      throw const ApiException(401, 'Usuário não identificado.');
    }
    return id;
  }

  String _schoolId(Request request) {
    final id = request.context['escolaId']?.toString();
    if (id == null || id.isEmpty) {
      throw const ApiException(403, 'Usuário não está vinculado a uma escola.');
    }
    return id;
  }

  void _requireProfile(Request request, Set<String> allowed) {
    if (!allowed.contains(_profile(request))) {
      throw const ApiException(403, 'Perfil sem permissão para esta operação.');
    }
  }

  void _ensureStudentAccess(
    Request request,
    String studentId,
    Map<String, dynamic> student, {
    bool allowStudent = true,
  }) {
    final profile = _profile(request);
    if ({'ADMINISTRADOR', 'ORGANIZADOR'}.contains(profile)) return;
    if (profile == 'ESCOLA' &&
        student['escola_id']?.toString() == _schoolId(request)) {
      return;
    }
    if (allowStudent &&
        profile == 'ALUNO' &&
        request.context['alunoId']?.toString() == studentId) {
      return;
    }
    throw const ApiException(403, 'Sem permissão para acessar este atleta.');
  }

  void _ensureTeamReadAccess(Request request, Map<String, dynamic> team) {
    final profile = _profile(request);
    if (profile == 'ESCOLA' &&
        team['escola_id']?.toString() != _schoolId(request)) {
      throw const ApiException(
        403,
        'A escola só pode acessar os próprios times.',
      );
    }
  }

  void _ensureTeamWriteAccess(Request request, Map<String, dynamic> team) {
    final profile = _profile(request);
    if (profile == 'ADMINISTRADOR') return;
    if (profile == 'ESCOLA' &&
        team['escola_id']?.toString() == _schoolId(request)) {
      return;
    }
    throw const ApiException(403, 'Sem permissão para alterar este time.');
  }

  DateTime? _optionalDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const ApiException(400, 'Data inválida.');
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime? _optionalDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const ApiException(400, 'Data e hora inválidas.');
    return parsed;
  }
}
