# Validação do projeto Flutter

## Conferências realizadas

- Estrutura Flutter com `pubspec.yaml`, `lib`, `assets`, `android`, `web` e `test`.
- Todos os imports locais apontam para arquivos existentes.
- Todas as classes de tela utilizadas na navegação foram localizadas no projeto.
- Identidade visual Aether incluída em assets e ícones Android/Web.
- URL padrão separada por plataforma:
  - Android Emulator: `http://10.0.2.2:8080/api/mobile`;
  - Web/desktop: `http://localhost:8080/api/mobile`;
  - celular físico: configurável no próprio aplicativo.
- Autenticação persistida localmente e token Bearer enviado pela camada HTTP.
- Estados de carregamento, lista vazia, falha, atualização e confirmação implementados.
- Navegação e permissões ajustadas conforme o perfil autenticado.

## Limitação da validação neste ambiente

O SDK Flutter/Dart não está instalado no ambiente usado para gerar os arquivos. Por isso, não foi possível executar aqui:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Antes da apresentação, esses quatro comandos devem ser executados no computador do projeto. O arquivo `COMO_EXECUTAR.bat` automatiza `flutter pub get` e `flutter run` no Windows.
