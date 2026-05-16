import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/site.dart';

class PlotCountTooLowException implements Exception {
  final int requested;
  final int maxUsed;
  PlotCountTooLowException({required this.requested, required this.maxUsed});

  @override
  String toString() =>
      'Cannot reduce plot count to $requested — plot #$maxUsed is referenced '
      'by an existing expense. Remove those entries first.';
}

class SiteRepo {
  SiteRepo(this._db);
  final AppDatabase _db;
  Database get _conn => _db.db;

  Future<List<Site>> listSites() async {
    final rows = await _conn.query('sites', orderBy: 'name COLLATE NOCASE');
    return rows.map(Site.fromMap).toList();
  }

  Future<Site?> findSite(int id) async {
    final rows = await _conn.query('sites', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Site.fromMap(rows.first);
  }

  Future<int> createSite(String name, {int plotCount = 0}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Site name cannot be empty');
    if (plotCount < 0) {
      throw ArgumentError('Plot count must be 0 or greater');
    }
    return _conn.insert('sites', {
      'name': trimmed,
      'plot_count': plotCount,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> renameSite(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Site name cannot be empty');
    await _conn.update(
      'sites',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Sets the plot count for the given site. Rejects with
  /// [PlotCountTooLowException] if any expense references a plot above the
  /// proposed new max.
  Future<void> setPlotCount(int siteId, int newCount) async {
    if (newCount < 0) {
      throw ArgumentError('Plot count must be 0 or greater');
    }
    final maxUsed = await maxUsedPlotNumber(siteId);
    if (maxUsed != null && newCount < maxUsed) {
      throw PlotCountTooLowException(requested: newCount, maxUsed: maxUsed);
    }
    await _conn.update(
      'sites',
      {'plot_count': newCount},
      where: 'id = ?',
      whereArgs: [siteId],
    );
  }

  /// Returns the maximum plot number referenced for this site across both
  /// From and To sides, or null if none.
  Future<int?> maxUsedPlotNumber(int siteId) async {
    final r = await _conn.rawQuery(
      '''
      SELECT MAX(p) AS m FROM (
        SELECT from_plot_number AS p FROM expenses
          WHERE from_site_id = ? AND from_kind = 'plot'
        UNION ALL
        SELECT to_plot_number AS p FROM expenses
          WHERE to_site_id = ? AND to_kind = 'plot'
      )
      ''',
      [siteId, siteId],
    );
    final v = r.first['m'];
    if (v == null) return null;
    return (v as num).toInt();
  }

  /// Count of expenses that reference this site on either side.
  Future<int> expenseCountForSite(int id) async {
    final r = await _conn.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses '
      'WHERE from_site_id = ? OR to_site_id = ?',
      [id, id],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> deleteSite(int id) async {
    await _conn.delete('sites', where: 'id = ?', whereArgs: [id]);
  }
}
