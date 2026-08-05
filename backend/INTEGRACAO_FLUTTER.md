# Integração do Flutter com a Aether API

O aplicativo Flutter deve consumir a API por HTTP. Ele **não deve acessar o PostgreSQL diretamente**.

## Dependências sugeridas

Adapte as versões ao `pubspec.yaml` do aplicativo:

```yaml
dependencies:
  http: any
  flutter_secure_storage: any
```

## Cliente Dart básico

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AetherApi {
  AetherApi({
    required this.baseUrl,
    http.Client? client,
    FlutterSecureStorage? storage,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final String baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _storage.read(key: 'aether_token');
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  dynamic _validate(http.Response response) {
    final body = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map
          ? body['erro']?.toString() ?? 'Falha na requisição.'
          : 'Falha na requisição.';
      throw ApiException(response.statusCode, message);
    }
    return body;
  }

  Future<void> login(String email, String senha) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/alunos/login'),
      headers: await _headers(json: true),
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    final data = Map<String, dynamic>.from(_validate(response) as Map);
    await _storage.write(
      key: 'aether_token',
      value: data['token'].toString(),
    );
  }

  Future<void> logout() => _storage.delete(key: 'aether_token');

  Future<List<Map<String, dynamic>>> listarAlunos({String? busca}) async {
    final uri = Uri.parse('$baseUrl/api/alunos').replace(
      queryParameters: {
        if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
      },
    );
    final response = await _client.get(uri, headers: await _headers());
    final data = Map<String, dynamic>.from(_validate(response) as Map);
    return (data['itens'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> consultarAluno(String id) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/alunos/$id'),
      headers: await _headers(),
    );
    return Map<String, dynamic>.from(_validate(response) as Map);
  }

  Future<Map<String, dynamic>> enviarDocumento({
    required String alunoId,
    required String tipoDocumentoId,
    required String nomeArquivo,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/alunos/$alunoId/documentos'),
      headers: await _headers(json: true),
      body: jsonEncode({
        'tipoDocumentoId': tipoDocumentoId,
        'nomeArquivo': nomeArquivo,
        'mimeType': mimeType,
        'arquivoBase64': base64Encode(bytes),
        'tamanhoBytes': bytes.length,
      }),
    );
    return Map<String, dynamic>.from(_validate(response) as Map);
  }

  Future<Uint8List> baixarDocumento(String documentoId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/documentos/$documentoId/arquivo'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _validate(response);
    }
    return response.bodyBytes;
  }

  Future<List<Map<String, dynamic>>> listarCompeticoes() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/competicoes'),
      headers: await _headers(),
    );
    final data = Map<String, dynamic>.from(_validate(response) as Map);
    return (data['itens'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> consultarCalendario({
    String? competicaoId,
    DateTime? de,
    DateTime? ate,
  }) async {
    final uri = Uri.parse('$baseUrl/api/partidas/calendario').replace(
      queryParameters: {
        if (competicaoId != null) 'competicaoId': competicaoId,
        if (de != null) 'de': de.toIso8601String(),
        if (ate != null) 'ate': ate.toIso8601String(),
      },
    );
    final response = await _client.get(uri, headers: await _headers());
    final data = Map<String, dynamic>.from(_validate(response) as Map);
    return (data['itens'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> registrarPontuacao({
    required String partidaId,
    required String timeId,
    String? alunoId,
    required int pontos,
    int? minuto,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/partidas/$partidaId/pontuacoes'),
      headers: await _headers(json: true),
      body: jsonEncode({
        'timeId': timeId,
        if (alunoId != null) 'alunoId': alunoId,
        'pontos': pontos,
        if (minuto != null) 'minuto': minuto,
      }),
    );
    return Map<String, dynamic>.from(_validate(response) as Map);
  }
}
```

## Endereços durante o desenvolvimento

- Android Emulator e API no mesmo computador: `http://10.0.2.2:8080`.
- Celular físico: IP local do computador, por exemplo `http://192.168.0.10:8080`.
- Produção: domínio com HTTPS.

Para o celular físico, computador e aparelho devem estar na mesma rede e a porta `8080` precisa estar liberada no firewall.

## Fluxo recomendado no aplicativo

1. Fazer login.
2. Salvar o JWT no armazenamento seguro.
3. Enviar `Authorization: Bearer <token>` nas rotas protegidas.
4. Ao receber `401`, apagar o token e voltar ao login.
5. Mostrar ao usuário o conteúdo do campo `erro`.
6. Manter modelos Dart separados para aluno, documento, competição, partida e classificação.
7. Usar os estados de carregamento, sucesso, vazio e erro em cada tela.

## Observações para documentos

O exemplo usa Base64, adequado ao protótipo. Para arquivos maiores em produção, use armazenamento externo e envie `urlArquivo`. A API também aceita essa estratégia.

## Contrato da API

- `ENDPOINTS.md`: exemplos e matriz por caso de uso.
- `openapi.yaml`: todas as 49 operações, pronto para importar em Postman, Insomnia ou Swagger.
