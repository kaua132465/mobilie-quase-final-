# Relatório de implementação de acessibilidade

## Arquivos e telas

### `mobile/lib/core/accessibility/*`

Problema: não havia uma política central para toque, movimento, anúncios e mensagens de erro.  
Solução: criadas configuração, utilitários e estruturas semânticas reutilizáveis.  
WCAG: 2.1.1, 2.4.3, 3.3.1, 3.3.3 e 4.1.2.

### `mobile/lib/core/theme.dart`

Problema: laranja com texto branco e amarelo textual apresentavam risco de contraste; controles não declaravam alvo mínimo central.  
Solução: tons acessíveis, tipografia mínima, bordas de erro, alvos de 48 dp e temas de botões.  
WCAG: 1.4.3, 1.4.11, 2.4.7.

### `mobile/lib/widgets/common.dart`

Problema: loading e feedback não eram anunciados; status dependia fortemente de cor; cartões e placares tinham informação visual fragmentada; busca não tinha label; validação obrigatória era genérica.  
Solução: regiões ao vivo, mensagens por categoria, status com ícone+texto, semântica agrupada, rótulo de pesquisa, obrigatoriedade e diálogo destrutivo reutilizável.  
Telas afetadas: dashboard, escolas, atletas, times, competições, calendário, partidas e rankings.  
WCAG: 1.3.1, 1.4.1, 2.4.6, 3.3.1, 3.3.2, 3.3.3, 4.1.2.

### `mobile/lib/screens/auth_screens.dart`

Problema: alternância de senha sem nome, primeiro campo sem ação “Próximo” e obrigatoriedade pouco explícita.  
Solução: tooltip dinâmico, foco e ações de teclado, hints, asterisco/instrução e bloqueio preservado durante login.  
WCAG: 2.1.1, 2.4.3, 2.4.6, 3.3.2, 4.1.2.

### `mobile/lib/screens/dashboard_screen.dart`

Problema: cartões não agrupavam nome/quantidade/ação; botão atualizar não tinha nome; grade podia ficar apertada com fonte ampliada.  
Solução: semântica em `MetricCard`, tooltip e proporção responsiva à escala textual.  
WCAG: 1.4.4, 2.4.6, 4.1.2.

### `mobile/lib/screens/ranking_screens.dart`

Problema: posição, entidade e pontos eram anunciados como fragmentos.  
Solução: descrição agrupada “Nº lugar, nome, pontos e resumo”, mantendo posição escrita.  
WCAG: 1.4.1, 4.1.2.

### `mobile/lib/screens/competition_screens.dart`

Problema: ações de calendário por ícone não tinham nome acessível.  
Solução: tooltips para período, locais, limpar filtro e editar partida. Os jogos usam o `MatchCard` textual.  
WCAG: 2.4.6, 4.1.2.

### `mobile/lib/screens/match_screens.dart`

Problema: atualização e placar ao vivo precisavam de contexto semântico integral.  
Solução: tooltips e região ao vivo com times, pontuação e situação textual.  
WCAG: 1.4.1, 4.1.2.

### `mobile/lib/screens/student_screens.dart`, `team_screens.dart`, `shell_screen.dart`, `app.dart`

Problema: ações de edição/logomarca sem nome explícito e animação sem respeitar redução de movimento.  
Solução: tooltips/labels e duração zero quando `disableAnimations` está ativo.  
WCAG: 2.3.3, 2.4.6, 3.2.3, 4.1.2.

### `mobile/test/accessibility_test.dart`

Cobertura: rótulos e erros de campo obrigatório, status redundante a cor, regiões de loading/erro, cartões críticos e alvos de toque.

