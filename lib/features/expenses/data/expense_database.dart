import 'package:path/path.dart' as path_utils;
import 'package:sqflite/sqflite.dart';

/// Owns the local database connection, with an injectable factory for tests.
final class ExpenseDatabase {
  ExpenseDatabase({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? path;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final databasePath =
          path ??
          path_utils.join(
            await _factory.getDatabasesPath(),
            'expense_pro.sqlite',
          );
      return await _factory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE expenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 120),
                amount_cents INTEGER NOT NULL CHECK(amount_cents > 0 AND amount_cents <= 999999999999),
                category TEXT NOT NULL CHECK(category IN ('food','transport','shopping','bills','health','entertainment','education','other')),
                occurred_at INTEGER NOT NULL,
                note TEXT NOT NULL DEFAULT '' CHECK(length(note) <= 1000),
                payment_method TEXT NOT NULL CHECK(payment_method IN ('cash','card','mobileBanking'))
              )
            ''');
            await database.execute(
              'CREATE INDEX expense_date_idx ON expenses(occurred_at DESC, id DESC)',
            );
            await database.execute(
              'CREATE INDEX expense_category_date_idx ON expenses(category, occurred_at DESC)',
            );
            await database.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
          },
        ),
      );
    } catch (_) {
      // Let a subsequent request retry a failed disk or plugin initialization.
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }
}
