# Tutorial para executar o ACE em outra máquina

Este guia considera um computador com Windows 10 ou Windows 11.

## 1. Requisitos

Instale os seguintes programas:

1. **Docker Desktop**
   - Download: https://www.docker.com/products/docker-desktop/
   - Durante a instalação, mantenha o uso do WSL 2 habilitado.
   - Depois de instalar, abra o Docker Desktop e aguarde aparecer como iniciado.

2. **Flutter SDK**
   - Instruções: https://docs.flutter.dev/get-started/install/windows/mobile
   - Adicione a pasta `flutter\bin` ao `PATH` do Windows.

3. **Android Studio**
   - Download: https://developer.android.com/studio
   - Instale o Android SDK, Platform Tools e um emulador Android.

4. **Visual Studio Code** (opcional, mas recomendado)
   - Instale as extensões **Flutter** e **Dart**.

Depois, feche e abra novamente o terminal.

## 2. Verificar a instalação

Abra o PowerShell e execute:

```powershell
docker --version
docker compose version
flutter doctor
```

Resolva os itens indicados pelo `flutter doctor` para Android. O Visual Studio
com C++ só é necessário para compilar uma versão desktop para Windows.

Para aceitar as licenças do Android:

```powershell
flutter doctor --android-licenses
```

## 3. Extrair e abrir o projeto

Extraia `ACE.zip` para uma pasta sem caracteres especiais, por exemplo:

```text
C:\Projetos\ACE
```

A estrutura deve ficar assim:

```text
ACE
├── backend
├── mobile
├── README.md
├── INICIAR_BACKEND.bat
└── VALIDAR_MOBILE.bat
```

## 4. Iniciar banco de dados e API

Abra o Docker Desktop. Depois, na pasta `ACE`, execute:

```powershell
cd backend
docker compose up
```

Na primeira execução, o Docker baixa as imagens do Dart e PostgreSQL. Isso pode
demorar alguns minutos.

Quando aparecer a mensagem abaixo, a API estará pronta:

```text
ACE API (geral + mobile) disponível em http://0.0.0.0:8080
```

Também é possível iniciar clicando duas vezes em:

```text
INICIAR_BACKEND.bat
```

Não feche esse terminal enquanto estiver usando o aplicativo.

Para testar a API no navegador:

```text
http://localhost:8080/api/mobile/saude
```

Para encerrar os serviços:

```powershell
docker compose down
```

Para apagar o banco local e recriá-lo com os dados demonstrativos:

```powershell
docker compose down -v
docker compose up
```

> Atenção: `docker compose down -v` apaga os dados locais do PostgreSQL.

## 5. Preparar o aplicativo Flutter

Abra outro PowerShell na pasta `ACE` e execute:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```

O primeiro comando baixa as dependências do aplicativo.

Também é possível executar essas verificações por:

```text
VALIDAR_MOBILE.bat
```

## 6. Executar no Android Emulator

Abra um emulador pelo Android Studio. Confira se ele foi reconhecido:

```powershell
flutter devices
```

Na pasta `ACE\mobile`, execute:

```powershell
flutter run
```

No emulador Android, o aplicativo usa automaticamente:

```text
http://10.0.2.2:8080/api/mobile
```

## 7. Executar em celular Android físico

### Ativar a depuração USB

1. No celular, abra **Configurações > Sobre o telefone**.
2. Toque sete vezes em **Número da versão**.
3. Abra **Opções do desenvolvedor**.
4. Ative **Depuração USB**.
5. Conecte o cabo e autorize o computador no celular.

Confira a conexão:

```powershell
flutter devices
```

### Descobrir o IP do computador

Execute:

```powershell
ipconfig
```

Procure o **Endereço IPv4** do adaptador Wi-Fi. Exemplo:

```text
192.168.1.50
```

O celular e o computador precisam estar na mesma rede Wi-Fi.

### Executar com a API correta

Substitua `IP_DO_COMPUTADOR` pelo endereço encontrado:

```powershell
flutter run --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:8080/api/mobile
```

Exemplo:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080/api/mobile
```

Também é possível alterar o endereço dentro do aplicativo em:

```text
Mais > Configuração da API
```

Depois de instalado, o aplicativo continua funcionando sem o cabo, desde que o
computador e o celular estejam na mesma rede e o back-end continue ativo.

## 8. Contas de demonstração

Todas usam a senha:

```text
Admin@123
```

Contas:

```text
admin@ace.local
escola@ace.local
atleta@ace.local
arbitro@ace.local
```

## 9. Liberar a porta no Firewall do Windows

Se o aplicativo abrir, mas não conectar à API no celular:

1. Confirme que o Docker está ativo.
2. Confirme que o endereço IP está correto.
3. Confirme que os dispositivos estão na mesma rede.
4. Permita o Docker e a porta TCP `8080` no Firewall do Windows.

Para criar uma regra pelo PowerShell aberto como Administrador:

```powershell
New-NetFirewallRule -DisplayName "ACE API 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
```

## 10. Problemas comuns

### `flutter` não é reconhecido

A pasta `flutter\bin` não está no `PATH`. Configure o PATH e reinicie o VS Code
e o terminal.

### Todos os arquivos Dart aparecem em vermelho

Abra diretamente a pasta `ACE\mobile` no VS Code e execute:

```powershell
flutter pub get
```

Depois pressione `Ctrl+Shift+P` e execute:

```text
Dart: Restart Analysis Server
```

### Celular aparece como `unauthorized`

Desbloqueie o celular, desconecte e conecte o cabo novamente e aceite a
solicitação de depuração USB.

### Aplicativo mostra “não foi possível conectar”

Confira o endereço em **Mais > Configuração da API**. Em celular físico não use
`localhost` nem `10.0.2.2`; use o IP Wi-Fi do computador.

### Porta 8080 já está em uso

Descubra o processo:

```powershell
Get-NetTCPConnection -LocalPort 8080
```

Encerre o serviço conflitante ou altere o mapeamento de porta no
`backend\docker-compose.yml`.

### Banco não contém os dados demonstrativos

Recrie o volume:

```powershell
cd backend
docker compose down -v
docker compose up
```

Esse comando apaga qualquer dado local anterior e executa novamente as
migrações e seeds.

