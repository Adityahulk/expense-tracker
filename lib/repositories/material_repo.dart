import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/material.dart';
import '../models/quality.dart';
import '../models/unit.dart';

class MaterialRepo {
  MaterialRepo(this._db);
  final AppDatabase _db;
  Database get _conn => _db.db;

  // ── Materials ──────────────────────────────────────────────────────────────

  Future<List<MaterialItem>> listMaterials() async {
    final rows = await _conn.query('materials', orderBy: 'name COLLATE NOCASE');
    return rows.map(MaterialItem.fromMap).toList();
  }

  Future<MaterialItem?> findMaterial(int id) async {
    final rows =
        await _conn.query('materials', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return MaterialItem.fromMap(rows.first);
  }

  Future<int> createMaterial(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Material name cannot be empty');
    return _conn.insert('materials', {
      'name': trimmed,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> renameMaterial(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Material name cannot be empty');
    await _conn.update(
      'materials',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns the count of expenses that reference this material. Use this to
  /// warn the user before deleting.
  Future<int> expenseCountForMaterial(int id) async {
    final r = await _conn.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses WHERE material_id = ?',
      [id],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> deleteMaterial(int id) async {
    await _conn.delete('materials', where: 'id = ?', whereArgs: [id]);
  }

  // ── Qualities ──────────────────────────────────────────────────────────────

  Future<List<Quality>> listQualities(int materialId) async {
    final rows = await _conn.query(
      'qualities',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Quality.fromMap).toList();
  }

  Future<int> createQuality(int materialId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Quality name cannot be empty');
    return _conn.insert('qualities', {
      'material_id': materialId,
      'name': trimmed,
    });
  }

  Future<void> renameQuality(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Quality name cannot be empty');
    await _conn.update(
      'qualities',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> expenseCountForQuality(int id) async {
    final r = await _conn.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses WHERE quality_id = ?',
      [id],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> deleteQuality(int id) async {
    await _conn.delete('qualities', where: 'id = ?', whereArgs: [id]);
  }

  // ── Units ──────────────────────────────────────────────────────────────────

  Future<List<UnitItem>> listUnits(int materialId) async {
    final rows = await _conn.query(
      'units',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(UnitItem.fromMap).toList();
  }

  Future<int> createUnit(int materialId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Unit name cannot be empty');
    return _conn.insert('units', {
      'material_id': materialId,
      'name': trimmed,
    });
  }

  Future<void> renameUnit(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Unit name cannot be empty');
    await _conn.update(
      'units',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> expenseCountForUnit(int id) async {
    final r = await _conn.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses WHERE unit_id = ?',
      [id],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> deleteUnit(int id) async {
    await _conn.delete('units', where: 'id = ?', whereArgs: [id]);
  }
}
