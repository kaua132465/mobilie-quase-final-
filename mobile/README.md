# Aether Mobile

Projeto Flutter/Dart das telas Mobile do TCC **Sistema de Gestão Esportiva Escolar**.

## Abrir e executar

1. Abra esta pasta no VS Code.
2. Confirme que a API está rodando com `docker compose up` no projeto back-end.
3. Execute:

```bash
flutter pub get
flutter run
```

No Android Emulator, o app usa por padrão:

```text
http://10.0.2.2:8080/api/mobile
```

No Windows, Chrome e iOS Simulator, usa:

```text
http://localhost:8080/api/mobile
```

Em celular físico, abra **Mais > Configuração da API** e informe o IP do computador, por exemplo:

```text
http://192.168.0.10:8080/api/mobile
```

## Usuários de demonstração

Senha para todos: `Admin@123`

- `admin@aether.local`
- `escola@aether.local`
- `atleta@aether.local`
- `arbitro@aether.local`

## Plataformas

O projeto inclui Web e Android. Caso o Android Studio peça para regenerar arquivos nativos, execute uma vez:

```bash
flutter create --platforms=android,web .
flutter pub get
```

Os arquivos da pasta `lib/` e os assets não são perdidos.


## Conteúdo implementado

- Login, recuperação de senha e sessão persistente;
- painel inicial por perfil;
- perfil e consulta de escolas;
- cadastro, consulta, edição, histórico e estatísticas de atletas;
- cadastro e gestão de times, elenco, capitão, funções e escalação;
- competições, inscrições, calendário e locais;
- partidas ao vivo com atualização automática;
- arbitragem, placar, pontuações, penalidades, resultado e publicação;
- rankings de escolas, equipes e atletas;
- tratamento de carregamento, erro, listas vazias e confirmações;
- configuração da API dentro do aplicativo.

Consulte `MAPEAMENTO_TELAS_MOBILE.md` para ver cada caso de uso, tela e endpoint.

## Primeira execução no Android

O projeto possui os arquivos Android. Caso o `gradle-wrapper.jar` ainda não esteja presente, o script Android tenta baixá-lo automaticamente na primeira compilação. Outra forma de regenerar os arquivos nativos é:

```bash
flutter create --platforms=android,web .
flutter pub get
```

Depois mantenha a API iniciada e execute:

```bash
flutter run
```
