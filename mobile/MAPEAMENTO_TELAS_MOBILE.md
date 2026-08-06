# Mapeamento das telas Mobile — ACE

Este projeto foi construído a partir dos wireframes da pasta do TCC e do arquivo **Divisão por Dispositivo**. Como esse arquivo usa uma numeração antiga em alguns pontos, a relação abaixo considera o nome da funcionalidade e a numeração oficial dos requisitos.

## Autenticação e escola

| Caso | Funcionalidade | Tela Flutter | Integração |
|---|---|---|---|
| UC02 / UC08 | Autenticar escola ou atleta | `LoginScreen` | `POST /auth/login` |
| UC03 | Gerenciar perfil da escola | `SchoolProfileScreen` | `GET/PUT /perfil/escola` |
| UC04 | Consultar escolas | `SchoolListScreen` e `SchoolDetailScreen` | `GET /escolas` e `/escolas/{id}` |
| UC06 | Recuperar acesso | `RecoveryRequestScreen` e `RecoveryConfirmScreen` | `POST /auth/recuperacao/solicitar` e `/confirmar` |

## Alunos e atletas

| Caso | Funcionalidade | Tela Flutter | Integração |
|---|---|---|---|
| UC07 | Cadastrar atleta | `StudentFormScreen` | `POST /alunos` |
| UC09 | Consultar atleta | `StudentListScreen` e `StudentDetailScreen` | `GET /alunos` e `/alunos/{id}` |
| UC10 | Editar atleta | `StudentFormScreen` | `PUT /alunos/{id}` |
| UC12 | Histórico esportivo | Aba Histórico de `StudentDetailScreen` | `GET /alunos/{id}/historico` |
| UC15 | Estatísticas do atleta | Aba Estatísticas de `StudentDetailScreen` | `GET /alunos/{id}/estatisticas` |
| UC16 / UC59 | Ranking individual | Aba Atletas de `RankingsScreen` | `GET /rankings/individual` |

## Times

| Caso | Funcionalidade | Tela Flutter | Integração |
|---|---|---|---|
| UC17 | Cadastrar time | `TeamFormScreen` | `POST /times` |
| UC18 | Consultar time | `TeamDetailScreen` | `GET /times/{id}` |
| UC19 | Editar time | `TeamFormScreen` | `PUT /times/{id}` |
| UC21 | Listar times | `TeamListScreen` | `GET /times` |
| UC22 | Vincular atleta | `TeamAthleteFormScreen` | `POST /times/{id}/atletas/{alunoId}` |
| UC23 | Remover atleta | Ação no elenco de `TeamDetailScreen` | `DELETE /times/{id}/atletas/{alunoId}` |
| UC24 | Registrar função | `TeamAthleteFormScreen` | `PATCH /times/{id}/atletas/{alunoId}` |
| UC25 | Definir capitão | Ação no elenco de `TeamDetailScreen` | `PUT /times/{id}/capitao` |
| UC29 | Escalação atual | Seletor de escalação de `TeamDetailScreen` | `PUT /times/{id}/escalacao` |
| UC30 / UC58 | Ranking por equipe | Aba Ranking de `TeamDetailScreen` e `RankingsScreen` | `GET /times/{id}/ranking` e `/rankings/equipes` |

## Competições e calendário

| Caso | Funcionalidade | Tela Flutter | Integração |
|---|---|---|---|
| UC34 | Visualizar competições | `CompetitionListScreen` e `CompetitionDetailScreen` | `GET /competicoes` e `/competicoes/{id}` |
| UC41 | Registrar calendário | `MatchScheduleScreen` | `PUT /partidas/{id}/calendario` |
| UC42 | Consultar calendário | `CalendarScreen` e aba Calendário de `MatchHubScreen` | `GET /calendario` |
| UC43 | Local das partidas | `LocationsScreen`, `LocationFormScreen` e seleção de local | `GET/POST /locais` e `PUT /partidas/{id}/local` |
| UC44 | Inscrever time | `CompetitionEnrollmentScreen` | `POST /competicoes/{id}/inscricoes` |
| UC53 | Classificação | Aba Classificação de `CompetitionDetailScreen` | `GET /competicoes/{id}/classificacao` |
| UC60 | Tabela e classificação | Aba Tabela de `CompetitionDetailScreen` | `GET /competicoes/{id}/tabela` |

## Partidas e resultados

| Caso | Funcionalidade | Tela Flutter | Integração |
|---|---|---|---|
| UC47 | Registrar arbitragem | Ação de arbitragem em `LiveMatchScreen` | `POST /partidas/{id}/arbitragem` |
| UC48 | Registrar resultado | `MatchResultScreen` | `PUT /partidas/{id}/resultado` |
| UC49 | Registrar pontuação | `ScoreEventScreen` | `POST /partidas/{id}/pontuacoes` |
| UC50 | Registrar penalidade | `PenaltyEventScreen` | `POST /partidas/{id}/penalidades` |
| UC52 | Histórico de partidas | `MatchHistoryScreen` | `GET /partidas/historico` |
| UC54 | Publicar resultado | Ação Publicar em `LiveMatchScreen` | `POST /partidas/{id}/publicar` |

## Rankings e acompanhamento

| Caso | Funcionalidade | Tela Flutter | Integração |
|---|---|---|---|
| UC56 | Ranking das escolas | Aba Escolas de `RankingsScreen` | `GET /rankings/escolas` |
| UC58 | Ranking das equipes | Aba Equipes de `RankingsScreen` | `GET /rankings/equipes` |
| UC59 | Ranking individual | Aba Atletas de `RankingsScreen` | `GET /rankings/individual` |

## Telas complementares dos wireframes

- `DashboardScreen`: resumo, atalhos, jogos ao vivo, próximos jogos e ranking.
- `MatchHubScreen`: abas Ao vivo, Calendário e Histórico.
- `LiveMatchScreen`: atualização automática do placar, eventos e controles por perfil.
- `MenuScreen`: menu completo e permissões conforme Administrador, Escola, Aluno, Árbitro ou Organizador.
- `ApiSettingsScreen`: troca e teste do endereço da API.
- `AboutScreen`: informações do projeto.

## Funções restritas ao PC

Não foram colocadas no aplicativo as operações classificadas como exclusivamente PC: exclusões administrativas, validação documental, criação e configuração completa de competições, chaveamento, emissão de súmula, premiações, relatórios, permissões e importação CSV.
