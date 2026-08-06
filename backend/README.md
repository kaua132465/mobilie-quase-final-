# ACE - Back-end Mobile em Dart e PostgreSQL

API REST do **Sistema de Gestão Esportiva Escolar**, adaptada aos wireframes Mobile e ao arquivo **Divisão por Dispositivo**.

## Tecnologias

- Dart 3.8+
- Shelf e Shelf Router
- PostgreSQL 16
- JWT
- BCrypt
- Docker Compose

## O que foi implementado

O módulo `/api/mobile` possui 49 operações para:

- autenticação e recuperação de senha;
- dashboard do aplicativo;
- perfil e consulta de escolas;
- cadastro, consulta e edição de atletas;
- histórico, estatísticas e ranking individual;
- cadastro e gerenciamento de times;
- vínculo, função, capitão e escalação de atletas;
- consulta de competições;
- calendário, locais e inscrição de times;
- partidas ao vivo, arbitragem, pontuação e penalidades;
- publicação de resultados;
- rankings de escolas, equipes e atletas;
- tabelas e classificações.

O mapeamento completo está em `MAPEAMENTO_CASOS_MOBILE.md`.

## Executar no VS Code com Docker

Abra esta pasta diretamente no VS Code e execute:

```bash
docker compose down -v
docker compose up
```

O parâmetro `-v` é importante na primeira execução desta versão, pois garante que as novas migrações Mobile sejam aplicadas.

Teste no navegador:

```text
http://localhost:8080/api/mobile/saude
```

## Contas de teste

Todas usam a senha `Admin@123`.

| Perfil | E-mail |
|---|---|
| Administrador | `admin@ace.local` |
| Escola | `escola@ace.local` |
| Aluno/atleta | `atleta@ace.local` |
| Árbitro | `arbitro@ace.local` |

## Endereços para o Flutter

- Android Emulator: `http://10.0.2.2:8080/api/mobile`
- Celular físico: `http://IP_DO_COMPUTADOR:8080/api/mobile`
- Navegador no computador: `http://localhost:8080/api/mobile`

O computador e o celular precisam estar na mesma rede, e a porta 8080 deve estar liberada no firewall.

## Arquivos importantes

- `lib/src/routes/mobile_router.dart`: rotas do aplicativo.
- `lib/src/repositories/escola_repository.dart`: perfil e escolas.
- `lib/src/repositories/time_repository.dart`: times e escalação.
- `lib/src/repositories/mobile_repository.dart`: dashboard, partidas ao vivo e rankings.
- `migrations/003_mobile.sql`: estrutura complementar Mobile.
- `migrations/004_seed_mobile.sql`: dados de demonstração.
- `MOBILE_ENDPOINTS.md`: exemplos de requisições.
- `INTEGRACAO_FLUTTER_MOBILE.md`: cliente Dart para o Flutter.
- `openapi_mobile.yaml`: contrato para Swagger, Postman ou Insomnia.

## Atualização em tempo real

Para o protótipo, a tela de partida ao vivo utiliza **polling**: o Flutter consulta `GET /partidas/{id}/ao-vivo` a cada 2 ou 3 segundos. Isso mantém placar, eventos, arbitragem e publicação atualizados sem exigir um servidor WebSocket adicional.

## Observação sobre os wireframes

Alguns wireframes antigos mostram botões de exclusão ou cadastro de escola. O arquivo **Divisão por Dispositivo** classifica essas operações como exclusivas de PC. Por isso, elas não foram incluídas no módulo `/api/mobile`.

## Execução sem Docker

Instale Dart e PostgreSQL, execute as migrações na ordem `001`, `002`, `003` e `004`, configure `.env.example` e rode:

```bash
dart pub get
dart run bin/server.dart
```

## Envio do código de recuperação por e-mail

Crie um arquivo `.env` na pasta `backend` usando `.env.example` como base e
preencha as variáveis `SMTP_*`. Para Gmail, use `smtp.gmail.com`, porta `587`,
`SMTP_SSL=false` e uma **senha de app** da conta Google (não use a senha normal).

Depois, recrie a API para carregar a configuração:

```bash
docker compose up -d --force-recreate api
```

O endpoint `POST /api/mobile/auth/recuperacao/solicitar` gera um código de seis
dígitos, envia o e-mail e o mantém válido por 15 minutos. A confirmação continua
em `POST /api/mobile/auth/recuperacao/confirmar`.

O aplicativo Flutter nunca deve acessar o PostgreSQL diretamente; toda comunicação deve passar pela API HTTP.
