import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:aether_backend/src/core/database.dart';
import 'package:aether_backend/src/middleware/cors.dart';
import 'package:aether_backend/src/middleware/error_handler.dart';
import 'package:aether_backend/src/repositories/aluno_repository.dart';
import 'package:aether_backend/src/repositories/competicao_repository.dart';
import 'package:aether_backend/src/repositories/escola_repository.dart';
import 'package:aether_backend/src/repositories/mobile_repository.dart';
import 'package:aether_backend/src/repositories/documento_repository.dart';
import 'package:aether_backend/src/repositories/partida_repository.dart';
import 'package:aether_backend/src/repositories/time_repository.dart';
import 'package:aether_backend/src/repositories/usuario_repository.dart';
import 'package:aether_backend/src/routes/api_router.dart';
import 'package:aether_backend/src/routes/mobile_router.dart';
import 'package:aether_backend/src/services/auth_service.dart';
import 'package:aether_backend/src/services/email_service.dart';

Future<void> main() async {
  final database = Database.fromEnvironment();
  await database.testConnection();

  final usuarios = UsuarioRepository(database);
  final escolas = EscolaRepository(database);
  final alunos = AlunoRepository(database);
  final times = TimeRepository(database);
  final documentos = DocumentoRepository(database);
  final competicoes = CompeticaoRepository(database);
  final partidas = PartidaRepository(database);
  final mobileRepository = MobileRepository(database);
  final email = EmailService.fromEnvironment();
  final auth = AuthService(usuarios, email);

  final api = ApiRouter(
    alunos: alunos,
    documentos: documentos,
    competicoes: competicoes,
    partidas: partidas,
    auth: auth,
  );

  final mobile = MobileRouter(
    auth: auth,
    escolas: escolas,
    alunos: alunos,
    times: times,
    competicoes: competicoes,
    partidas: partidas,
    mobile: mobileRepository,
  );

  final rootRouter = Router()
    ..mount('/api/mobile/', mobile.handler)
    ..mount('/api/', api.handler);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware(errorHandler())
      .addHandler(rootRouter.call);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Aether API (geral + mobile) disponível em http://${server.address.host}:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    await database.close();
    exit(0);
  });
}
