import 'dart:io';

import 'package:postgres/postgres.dart';

class Database {
  Database._(this.pool);

  final Pool pool;

  factory Database.fromEnvironment() {
    final url = Platform.environment['DATABASE_URL'];
    if (url == null || url.trim().isEmpty) {
      throw StateError('Defina a variável DATABASE_URL antes de iniciar a API.');
    }
    return Database._(Pool.withUrl(url));
  }

  Future<void> testConnection() async {
    await pool.execute('SELECT 1');
  }

  Future<void> close() => pool.close();
}
