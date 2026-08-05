# Mapeamento dos casos de uso Mobile

O arquivo **Divisão por Dispositivo.docx** utiliza a numeração antiga do projeto. A API foi implementada pelo **nome da funcionalidade** e relacionada à numeração oficial de **Casos de Uso e Requisitos Funcionais.docx**.

## Gestão de escolas/equipes

| Numeração oficial | Funcionalidade | Rota Mobile principal |
|---|---|---|
| UC02 | Autenticar escola/equipe | `POST /api/mobile/auth/login` |
| UC03 | Gerenciar perfil da escola/equipe | `GET/PUT /api/mobile/perfil/escola` |
| UC04 | Consultar escola/equipe | `GET /api/mobile/escolas` e `GET /api/mobile/escolas/{id}` |
| UC06 | Recuperar acesso | `POST /api/mobile/auth/recuperacao/solicitar` e `/confirmar` |

## Gestão de alunos/atletas

| Numeração oficial | Funcionalidade | Rota Mobile principal |
|---|---|---|
| UC07 | Cadastrar aluno/atleta | `POST /api/mobile/alunos` |
| UC08 | Autenticar aluno/atleta | `POST /api/mobile/auth/login` |
| UC09 | Consultar aluno/atleta | `GET /api/mobile/alunos` e `GET /api/mobile/alunos/{id}` |
| UC10 | Editar aluno/atleta | `PUT /api/mobile/alunos/{id}` |
| UC12 | Consultar histórico esportivo | `GET /api/mobile/alunos/{id}/historico` |
| UC15 | Consultar estatísticas do atleta | `GET /api/mobile/alunos/{id}/estatisticas` |
| UC16 | Visualizar ranking individual | `GET /api/mobile/rankings/individual` |

## Gestão de times

| Numeração oficial | Funcionalidade | Rota Mobile principal |
|---|---|---|
| UC17 | Cadastrar time | `POST /api/mobile/times` |
| UC18 | Consultar time | `GET /api/mobile/times/{id}` |
| UC19 | Editar time | `PUT /api/mobile/times/{id}` |
| UC21 | Listar times da escola/equipe | `GET /api/mobile/times` |
| UC22 | Vincular aluno/atleta a time | `POST /api/mobile/times/{id}/atletas/{alunoId}` |
| UC23 | Remover aluno/atleta de time | `DELETE /api/mobile/times/{id}/atletas/{alunoId}` |
| UC24 | Registrar função do atleta | `PATCH /api/mobile/times/{id}/atletas/{alunoId}` |
| UC25 | Definir capitão do time | `PUT /api/mobile/times/{id}/capitao` |
| UC29 | Adicionar escalação atual | `PUT /api/mobile/times/{id}/escalacao` |
| UC30 | Visualizar ranking por equipe | `GET /api/mobile/times/{id}/ranking` e `/rankings/equipes` |

## Competições e calendário

| Numeração oficial | Funcionalidade | Rota Mobile principal |
|---|---|---|
| UC34 | Visualizar competições/eventos | `GET /api/mobile/competicoes` e `GET /api/mobile/competicoes/{id}` |
| UC41 | Registrar calendário dos jogos | `PUT /api/mobile/partidas/{id}/calendario` |
| UC42 | Consultar calendário dos jogos | `GET /api/mobile/calendario` |
| UC43 | Registrar local das partidas | `POST /api/mobile/locais` e `PUT /api/mobile/partidas/{id}/local` |
| UC44 | Inscrever time em competição | `POST /api/mobile/competicoes/{id}/inscricoes` |

## Partidas e resultados

| Numeração oficial | Funcionalidade | Rota Mobile principal |
|---|---|---|
| UC47 | Registrar arbitragem | `POST /api/mobile/partidas/{id}/arbitragem` |
| UC48 | Registrar resultado | `PUT /api/mobile/partidas/{id}/resultado` |
| UC49 | Registrar pontuação | `POST /api/mobile/partidas/{id}/pontuacoes` |
| UC50 | Registrar faltas e penalidades | `POST /api/mobile/partidas/{id}/penalidades` |
| UC52 | Consultar histórico de partidas | `GET /api/mobile/partidas/historico` |
| UC53 | Visualizar classificação | `GET /api/mobile/competicoes/{id}/classificacao` |
| UC54 | Publicar resultados | `POST /api/mobile/partidas/{id}/publicar` |

## Rankings e acompanhamento

| Numeração oficial | Funcionalidade | Rota Mobile principal |
|---|---|---|
| UC56 | Visualizar ranking das escolas | `GET /api/mobile/rankings/escolas` |
| UC58 | Visualizar ranking por equipe | `GET /api/mobile/rankings/equipes` |
| UC59 | Visualizar ranking individual | `GET /api/mobile/rankings/individual` |
| UC60 | Acompanhar tabelas e classificações | `GET /api/mobile/competicoes/{id}/tabela` |

## Funções exclusivamente Mobile dos wireframes

- Dashboard resumido: `GET /api/mobile/dashboard`.
- Consulta de partidas em andamento: `GET /api/mobile/partidas/ao-vivo`.
- Tela de partida ao vivo: `GET /api/mobile/partidas/{id}/ao-vivo`.
- Atualização rápida: o Flutter deve repetir a consulta da partida a cada 2 ou 3 segundos enquanto a tela estiver aberta.

## Funções não expostas no módulo Mobile

Embora alguns botões apareçam em versões antigas dos wireframes, a divisão por dispositivo classifica como exclusivas de PC: exclusão de escola, exclusão de aluno, exclusão de time, validação de documentos, criação/configuração completa de competição, chaveamento, súmula, premiações, relatórios, permissões e importação CSV.
