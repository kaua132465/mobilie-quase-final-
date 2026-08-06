import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_scope.dart';
import 'core/session_controller.dart';
import 'core/theme.dart';
import 'core/update_checker.dart';
import 'screens/auth_screens.dart';
import 'screens/shell_screen.dart';

class AceApp extends StatelessWidget {
  const AceApp({required this.session, super.key});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: session,
      child: MaterialApp(
        title: 'ACE',
        debugShowCheckedModeBanner: false,
        theme: buildAceTheme(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const UpdateGate(child: SessionGate()),
      ),
    );
  }
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    if (!session.initialized) {
      return const _AceSplashScreen();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: session.isAuthenticated
          ? const MainShell(key: ValueKey('shell'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}

class _AceSplashScreen extends StatelessWidget {
  const _AceSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AceColors.navy,
      body: SafeArea(
        child: Center(
          child: FractionallySizedBox(
            widthFactor: .88,
            child: Image(
              image: AssetImage('assets/images/ace_logo.png'),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
