# Endpoints da API Mobile

Base local: `http://localhost:8080/api/mobile`

No Android Emulator use `http://10.0.2.2:8080/api/mobile`. Em celular físico use o IP local do computador.

## Autenticação

- `POST /auth/login`
- `POST /auth/recuperacao/solicitar`
- `POST /auth/recuperacao/confirmar`

Login:

```json
{
  "email": "escola@aether.local",
  "senha": "Admin@123"
}
```

Depois do login, envie o cabeçalho:

```text
Authorization: Bearer TOKEN_RECEBIDO
```

## Dashboard e filtros

- `GET /dashboard`
- `GET /modalidades`
- `GET /categorias`

## Escola

- `GET /perfil/escola`
- `PUT /perfil/escola`
- `GET /escolas?busca=`
- `GET /escolas/{id}`

Atualização do perfil:

```json
{
  "nome": "Etec de Itanhaém",
  "cidade": "Itanhaém",
  "estado": "SP",
  "logradouro": "Avenida das Escolas",
  "numero": "100",
  "bairro": "Centro",
  "cep": "11740000",
  "telefone": "(13) 3421-0000",
  "email": "escola@exemplo.com"
}
```

## Alunos

- `GET /alunos?busca=&pagina=1&limite=30`
- `POST /alunos`
- `GET /alunos/{id}`
- `PUT /alunos/{id}`
- `GET /alunos/{id}/historico`
- `GET /alunos/{id}/estatisticas`
- `GET /rankings/individual?competicaoId=&modalidadeId=`

Cadastro:

```json
{
  "nome": "Atleta Exemplo",
  "email": "atleta@escola.com",
  "senha": "SenhaSegura123",
  "telefone": "(13) 99999-9999",
  "cpf": "12345678901",
  "dataNascimento": "2009-05-10",
  "matricula": "20260001"
}
```

Quando o perfil autenticado é `ESCOLA`, a API utiliza automaticamente a escola do token. O campo `senha` é opcional; quando omitido, a resposta devolve uma `senhaTemporaria` para o primeiro acesso.

## Times

- `GET /times?busca=&modalidadeId=&categoriaId=`
- `POST /times`
- `GET /times/{id}`
- `PUT /times/{id}`
- `POST /times/{id}/atletas/{alunoId}`
- `PATCH /times/{id}/atletas/{alunoId}`
- `DELETE /times/{id}/atletas/{alunoId}`
- `PUT /times/{id}/capitao`
- `PUT /times/{id}/escalacao`
- `GET /times/{id}/ranking`

Cadastro de time:

```json
{
  "nome": "Time Escolar",
  "modalidadeId": "UUID",
  "categoriaId": "UUID",
  "tecnico": "Nome do responsável",
  "ativo": true
}
```

Escalação:

```json
{
  "atletas": [
    {
      "alunoId": "UUID",
      "numeroCamisa": 10,
      "posicao": "Ala",
      "funcao": "JOGADOR"
    }
  ]
}
```

## Competições e calendário

- `GET /competicoes`
- `GET /competicoes/{id}`
- `GET /calendario?competicaoId=&timeId=&de=&ate=`
- `PUT /partidas/{id}/calendario`
- `GET /locais`
- `POST /locais`
- `PUT /partidas/{id}/local`
- `POST /competicoes/{id}/inscricoes`
- `GET /competicoes/{id}/classificacao`
- `GET /competicoes/{id}/tabela`

Agendamento:

```json
{
  "dataHora": "2026-08-12T14:00:00-03:00",
  "localId": "UUID_DO_LOCAL",
  "motivo": "Calendário oficial"
}
```

## Partidas ao vivo

- `GET /partidas/ao-vivo`
- `GET /partidas/{id}/ao-vivo`
- `PATCH /partidas/{id}/iniciar`
- `POST /partidas/{id}/arbitragem`
- `PUT /partidas/{id}/resultado`
- `POST /partidas/{id}/pontuacoes`
- `POST /partidas/{id}/penalidades`
- `POST /partidas/{id}/publicar`
- `GET /partidas/historico`

Pontuação:

```json
{
  "timeId": "UUID_DO_TIME",
  "alunoId": "UUID_DO_ATLETA",
  "pontos": 1,
  "minuto": 12,
  "observacao": "Gol"
}
```

Penalidade:

```json
{
  "timeId": "UUID_DO_TIME",
  "alunoId": "UUID_DO_ATLETA",
  "tipo": "CARTAO_AMARELO",
  "minuto": 18,
  "observacao": "Conduta antidesportiva"
}
```

## Rankings

- `GET /rankings/escolas`
- `GET /rankings/equipes`
- `GET /rankings/individual`

Filtros disponíveis: `competicaoId`, `modalidadeId` e `limite`.
