import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  const EmailService({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromEmail,
    required this.fromName,
    required this.ssl,
  });

  factory EmailService.fromEnvironment() {
    final environment = Platform.environment;
    return EmailService(
      host: environment['SMTP_HOST']?.trim() ?? '',
      port: int.tryParse(environment['SMTP_PORT'] ?? '') ?? 587,
      username: environment['SMTP_USERNAME']?.trim() ?? '',
      password: environment['SMTP_PASSWORD'] ?? '',
      fromEmail: environment['SMTP_FROM_EMAIL']?.trim() ?? '',
      fromName: environment['SMTP_FROM_NAME']?.trim() ?? 'Aether',
      ssl: (environment['SMTP_SSL'] ?? '').toLowerCase() == 'true',
    );
  }

  final String host;
  final int port;
  final String username;
  final String password;
  final String fromEmail;
  final String fromName;
  final bool ssl;

  bool get isConfigured =>
      host.isNotEmpty &&
      username.isNotEmpty &&
      password.isNotEmpty &&
      fromEmail.isNotEmpty;

  Future<void> sendPasswordResetCode({
    required String recipientEmail,
    required String recipientName,
    required String code,
  }) async {
    if (!isConfigured) throw StateError('SMTP não configurado.');

    final server = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: ssl,
    );
    final message = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients.add(Address(recipientEmail, recipientName))
      ..subject = 'Código de redefinição de senha - Aether'
      ..text = '''
Olá, $recipientName!

Seu código de redefinição de senha é: $code

O código expira em 15 minutos. Se você não solicitou a redefinição, ignore este e-mail.
'''
      ..html = '''
<h2>Redefinição de senha</h2>
<p>Olá, ${_escapeHtml(recipientName)}!</p>
<p>Use o código abaixo para redefinir sua senha:</p>
<p style="font-size: 28px; font-weight: bold; letter-spacing: 6px;">$code</p>
<p>O código expira em 15 minutos. Se você não fez esta solicitação, ignore este e-mail.</p>
''';

    await send(message, server);
  }

  static String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
