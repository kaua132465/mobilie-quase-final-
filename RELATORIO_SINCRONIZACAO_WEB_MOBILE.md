# Relatório de sincronização Banco Web → Banco Mobile

Data da execução: 25/09/2026  
Projeto: **ACE — Sistema de Gestão Esportiva Escolar**

## Resultado

A sincronização foi concluída e confirmada com `COMMIT`. Os bancos continuam
separados e nenhuma tabela ou registro foi removido. O banco Web permaneceu
inalterado e foi usado exclusivamente como origem.

Foram copiados para o Mobile:

- 100 usuários;
- 5 escolas novas e atualização da escola já correspondente;
- 8 alunos;
- 5 modalidades esportivas novas;
- 7 categorias novas;
- 16 times.

Uma segunda execução em modo `dry-run` encontrou **zero adições e zero
atualizações**, comprovando a idempotência do script.

## Ambiente Docker

| Item | Web (origem) | Mobile (destino) |
|---|---|---|
| Tecnologia | PostgreSQL 17.11 | PostgreSQL 16 |
| Container do banco | `ace-joao-okabe-db-1` | `backend-banco-1` |
| Container da aplicação | `ace-joao-okabe-web-1` | `backend-api-1` |
| Database | `ace` | `aether` |
| Usuário do banco | `ace` | `postgres` |
| Porta no host | `5433` | `5432` |
| Porta no container | `5432` | `5432` |
| Network | `ace-joao-okabe_default` | `backend_default` |
| Volume principal | `ace_joao_okabe_pgdata_c1e5a1f` | `backend_aether_pgdata` |
| Aplicação HTTP | `http://localhost:8081` | `http://localhost:8080` |

Arquivos Docker analisados:

- Web: `C:\Users\kauas\Desktop\ACE-Joao-Okabe\compose.yml`
- Web: `C:\Users\kauas\Desktop\ACE-Joao-Okabe\docker\php\Dockerfile`
- Web: `C:\Users\kauas\Desktop\ACE-Joao-Okabe\.env`
- Mobile: `C:\Users\kauas\Desktop\ACE\backend\docker-compose.yml`
- Mobile: `C:\Users\kauas\Desktop\ACE\backend\.env`

## Backups

Os dois backups foram criados antes de qualquer gravação e validados com
`pg_restore -l`:

- `C:\Users\kauas\Desktop\ACE\backups\sync_web_mobile_20260925_074510\web_ace.dump`
- `C:\Users\kauas\Desktop\ACE\backups\sync_web_mobile_20260925_074510\mobile_aether.dump`

Nenhum backup anterior foi sobrescrito.

## Estrutura encontrada

### Tabelas Web

`aluno`, `classificacao_grupo`, `competicao`,
`configuracao_classificacao`, `confronto`, `confronto_participante`,
`criterio_classificacao`, `documentos_aluno`, `escalacao_integrante`,
`escola`, `esporte`, `estatistica_classificacao`, `etapa_competicao`,
`etapa_partida`, `formato`, `funcao_integrante`, `grupo_competicao`,
`info_partida`, `inscricao_competicao`, `metrica_classificacao`,
`modalidade`, `origem_participante_confronto`, `papel`, `partida`,
`penalidade`, `responsavel`, `responsavel_time`,
`resultado_etapa_partida`, `rodada_competicao`, `time`, `tipo_etapa`,
`tipo_penalidade`, `usuario`, `usuario_papel`, `vinculo_grupo_time`,
`vinculo_inscricao_time`, `vinculo_partida_time`,
`vinculo_tecnico_time`, `vinculo_time_escola`,
`vinculo_time_integrante` e `vinculo_usuario_escola`.

### Tabelas Mobile

`aluno`, `arbitragem_partida`, `arbitro`, `calendario_alteracao`,
`categoria`, `chaveamento`, `chaveamento_item`, `competicao`,
`competicao_categoria`, `competicao_modalidade`, `documento_atleta`,
`edicao_jogos`, `escola`, `evento_partida`, `fase_competicao`,
`grupo_competicao`, `inscricao_competicao`, `local_modalidade`,
`local_partida`, `log_auditoria`, `modalidade`, `participacao_atleta`,
`partida`, `recuperacao_senha`, `regra_classificacao`,
`resultado_publicado`, `sumula_partida`, `time_aluno`,
`time_esportivo`, `tipo_documento`, `usuario` e `validacao_documento`.

## Diferenças de schema e mapeamento

Os schemas representam os mesmos conceitos com estruturas diferentes. Não foi
feita nenhuma alteração permanente de schema.

| Web | Mobile | Estratégia |
|---|---|---|
| `usuario` | `usuario` | Correspondência por e-mail; hash BCrypt preservado |
| `escola` | `escola` | Correspondência por nome normalizado |
| `esporte` | `modalidade` | Esporte do Web representa modalidade esportiva no Mobile |
| `modalidade` | `categoria` | Sexo/faixa do Web representa categoria no Mobile |
| `aluno` | `aluno` | Correspondência pelo usuário/e-mail |
| `time` + `vinculo_time_escola` | `time_esportivo` | Escola e modalidade preservadas |
| `vinculo_time_integrante` | `time_aluno` | Somente quando existe `aluno` formal correspondente |
| `competicao` | `competicao` | Mapeamento preparado; origem estava vazia |
| `vinculo_inscricao_time` | `inscricao_competicao` | Mapeamento preparado; origem estava vazia |
| `partida` + tabelas de vínculo/informação | `partida` | Mapeamento preparado; origem estava vazia |

### IDs

O Web usa chaves `integer`; o Mobile usa `uuid`. Por incompatibilidade de tipo,
não é possível conservar literalmente os números do Web. Para registros novos,
foram usados UUIDs determinísticos derivados da entidade e do ID Web. Assim, o
mesmo registro sempre recebe o mesmo UUID em reexecuções.

Identidades preexistentes no Mobile foram preservadas. A escola
`Etec de Itanhaém`, por exemplo, manteve seu UUID original e recebeu apenas os
campos existentes no Web.

Validação dos UUIDs:

- usuários determinísticos encontrados: 100;
- alunos determinísticos encontrados: 8;
- times determinísticos encontrados: 16;
- escolas determinísticas novas: 5;
- escola preexistente preservada: 1.

### Campos sem equivalente

- O Web não possui CPF. Para os oito alunos novos, o campo técnico obrigatório
  do Mobile recebeu 11 dígitos derivados do RA, enquanto o RA original foi
  preservado integralmente em `matricula`.
- Campos do Web sem equivalente seguro no Mobile, como caminhos de imagem e
  certas tabelas específicas de chaveamento, não foram inventados nem gravados.
- Dados exclusivos do Mobile foram mantidos.

## Estatísticas da sincronização

| Entidade de destino | Origem Web | Existiam correspondentes | Adicionados | Atualizados | Já iguais | Ignorados |
|---|---:|---:|---:|---:|---:|---:|
| `usuario` | 100 | 0 | 100 | 0 | 0 | 0 |
| `escola` | 6 | 1 | 5 | 1 | 0 | 0 |
| `modalidade` | 9 | 4 | 5 | 0 | 4 | 0 |
| `categoria` | 9 | 2 | 7 | 0 | 2 | 0 |
| `aluno` | 8 | 0 | 8 | 0 | 0 | 0 |
| `time_esportivo` | 17 | 0 | 16 | 0 | 0 | 1 |
| `time_aluno` | 81 | 0 | 0 | 0 | 0 | 81 |
| `competicao` | 0 | 0 | 0 | 0 | 0 | 0 |
| `inscricao_competicao` | 0 | 0 | 0 | 0 | 0 | 0 |
| `partida` | 0 | 0 | 0 | 0 | 0 | 0 |

O time `Primeiro Time` foi ignorado porque não possui vínculo com escola no
Web, enquanto `time_esportivo.escola_id` é obrigatório no Mobile.

Os 81 vínculos de `vinculo_time_integrante` foram ignorados porque nenhum deles
aponta para um registro formal em `aluno`. Criar esses atletas exigiria inventar
CPF, data de nascimento e escola, o que contrariaria a integridade dos dados.

## Quantidades no Mobile antes e depois

| Tabela | Antes | Depois |
|---|---:|---:|
| `usuario` | 6 | 106 |
| `escola` | 231 | 236 |
| `modalidade` | 4 | 9 |
| `categoria` | 4 | 11 |
| `aluno` | 2 | 10 |
| `time_esportivo` | 2 | 18 |
| `time_aluno` | 1 | 1 |
| `competicao` | 1 | 1 |
| `inscricao_competicao` | 2 | 2 |
| `partida` | 1 | 1 |

As quantidades são maiores que as do Web porque a regra da tarefa determinou
que registros exclusivos já existentes no Mobile não fossem apagados.

## Integridade e conteúdo

- 100/100 usuários Web encontrados no Mobile;
- zero divergências em nome, e-mail, hash de senha e estado dos usuários;
- 8/8 alunos Web encontrados no Mobile;
- zero divergências nos dados acadêmicos transferidos;
- hashes de senha mantidos em BCrypt, sem conversão para texto simples;
- zero e-mails duplicados;
- zero CPFs duplicados;
- zero registros órfãos nos relacionamentos de usuário, aluno, escola, time e
  vínculos de time;
- zero constraints não validados;
- sequence `log_auditoria_id_seq` igual ou superior ao maior ID;
- nenhum objeto temporário de FDW permaneceu no banco após o `COMMIT`;
- banco Web permaneceu com 100 usuários, 6 escolas, 8 alunos, 17 times,
  0 competições e 0 partidas.

## Testes funcionais

- `GET /login` Web: HTTP 200;
- login Web do administrador sincronizado: redirecionamento para `/dashboard`;
- dashboard Web: HTTP 200;
- saúde da API Mobile: `ok`;
- login Mobile com o administrador do Web: sucesso, perfil `ADMINISTRADOR`;
- endpoints Mobile `dashboard`, `escolas`, `alunos`, `times`, `modalidades`,
  `categorias`, `competicoes` e `calendario`: HTTP 200;
- teste transacional de criação e atualização: sucesso;
- rollback do teste: zero registros residuais;
- containers Web e Mobile continuaram ativos; os dois bancos permaneceram
  saudáveis;
- logs recentes sem erro fatal ou exceção da aplicação.

## Arquivos criados

- `C:\Users\kauas\Desktop\ACE\backend\scripts\sync_web_to_mobile.sql`
- `C:\Users\kauas\Desktop\ACE\backend\scripts\sync_web_to_mobile.ps1`
- `C:\Users\kauas\Desktop\ACE\RELATORIO_SINCRONIZACAO_WEB_MOBILE.md`
- backups na pasta indicada acima;
- logs em `C:\Users\kauas\Desktop\ACE\logs`.

Nenhum arquivo de aplicação, tela, Flutter, frontend, rota, controller,
repository ou regra de negócio foi modificado por esta sincronização.

Log do `COMMIT`:

`C:\Users\kauas\Desktop\ACE\logs\sync_web_mobile_20260925_074856.log`

Log da validação idempotente final:

`C:\Users\kauas\Desktop\ACE\logs\sync_web_mobile_20260925_075116.log`

## Comandos e técnicas principais

- `docker ps`, `docker compose ps`, `docker inspect`;
- consultas ao catálogo `information_schema` e `pg_catalog`;
- `pg_dump -Fc` e `pg_restore -l`;
- PostgreSQL FDW temporário dentro da mesma transação;
- `INSERT ... ON CONFLICT ... DO UPDATE ... WHERE ... IS DISTINCT FROM`;
- `SET CONSTRAINTS ALL IMMEDIATE`;
- `COMMIT` na execução real e `ROLLBACK` nos testes;
- comparações de conteúdo por e-mail, IDs determinísticos e hashes MD5 dos
  hashes BCrypt, sem expor as senhas.

## Como executar novamente

No PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\kauas\Desktop\ACE\backend\scripts\sync_web_to_mobile.ps1"
```

Para simular sem gravar:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\kauas\Desktop\ACE\backend\scripts\sync_web_to_mobile.ps1" `
  -DryRun -SkipBackup
```
