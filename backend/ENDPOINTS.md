# Matriz de endpoints — Aether API

A URL-base dos exemplos é `http://localhost:8080`. Todas as rotas, exceto saúde e login, exigem um token JWT:

```http
Authorization: Bearer <token>
Content-Type: application/json
```

## UC07–UC16 — alunos, documentos, estatísticas e ranking

| UC | Método e rota | Finalidade | Perfis de escrita |
|---|---|---|---|
| UC07 | `POST /api/alunos` | Cadastrar aluno e credencial | ADMINISTRADOR, ESCOLA |
| UC08 | `POST /api/auth/login` | Autenticar qualquer usuário | Público |
| UC08 | `POST /api/auth/alunos/login` | Alias de autenticação para o app do aluno | Público |
| UC09 | `GET /api/alunos` | Listar/pesquisar alunos | ADMINISTRADOR, ESCOLA, ORGANIZADOR |
| UC09 | `GET /api/alunos/{id}` | Consultar aluno | Usuário autorizado |
| UC10 | `PUT /api/alunos/{id}` | Editar aluno | ADMINISTRADOR, ESCOLA ou próprio aluno |
| UC11 | `DELETE /api/alunos/{id}` | Excluir aluno logicamente | ADMINISTRADOR, ESCOLA |
| UC12 | `GET /api/alunos/{id}/historico` | Consultar histórico esportivo | Usuário autorizado |
| UC13 | `GET /api/documentos/tipos` | Listar tipos e regras de documentos | Autenticado |
| UC13 | `GET /api/alunos/{id}/documentos` | Listar documentos do atleta | Usuário autorizado |
| UC13 | `POST /api/alunos/{id}/documentos` | Enviar documento | Usuário autorizado |
| UC13 | `PUT /api/alunos/{id}/documentos/{documentoId}` | Substituir documento | Usuário autorizado |
| UC13 | `DELETE /api/alunos/{id}/documentos/{documentoId}` | Remover documento logicamente | Usuário autorizado |
| UC13 | `GET /api/documentos/{id}/arquivo` | Baixar ou abrir documento | Usuário autorizado |
| UC14 | `GET /api/documentos/pendentes` | Consultar fila de validação | ADMINISTRADOR, ESCOLA |
| UC14 | `PATCH /api/documentos/{id}/validacao` | Aprovar, rejeitar ou solicitar correção | ADMINISTRADOR, ESCOLA |
| UC15 | `GET /api/alunos/{id}/estatisticas` | Consultar estatísticas do atleta | Usuário autorizado |
| UC16 | `GET /api/rankings/individual` | Visualizar ranking individual | Autenticado |

## UC31–UC43 — configuração da competição

| UC | Método e rota | Finalidade | Perfis de escrita |
|---|---|---|---|
| UC31 | `POST /api/competicoes` | Criar competição | ADMINISTRADOR |
| UC32 | `PUT /api/competicoes/{id}` | Editar competição | ADMINISTRADOR |
| UC33 | `DELETE /api/competicoes/{id}` | Cancelar/excluir logicamente | ADMINISTRADOR |
| UC34 | `GET /api/competicoes` | Listar e filtrar competições | Autenticado |
| UC34 | `GET /api/competicoes/{id}` | Visualizar detalhes e configurações | Autenticado |
| UC35 | `POST /api/competicoes/{id}/edicoes` | Criar edição anual | ADMINISTRADOR |
| UC36 | `PUT /api/competicoes/{id}/modalidades/{modalidadeId}` | Configurar modalidade | ADMINISTRADOR |
| UC36 | `DELETE /api/competicoes/{id}/modalidades/{modalidadeId}` | Remover modalidade | ADMINISTRADOR |
| UC37 | `PUT /api/competicoes/{id}/categorias/{categoriaId}` | Configurar categoria | ADMINISTRADOR |
| UC37 | `DELETE /api/competicoes/{id}/categorias/{categoriaId}` | Remover categoria | ADMINISTRADOR |
| UC38 | `PUT /api/competicoes/{id}/fases` | Criar, editar e ordenar fases | ADMINISTRADOR |
| UC39 | `POST /api/competicoes/{id}/chaveamentos` | Gerar chaveamento | ADMINISTRADOR |
| UC40 | `POST /api/competicoes/{id}/partidas/gerar` | Gerar tabela de partidas | ADMINISTRADOR |
| UC41 | `PUT /api/competicoes/{id}/calendario` | Agendar partidas em lote | ADMINISTRADOR, ORGANIZADOR |
| UC41 | `PUT /api/partidas/{id}/calendario` | Agendar ou reagendar uma partida | ADMINISTRADOR, ORGANIZADOR |
| UC42 | `GET /api/partidas/calendario` | Consultar calendário | Autenticado |
| UC43 | `POST /api/locais` | Cadastrar local | ADMINISTRADOR |
| UC43 | `GET /api/locais` | Listar locais compatíveis | Autenticado |
| UC43 | `PUT /api/partidas/{id}/local` | Vincular local à partida | ADMINISTRADOR, ORGANIZADOR |

## UC44–UC53 — execução da competição

| UC | Método e rota | Finalidade | Perfis de escrita |
|---|---|---|---|
| UC44 | `POST /api/competicoes/{id}/inscricoes` | Inscrever ou reativar time | ADMINISTRADOR, ORGANIZADOR, ESCOLA |
| UC45 | `DELETE /api/competicoes/{id}/inscricoes/{timeId}` | Cancelar inscrição | ADMINISTRADOR, ORGANIZADOR, ESCOLA |
| UC46 | `PATCH /api/competicoes/{id}/encerrar` | Encerrar competição | ADMINISTRADOR, ORGANIZADOR |
| UC47 | `POST /api/partidas/{id}/arbitragem` | Designar árbitro e função | ADMINISTRADOR, ORGANIZADOR |
| UC48 | `PUT /api/partidas/{id}/resultado` | Registrar resultado final | ADMINISTRADOR, ORGANIZADOR, ARBITRO |
| UC49 | `POST /api/partidas/{id}/pontuacoes` | Registrar ponto, gol ou cesta | ADMINISTRADOR, ORGANIZADOR, ARBITRO |
| UC50 | `POST /api/partidas/{id}/penalidades` | Registrar falta, cartão ou penalidade | ADMINISTRADOR, ORGANIZADOR, ARBITRO |
| UC51 | `GET /api/partidas/{id}/sumula` | Consultar prévia/súmula | Autenticado |
| UC51 | `POST /api/partidas/{id}/sumula` | Emitir e versionar súmula | ADMINISTRADOR, ORGANIZADOR, ARBITRO |
| UC52 | `GET /api/partidas/historico` | Consultar partidas encerradas | Autenticado |
| UC53 | `GET /api/competicoes/{id}/classificacao` | Visualizar classificação | Autenticado |

## Parâmetros de consulta

- `GET /api/alunos`: `busca`, `escolaId`, `pagina`, `limite`.
- `GET /api/documentos/pendentes`: `escolaId`, `status`, `pagina`, `limite`.
- `GET /api/competicoes`: `busca`, `status`, `modalidadeId`, `de`, `ate`, `pagina`, `limite`.
- `GET /api/rankings/individual`: `competicaoId`, `modalidadeId`, `limite`.
- `GET /api/partidas/calendario`: `competicaoId`, `timeId`, `localId`, `de`, `ate`, `pagina`, `limite`.
- `GET /api/partidas/historico`: `competicaoId`, `timeId`, `de`, `ate`, `pagina`, `limite`.
- `GET /api/locais`: `busca`, `modalidadeId`.

Datas e horas devem usar ISO 8601, por exemplo `2026-08-10T14:00:00-03:00`.

## Exemplos principais

### Login

```json
{
  "email": "admin@aether.local",
  "senha": "Admin@123"
}
```

### Cadastrar aluno

```json
{
  "nome": "Atleta Exemplo",
  "email": "atleta@escola.com",
  "senha": "SenhaSegura123",
  "cpf": "12345678901",
  "dataNascimento": "2009-05-10",
  "escolaId": "UUID_DA_ESCOLA",
  "matricula": "20260001",
  "genero": "MASCULINO",
  "telefone": "(13) 99999-9999"
}
```

### Enviar documento em Base64

```json
{
  "tipoDocumentoId": "UUID_DO_TIPO",
  "nomeArquivo": "atestado-medico.pdf",
  "mimeType": "application/pdf",
  "arquivoBase64": "JVBERi0xLjQKLi4u",
  "tamanhoBytes": 128000
}
```

Também é possível informar `urlArquivo` no lugar de `arquivoBase64`.

### Validar documento

```json
{
  "status": "APROVADA",
  "observacao": "Documento legível e dentro da validade."
}
```

Status aceitos: `APROVADA`, `REJEITADA` e `CORRECAO_SOLICITADA`.

### Criar competição

```json
{
  "nome": "Jogos Escolares 2026",
  "descricao": "Etapa municipal",
  "tipo": "JOGOS_ESCOLARES",
  "abrangencia": "MUNICIPAL",
  "formato": "PONTOS_CORRIDOS",
  "limiteTimes": 16,
  "dataInicio": "2026-08-10",
  "dataFim": "2026-08-30",
  "dataLimiteInscricao": "2026-08-01T23:59:59-03:00"
}
```

### Organizar fases

```json
{
  "fases": [
    {
      "nome": "Fase de grupos",
      "ordem": 1,
      "tipo": "GRUPOS",
      "quantidadeGrupos": 4,
      "classificados": 8
    },
    {
      "nome": "Eliminatórias",
      "ordem": 2,
      "tipo": "MATA_MATA",
      "classificados": 1
    }
  ]
}
```

### Gerar tabela de partidas

```json
{
  "faseId": "UUID_DA_FASE",
  "modo": "IDA_VOLTA",
  "substituir": false
}
```

### Registrar calendário em lote

```json
{
  "partidas": [
    {
      "partidaId": "UUID_DA_PARTIDA",
      "dataHora": "2026-08-12T14:00:00-03:00",
      "localId": "UUID_DO_LOCAL",
      "motivo": "Calendário inicial"
    }
  ]
}
```

### Inscrever time

```json
{
  "timeId": "UUID_DO_TIME"
}
```

### Registrar arbitragem

```json
{
  "arbitroId": "UUID_DO_ARBITRO",
  "funcao": "PRINCIPAL"
}
```

### Registrar resultado

```json
{
  "placarCasa": 3,
  "placarVisitante": 2
}
```

### Registrar pontuação

```json
{
  "timeId": "UUID_DO_TIME",
  "alunoId": "UUID_DO_ALUNO",
  "pontos": 1,
  "minuto": 18,
  "observacao": "Gol de falta"
}
```

### Registrar penalidade

```json
{
  "timeId": "UUID_DO_TIME",
  "alunoId": "UUID_DO_ALUNO",
  "tipo": "CARTAO_AMARELO",
  "minuto": 25,
  "observacao": "Conduta antidesportiva"
}
```

## Respostas de erro

```json
{
  "erro": "Descrição amigável do problema"
}
```

Códigos mais usados: `400`, `401`, `403`, `404`, `409` e `500`. O contrato completo, com os **49 métodos**, está em `openapi.yaml`.
