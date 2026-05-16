import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/expense.dart';
import '../models/route_endpoint.dart';

class ExpenseFilter {
  final List<int> materialIds;
  final List<int> qualityIds;
  final List<int> supplierIds; // matches either from or to
  final List<int> siteIds; // matches either from or to
  final String? dateFrom; // inclusive, yyyy-MM-dd
  final String? dateTo;
  final double? minCost;
  final double? maxCost;

  const ExpenseFilter({
    this.materialIds = const [],
    this.qualityIds = const [],
    this.supplierIds = const [],
    this.siteIds = const [],
    this.dateFrom,
    this.dateTo,
    this.minCost,
    this.maxCost,
  });

  bool get isEmpty =>
      materialIds.isEmpty &&
      qualityIds.isEmpty &&
      supplierIds.isEmpty &&
      siteIds.isEmpty &&
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

  /// Find expenses identical to [candidate] on every business field except
  /// `person_name`. Notes are case-insensitive, whitespace-trimmed. All route
  /// fields and FKs are compared exactly.
  Future<List<Expense>> findDuplicates(
    Expense candidate, {
    int? excludeId,
  }) async {
    final conditions = <String>[
      'material_id = ?',
      'cost = ?',
      'quantity = ?',
      'date = ?',
      'from_kind = ?',
      'to_kind = ?',
    ];
    final args = <Object?>[
      candidate.materialId,
      candidate.cost,
      candidate.quantity,
      candidate.date,
      RouteEndpoint.kindToString(candidate.fromKind),
      RouteEndpoint.kindToString(candidate.toKind),
    ];

    void addNullableEq(String column, Object? value) {
      if (value == null) {
        conditions.add('$column IS NULL');
      } else {
        conditions.add('$column = ?');
        args.add(value);
      }
    }

    addNullableEq('quality_id', candidate.qualityId);
    addNullableEq('unit_id', candidate.unitId);
    addNullableEq('from_supplier_id', candidate.fromSupplierId);
    addNullableEq('from_site_id', candidate.fromSiteId);
    addNullableEq('from_plot_number', candidate.fromPlotNumber);
    addNullableEq('to_supplier_id', candidate.toSupplierId);
    addNullableEq('to_site_id', candidate.toSiteId);
    addNullableEq('to_plot_number', candidate.toPlotNumber);

    final normalisedNote = _normaliseText(candidate.note);
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

  static String? _normaliseText(String? v) {
    if (v == null) return null;
    final t = v.trim().toLowerCase();
    return t.isEmpty ? null : t;
  }

  Future<List<ExpenseRow>> listRecent({int limit = 100, int offset = 0}) async {
    final rows = await _conn.rawQuery('''
      ${_selectWithJoins()}
      ORDER BY e.date DESC, e.created_at DESC
      LIMIT ? OFFSET ?
    ''', [limit, offset]);
    return rows.map(_rowToExpenseRow).toList();
  }

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
    if (f.supplierIds.isNotEmpty) {
      final ph = _placeholders(f.supplierIds.length);
      conditions.add(
          '(e.from_supplier_id IN ($ph) OR e.to_supplier_id IN ($ph))');
      args.addAll(f.supplierIds);
      args.addAll(f.supplierIds);
    }
    if (f.siteIds.isNotEmpty) {
      final ph = _placeholders(f.siteIds.length);
      conditions
          .add('(e.from_site_id IN ($ph) OR e.to_site_id IN ($ph))');
      args.addAll(f.siteIds);
      args.addAll(f.siteIds);
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
      ${_selectWithJoins()}
      $whereClause
      ORDER BY e.date DESC, e.created_at DESC
    ''', args);
    return rows.map(_rowToExpenseRow).toList();
  }

  Future<List<ExpenseRow>> listAll() => search(const ExpenseFilter());

  /// Distinct person names previously typed — used for the autocomplete
  /// suggestion on the (now optional) "Spent by" field.
  Future<List<String>> distinctPersonNames() async {
    final rows = await _conn.rawQuery('''
      SELECT DISTINCT person_name AS v FROM expenses
      WHERE person_name IS NOT NULL AND TRIM(person_name) != ''
      ORDER BY person_name COLLATE NOCASE
    ''');
    return [for (final r in rows) (r['v'] as String)];
  }

  static String _selectWithJoins() => '''
    SELECT e.*,
           m.name  AS material_name,
           q.name  AS quality_name,
           u.name  AS unit_name,
           fs.name AS from_supplier_name,
           fst.name AS from_site_name,
           ts.name AS to_supplier_name,
           tst.name AS to_site_name
    FROM expenses e
    JOIN      materials  m   ON m.id   = e.material_id
    LEFT JOIN qualities  q   ON q.id   = e.quality_id
    LEFT JOIN units      u   ON u.id   = e.unit_id
    LEFT JOIN suppliers  fs  ON fs.id  = e.from_supplier_id
    LEFT JOIN sites      fst ON fst.id = e.from_site_id
    LEFT JOIN suppliers  ts  ON ts.id  = e.to_supplier_id
    LEFT JOIN sites      tst ON tst.id = e.to_site_id
  ''';

  static String _placeholders(int n) => List.filled(n, '?').join(',');

  static ExpenseRow _rowToExpenseRow(Map<String, Object?> r) {
    return ExpenseRow(
      expense: Expense.fromMap(r),
      materialName: r['material_name'] as String,
      qualityName: r['quality_name'] as String?,
      unitName: r['unit_name'] as String?,
      fromSupplierName: r['from_supplier_name'] as String?,
      fromSiteName: r['from_site_name'] as String?,
      toSupplierName: r['to_supplier_name'] as String?,
      toSiteName: r['to_site_name'] as String?,
    );
  }
}
