# ACE

Projeto colaborativo com aplicativo Flutter, API Dart e PostgreSQL.

## Estrutura

- `mobile/`: aplicativo Flutter para Android e web.
- `backend/`: API Dart, Docker Compose e migrações do PostgreSQL.

## Requisitos

- Docker Desktop
- Flutter SDK
- Android Studio ou um celular Android com depuração USB

## Iniciar o back-end

Na raiz do projeto:

```powershell
cd backend
docker compose up
```

A API ficará disponível em:

```text
http://localhost:8080/api/mobile
```

O PostgreSQL e os dados de demonstração são criados pelas migrações da pasta
`backend/migrations`.

## Executar o aplicativo

Em outro terminal:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

No Android Emulator, o aplicativo usa `http://10.0.2.2:8080/api/mobile`.
Em celular físico, informe em **Mais > Configuração da API**:

```text
http://IP_DO_COMPUTADOR:8080/api/mobile
```

O celular e o computador precisam estar na mesma rede.

## Contas de demonstração

Senha para todas as contas: `Admin@123`

- `admin@aether.local`
- `escola@aether.local`
- `atleta@aether.local`
- `arbitro@aether.local`

## Observações

Arquivos gerados, caches, APKs e configurações locais de SDK não fazem parte
do pacote. Cada desenvolvedor deve executar `flutter pub get` em sua máquina.
