# Acessibilidade e usabilidade — ACE Mobile

## Objetivo

As melhorias deste ciclo apoiam o TCC **ACE — Sistema de Gestão Esportiva Escolar** e buscam conformidade técnica com critérios aplicáveis da WCAG 2.1 nível AA. Este documento não representa certificação de conformidade; uma avaliação completa também exige testes manuais, tecnologias assistivas e usuários reais.

## Melhorias realizadas

- Infraestrutura central em `lib/core/accessibility`, com configuração, mensagens e widgets semânticos reutilizáveis.
- Tema com cor primária de ação escurecida, contraste textual reforçado, erros visuais e textuais, tipografia mínima e alvos de toque Material de 48 dp.
- Cabeçalhos, carregamentos e mensagens de feedback expostos semanticamente.
- Erros diferenciados por validação, autenticação, autorização, conteúdo ausente, servidor e conexão.
- Campos obrigatórios com asterisco, instrução e mensagem textual; ação de teclado e foco configuráveis.
- Pesquisa com rótulo visível/semântico e ação “Limpar pesquisa” identificada.
- Status com texto e ícone, preservando a cor apenas como reforço.
- Cartões de dashboard, partidas e rankings com descrições completas para leitor de tela.
- Placar ao vivo como região atualizável, incluindo times, pontos e situação textual.
- Login com ordem de foco, “Próximo/Concluído”, bloqueio durante autenticação e alternância “Mostrar/Ocultar senha”.
- Ações de ícone críticas com `tooltip`; botões destrutivos existentes mantêm confirmação textual.
- Layout do dashboard ajustado para escala de fonte aumentada e animação de troca de sessão removida quando o sistema solicita redução de movimento.
- Testes de widget para campos obrigatórios, status, loading/erro, cartão semântico e alvo de toque.

## Critérios WCAG relacionados

| Implementação | Critério | Status |
|---|---|---|
| Contraste de texto e controles no tema | 1.4.3, 1.4.11 | Implementado no tema central; requer verificação visual em dispositivo |
| Escala de texto sem bloqueio global | 1.4.4 | Implementado; amostragem manual ampla pendente |
| Navegação por teclado e ordem de foco no login | 2.1.1, 2.4.3 | Implementado |
| Cabeçalhos e rótulos descritivos | 2.4.6 | Implementado nos componentes centrais e fluxos críticos |
| Foco visível Material | 2.4.7 | Implementado pelo tema/controles nativos; teste físico pendente |
| Navegação inferior com rótulos | 3.2.3 | Implementado |
| Erros textuais e sugestões de correção | 3.3.1, 3.3.3 | Implementado |
| Labels, hints e obrigatoriedade | 3.3.2 | Implementado na abstração de formulário |
| Nome, função, valor e estados | 4.1.2 | Implementado nos componentes e telas críticas |

## Recursos Flutter utilizados

`Semantics`, `Tooltip`, `FocusNode`, `FocusTraversalGroup`, `ThemeData`, `ColorScheme`, `SnackBar`, `Form`, `TextFormField`, `SafeArea`, `SingleChildScrollView`, `Flexible`, `Expanded`, `Wrap`, `MediaQuery`, `CircularProgressIndicator` e testes de semântica via `flutter_test`.

## Limitações e testes necessários

- Validar TalkBack em Android físico, incluindo pronúncia, agrupamento e frequência de anúncios do placar.
- Percorrer todos os formulários com teclado físico e Switch Access.
- Fazer inspeção instrumental de contraste de todos os pixels/imagens e estados desabilitados.
- Testar todas as telas em 320, 360 e 412 px, tablet e escalas de fonte de 100%, 150% e 200%.
- Conduzir avaliação com usuários dos perfis ADMINISTRADOR, ORGANIZADOR, ESCOLA, ALUNO e ÁRBITRO.
- Verificar fluxo offline real, perda de sessão no meio da navegação e latência elevada.

