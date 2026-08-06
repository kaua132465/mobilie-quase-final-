# Relatório de validação - Back-end Mobile ACE

## Escopo conferido

- Documento de referência: `Divisão por Dispositivo.docx`.
- Base visual: 40 páginas do arquivo `Wireframe.pdf`, com foco nas telas Mobile.
- Numeração oficial relacionada pelo nome das funcionalidades: 37 casos de uso Mobile/Mobile + PC.
- Operações do módulo `/api/mobile`: 49.
- Operações registradas em `openapi_mobile.yaml`: 49.

## Estrutura criada

- Arquivos Dart: 19.
- Migrações SQL: 4.
- Documentos Markdown: 6.
- Novos repositórios: usuário, escola, time e operações Mobile.
- Nova rota principal: `lib/src/routes/mobile_router.dart`.
- Migrações complementares: `003_mobile.sql` e `004_seed_mobile.sql`.

## Verificações automáticas executadas

- Todos os imports relativos apontam para arquivos existentes.
- Parênteses, colchetes e chaves dos arquivos Dart estão balanceados.
- Todos os handlers usados nas rotas Mobile possuem método correspondente.
- `docker-compose.yml` foi carregado como YAML válido.
- `openapi_mobile.yaml` foi carregado como YAML válido.
- O número de operações do código e do OpenAPI coincide: 49.

## Decisões de implementação

- PostgreSQL foi mantido como banco, conforme autorizado.
- O Flutter acessa somente a API HTTP; não acessa o banco diretamente.
- A atualização da partida ao vivo usa polling de 2 a 3 segundos.
- Exclusões e configurações administrativas classificadas como PC não foram expostas no módulo Mobile.
- O cadastro Mobile de atleta aceita senha opcional; quando ausente, devolve senha temporária.
- Registro de resultado e publicação do resultado permanecem operações separadas.

## Limitação da validação neste ambiente

O ambiente usado para gerar o pacote não possui Dart SDK, Docker nem PostgreSQL instalados. Portanto, não foi possível executar `dart analyze`, `dart test` ou iniciar o banco. A validação realizada foi estrutural e documental. No computador do projeto, execute:

```bash
docker compose down -v
docker compose up
```

Depois verifique:

```text
http://localhost:8080/api/mobile/saude
```
