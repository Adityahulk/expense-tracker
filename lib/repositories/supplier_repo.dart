import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/supplier.dart';

class SupplierRepo {
  SupplierRepo(this._db);
  final AppDatabase _db;
  Database get _conn => _db.db;

  Future<List<Supplier>> listSuppliers() async {
    final rows = await _conn.query('suppliers', orderBy: 'name COLLATE NOCASE');
    return rows.map(Supplier.fromMap).toList();
  }

  Future<Supplier?> findSupplier(int id) async {
    final rows =
        await _conn.query('suppliers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Supplier.fromMap(rows.first);
  }

  Future<int> createSupplier(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Supplier name cannot be empty');
    return _conn.insert('suppliers', {
      'name': trimmed,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> renameSupplier(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Supplier name cannot be empty');
    await _conn.update(
      'suppliers',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count of expenses that reference this supplier on either side.
  Future<int> expenseCountForSupplier(int id) async {
    final r = await _conn.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses '
      'WHERE from_supplier_id = ? OR to_supplier_id = ?',
      [id, id],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> deleteSupplier(int id) async {
    await _conn.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }
}
