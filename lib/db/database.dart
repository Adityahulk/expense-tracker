import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Wraps a single sqflite [Database] instance for the whole app.
class AppDatabase {
  AppDatabase._(this.db, this.path);

  final Database db;
  final String path;

  static AppDatabase? _instance;

  static Future<AppDatabase> open({String? overridePath}) async {
    if (_instance != null) return _instance!;
    final dbPath = overridePath ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'expense_tracker.db',
        );
    final db = await openDatabase(
      dbPath,
      version: kSchemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        for (final stmt in kCreateStatements) {
          await db.execute(stmt);
        }
      },
      onUpgrade: (db, oldV, newV) async {
        for (var v = oldV + 1; v <= newV; v++) {
          for (final stmt in (migrationSteps[v] ?? const <String>[])) {
            await db.execute(stmt);
          }
        }
      },
    );
    final instance = AppDatabase._(db, dbPath);
    _instance = instance;
    return instance;
  }

  /// Used by danger-zone wipe to re-create empty tables.
  Future<void> wipeAll() async {
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      await txn.delete('expenses');
      await txn.delete('qualities');
      await txn.delete('units');
      await txn.delete('materials');
      // Reset auto-increment counters.
      await txn.delete('sqlite_sequence');
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  /// For tests.
  static void resetForTesting() {
    _instance = null;
  }

  Future<void> close() async {
    await db.close();
    _instance = null;
  }
}
