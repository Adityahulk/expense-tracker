import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../models/expense.dart';
import '../models/material.dart';
import '../models/quality.dart';
import '../models/unit.dart';
import 'file_paths.dart';

class ExcelExportService {
  /// Export a filtered set of expenses to `<Downloads>/expense-tracker/expenses_<ts>.xlsx`.
  /// Returns the absolute path of the created file.
  Future<String> exportExpenses(List<ExpenseRow> rows,
      {String filenamePrefix = 'expenses'}) async {
    final dir = await FilePaths.downloadsDir();
    final filename = '${filenamePrefix}_${FilePaths.timestampSuffix()}.xlsx';
    final path = p.join(dir, filename);

    final excel = Excel.createExcel();
    // Excel.createExcel makes a default sheet named "Sheet1" — rename it.
    excel.rename('Sheet1', 'Expenses');
    final sheet = excel['Expenses'];

    _writeExpenseHeader(sheet);
    for (final r in rows) {
      _writeExpenseRow(sheet, r);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel.save returned null bytes');
    }
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Full backup: expenses + master data, each on its own sheet.
  /// Returns the absolute path of the created file.
  Future<String> exportFullBackup({
    required List<ExpenseRow> expenses,
    required List<MaterialItem> materials,
    required Map<int, List<Quality>> qualitiesByMaterial,
    required Map<int, List<UnitItem>> unitsByMaterial,
    String filenamePrefix = 'expense-tracker_backup',
  }) async {
    final dir = await FilePaths.downloadsDir();
    final filename = '${filenamePrefix}_${FilePaths.timestampSuffix()}.xlsx';
    final path = p.join(dir, filename);

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Expenses');
    final expensesSheet = excel['Expenses'];
    _writeExpenseHeader(expensesSheet);
    for (final r in expenses) {
      _writeExpenseRow(expensesSheet, r);
    }

    final materialsSheet = excel['Materials'];
    materialsSheet.appendRow(<CellValue>[
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Created'),
    ]);
    for (final m in materials) {
      materialsSheet.appendRow(<CellValue>[
        IntCellValue(m.id ?? 0),
        TextCellValue(m.name),
        TextCellValue(_isoFromEpoch(m.createdAt)),
      ]);
    }

    final qualitiesSheet = excel['Qualities'];
    qualitiesSheet.appendRow(<CellValue>[
      TextCellValue('Material'),
      TextCellValue('Quality'),
    ]);
    for (final m in materials) {
      final qs = qualitiesByMaterial[m.id] ?? const [];
      for (final q in qs) {
        qualitiesSheet.appendRow(<CellValue>[
          TextCellValue(m.name),
          TextCellValue(q.name),
        ]);
      }
    }

    final unitsSheet = excel['Units'];
    unitsSheet.appendRow(<CellValue>[
      TextCellValue('Material'),
      TextCellValue('Unit'),
    ]);
    for (final m in materials) {
      final us = unitsByMaterial[m.id] ?? const [];
      for (final u in us) {
        unitsSheet.appendRow(<CellValue>[
          TextCellValue(m.name),
          TextCellValue(u.name),
        ]);
      }
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel.save returned null bytes');
    }
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static final NumberFormat _money = NumberFormat('#,##0.00');

  void _writeExpenseHeader(Sheet sheet) {
    sheet.appendRow(<CellValue>[
      TextCellValue('Date'),
      TextCellValue('Material'),
      TextCellValue('Quality'),
      TextCellValue('Quantity'),
      TextCellValue('Unit'),
      TextCellValue('Cost'),
      TextCellValue('Spent by'),
      TextCellValue('Note'),
      TextCellValue('Recorded at'),
    ]);
  }

  void _writeExpenseRow(Sheet sheet, ExpenseRow r) {
    final e = r.expense;
    sheet.appendRow(<CellValue>[
      TextCellValue(e.date),
      TextCellValue(r.materialName),
      TextCellValue(r.qualityName ?? ''),
      DoubleCellValue(e.quantity),
      TextCellValue(r.unitName ?? ''),
      DoubleCellValue(e.cost),
      TextCellValue(e.personName),
      TextCellValue(e.note ?? ''),
      TextCellValue(_isoFromEpoch(e.createdAt)),
    ]);
  }

  static String _isoFromEpoch(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  // kept for potential future use
  // ignore: unused_element
  static String _formatMoney(double v) => _money.format(v);
}
