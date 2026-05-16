import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Names used for the two vault DBs.
const String kVaultA = 'vault_a';
const String kVaultB = 'vault_b';

/// Wraps a single sqflite [Database] instance for one vault. Multiple vaults
/// can be opened by name; each has its own file and its own [AppDatabase].
class AppDatabase {
  AppDatabase._(this.db, this.path, this.vaultName);

  final Database db;
  final String path;
  final String vaultName;

  static final Map<String, AppDatabase> _instances = {};

  /// Returns the resolved file path for a vault DB without opening it.
  static Future<String> pathForVault(String vaultName) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, '$vaultName.db');
  }

  /// Open (or return the already-open) DB for [vaultName]. Pass
  /// [overridePath] only in tests.
  static Future<AppDatabase> open({
    String vaultName = kVaultA,
    String? overridePath,
  }) async {
    final cached = _instances[vaultName];
    if (cached != null) return cached;

    // One-time migration: if this is the first time we're opening a vault DB
    // on a device that already has a v1 `expense_tracker.db`, rename it.
    final dbPath = overridePath ?? await pathForVault(vaultName);
    if (overridePath == null && vaultName == kVaultA) {
      final legacy = p.join(p.dirname(dbPath), 'expense_tracker.db');
      final vaultAFile = File(dbPath);
      final legacyFile = File(legacy);
      if (!await vaultAFile.exists() && await legacyFile.exists()) {
        await legacyFile.rename(dbPath);
      }
    }

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
    final instance = AppDatabase._(db, dbPath, vaultName);
    _instances[vaultName] = instance;
    return instance;
  }

  /// Used by danger-zone wipe to empty every user-data table.
  Future<void> wipeAll() async {
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      await txn.delete('expenses');
      await txn.delete('qualities');
      await txn.delete('units');
      await txn.delete('materials');
      await txn.delete('suppliers');
      await txn.delete('sites');
      await txn.delete('sqlite_sequence');
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  /// Read raw DB bytes (used for backup).
  Future<List<int>> readBytes() async {
    return File(path).readAsBytes();
  }

  /// For tests.
  static void resetForTesting() {
    _instances.clear();
  }

  Future<void> close() async {
    await db.close();
    _instances.remove(vaultName);
  }
}
