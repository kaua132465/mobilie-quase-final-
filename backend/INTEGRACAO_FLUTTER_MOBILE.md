# Integração das telas Flutter com a API Mobile

## Dependências

```yaml
dependencies:
  http: any
  flutter_secure_storage: any
```

## Cliente básico

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MobileApi {
  MobileApi(this.baseUrl);

  final String baseUrl;
  final _client = http.Client();
  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _storage.read(key: 'aether_token');
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _body(http.Response response) {
    final data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data is Map ? data['erro'] ?? 'Falha na requisição' : 'Falha na requisição');
    }
    return data;
  }

  Future<Map<String, dynamic>> login(String email, String senha) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _headers(json: true),
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    final data = Map<String, dynamic>.from(_body(response) as Map);
    await _storage.write(key: 'aether_token', value: data['token'].toString());
    return data;
  }

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: await _headers(),
    );
    return Map<String, dynamic>.from(_body(response) as Map);
  }

  Future<List<Map<String, dynamic>>> alunos({String? busca}) async {
    final uri = Uri.parse('$baseUrl/alunos').replace(queryParameters: {
      if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
    });
    final response = await _client.get(uri, headers: await _headers());
    final data = Map<String, dynamic>.from(_body(response) as Map);
    return (data['itens'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> times({String? busca}) async {
    final uri = Uri.parse('$baseUrl/times').replace(queryParameters: {
      if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
    });
    final response = await _client.get(uri, headers: await _headers());
    final data = Map<String, dynamic>.from(_body(response) as Map);
    return (data['itens'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> partidaAoVivo(String partidaId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/partidas/$partidaId/ao-vivo'),
      headers: await _headers(),
    );
    return Map<String, dynamic>.from(_body(response) as Map);
  }

  Future<void> registrarPonto({
    required String partidaId,
    required String timeId,
    String? alunoId,
    int pontos = 1,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/partidas/$partidaId/pontuacoes'),
      headers: await _headers(json: true),
      body: jsonEncode({
        'timeId': timeId,
        if (alunoId != null) 'alunoId': alunoId,
        'pontos': pontos,
      }),
    );
    _body(response);
  }
}
```

Use como `baseUrl`:

- Android Emulator: `http://10.0.2.2:8080/api/mobile`
- Celular físico: `http://IP_DO_COMPUTADOR:8080/api/mobile`

## Atualização da partida ao vivo

Enquanto a tela **Partida ao vivo** estiver aberta, consulte `partidaAoVivo` a cada 2 ou 3 segundos com `Timer.periodic`. Cancele o timer no `dispose()` da tela. O retorno contém `atualizado_em`, eventos, arbitragem, placar e status de publicação.

## Correspondência com os wireframes

- Login: `/auth/login`
- Dashboard: `/dashboard`
- Cadastrar/editar/consultar atleta: `/alunos`
- Lista e detalhe dos times: `/times`
- Calendário: `/calendario`
- Partida ao vivo: `/partidas/{id}/ao-vivo`
- Ranking: `/rankings/escolas`, `/equipes` e `/individual`
- Perfil da escola: `/perfil/escola`
