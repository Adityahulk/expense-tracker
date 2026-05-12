import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/expense.dart';

class ExpenseFilter {
  final List<int> materialIds;
  final List<int> qualityIds;
  final String? dateFrom; // inclusive, yyyy-MM-dd
  final String? dateTo; // inclusive
  final double? minCost;
  final double? maxCost;

  const ExpenseFilter({
    this.materialIds = const [],
    this.qualityIds = const [],
    this.dateFrom,
    this.dateTo,
    this.minCost,
    this.maxCost,
  });

  bool get isEmpty =>
      materialIds.isEmpty &&
      qualityIds.isEmpty &&
      dateFrom == null &&
      dateTo == null &&
      minCost == null &&
      maxCost == null;
}

class ExpenseRepo {
  ExpenseRepo(this._db);
  final AppDatabase _db;
  Database get _conn => _db.db;

  Future<int> insert(Expense e) => _conn.insert('expenses', e.toMap());

  Future<int> update(Expense e) {
    if (e.id == null) {
      throw ArgumentError('Cannot update expense without id');
    }
    return _conn.update(
      'expenses',
      e.toMap(),
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<void> delete(int id) async {
    await _conn.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Expense?> findById(int id) async {
    final rows =
        await _conn.query('expenses', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Expense.fromMap(rows.first);
  }

  /// Find expenses with the same business fields as [candidate], EXCLUDING
  /// `person_name`. If [excludeId] is given, that row is ignored (used when
  /// editing).
  ///
  /// Note: notes are compared case-insensitively and after trimming, mirroring
  /// the UX expectation that whitespace/case typos don't make entries unique.
  Future<List<Expense>> findDuplicates(
    Expense candidate, {
    int? excludeId,
  }) async {
    final normalisedNote = _normaliseNote(candidate.note);
    final conditions = <String>[
      'material_id = ?',
      'cost = ?',
      'quantity = ?',
      'date = ?',
    ];
    final args = <Object?>[
      candidate.materialId,
      candidate.cost,
      candidate.quantity,
      candidate.date,
    ];

    if (candidate.qualityId == null) {
      conditions.add('quality_id IS NULL');
    } else {
      conditions.add('quality_id = ?');
      args.add(candidate.qualityId);
    }
    if (candidate.unitId == null) {
      conditions.add('unit_id IS NULL');
    } else {
      conditions.add('unit_id = ?');
      args.add(candidate.unitId);
    }
    if (normalisedNote == null) {
      conditions.add('(note IS NULL OR TRIM(LOWER(note)) = \'\')');
    } else {
      conditions.add('TRIM(LOWER(COALESCE(note, \'\'))) = ?');
      args.add(normalisedNote);
    }
    if (excludeId != null) {
      conditions.add('id != ?');
      args.add(excludeId);
    }

    final rows = await _conn.query(
      'expenses',
      where: conditions.join(' AND '),
      whereArgs: args,
    );
    return rows.map(Expense.fromMap).toList();
  }

  static String? _normaliseNote(String? note) {
    if (note == null) return null;
    final t = note.trim().toLowerCase();
    return t.isEmpty ? null : t;
  }

  /// Recent expenses, joined with names, newest first.
  Future<List<ExpenseRow>> listRecent({int limit = 30, int offset = 0}) async {
    final rows = await _conn.rawQuery('''
      SELECT e.*,
             m.name AS material_name,
             q.name AS quality_name,
             u.name AS unit_name
      FROM expenses e
      JOIN materials m ON m.id = e.material_id
      LEFT JOIN qualities q ON q.id = e.quality_id
      LEFT JOIN units     u ON u.id = e.unit_id
      ORDER BY e.date DESC, e.created_at DESC
      LIMIT ? OFFSET ?
    ''', [limit, offset]);
    return rows.map(_rowToExpenseRow).toList();
  }

  /// Filter results for the Search screen.
  Future<List<ExpenseRow>> search(ExpenseFilter f) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (f.materialIds.isNotEmpty) {
      conditions.add('e.material_id IN (${_placeholders(f.materialIds.length)})');
      args.addAll(f.materialIds);
    }
    if (f.qualityIds.isNotEmpty) {
      conditions.add('e.quality_id IN (${_placeholders(f.qualityIds.length)})');
      args.addAll(f.qualityIds);
    }
    if (f.dateFrom != null) {
      conditions.add('e.date >= ?');
      args.add(f.dateFrom);
    }
    if (f.dateTo != null) {
      conditions.add('e.date <= ?');
      args.add(f.dateTo);
    }
    if (f.minCost != null) {
      conditions.add('e.cost >= ?');
      args.add(f.minCost);
    }
    if (f.maxCost != null) {
      conditions.add('e.cost <= ?');
      args.add(f.maxCost);
    }

    final whereClause =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await _conn.rawQuery('''
      SELECT e.*,
             m.name AS material_name,
             q.name AS quality_name,
             u.name AS unit_name
      FROM expenses e
      JOIN materials m ON m.id = e.material_id
      LEFT JOIN qualities q ON q.id = e.quality_id
      LEFT JOIN units     u ON u.id = e.unit_id
      $whereClause
      ORDER BY e.date DESC, e.created_at DESC
    ''', args);
    return rows.map(_rowToExpenseRow).toList();
  }

  /// Full export (all expenses, all master data) for the danger-zone backup
  /// and the "export everything" settings option.
  Future<List<ExpenseRow>> listAll() => search(const ExpenseFilter());

  static String _placeholders(int n) => List.filled(n, '?').join(',');

  static ExpenseRow _rowToExpenseRow(Map<String, Object?> r) {
    final mat = r['material_name'] as String;
    final qual = r['quality_name'] as String?;
    final unit = r['unit_name'] as String?;
    // Build expense from the same row (Expense.fromMap ignores joined name cols).
    return ExpenseRow(
      expense: Expense.fromMap(r),
      materialName: mat,
      qualityName: qual,
      unitName: unit,
    );
  }
}
