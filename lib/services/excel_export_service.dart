import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../models/material.dart';
import '../models/quality.dart';
import '../models/site.dart';
import '../models/supplier.dart';
import '../models/unit.dart';

class ExcelExportService {
  /// Build an .xlsx for [rows] and return the raw bytes.
  Uint8List buildExpensesXlsx(List<ExpenseRow> rows) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Expenses');
    final sheet = excel['Expenses'];

    _writeExpenseHeader(sheet);
    for (final r in rows) {
      _writeExpenseRow(sheet, r);
    }
    return _save(excel);
  }

  /// Full backup workbook: expenses + master data on separate sheets.
  Uint8List buildFullBackupXlsx({
    required List<ExpenseRow> expenses,
    required List<MaterialItem> materials,
    required Map<int, List<Quality>> qualitiesByMaterial,
    required Map<int, List<UnitItem>> unitsByMaterial,
    required List<Supplier> suppliers,
    required List<Site> sites,
  }) {
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

    final suppliersSheet = excel['Suppliers'];
    suppliersSheet.appendRow(<CellValue>[
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Created'),
    ]);
    for (final s in suppliers) {
      suppliersSheet.appendRow(<CellValue>[
        IntCellValue(s.id ?? 0),
        TextCellValue(s.name),
        TextCellValue(_isoFromEpoch(s.createdAt)),
      ]);
    }

    final sitesSheet = excel['Sites'];
    sitesSheet.appendRow(<CellValue>[
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Plot count'),
      TextCellValue('Created'),
    ]);
    for (final s in sites) {
      sitesSheet.appendRow(<CellValue>[
        IntCellValue(s.id ?? 0),
        TextCellValue(s.name),
        IntCellValue(s.plotCount),
        TextCellValue(_isoFromEpoch(s.createdAt)),
      ]);
    }

    return _save(excel);
  }

  static Uint8List _save(Excel excel) {
    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel.save returned null bytes');
    }
    return Uint8List.fromList(bytes);
  }

  void _writeExpenseHeader(Sheet sheet) {
    sheet.appendRow(<CellValue>[
      TextCellValue('Date'),
      TextCellValue('Material'),
      TextCellValue('Quality'),
      TextCellValue('Quantity'),
      TextCellValue('Unit'),
      TextCellValue('Cost'),
      TextCellValue('From'),
      TextCellValue('To'),
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
      TextCellValue(r.fromDisplay()),
      TextCellValue(r.toDisplay()),
      TextCellValue(e.personName),
      TextCellValue(e.note ?? ''),
      TextCellValue(_isoFromEpoch(e.createdAt)),
    ]);
  }

  static String _isoFromEpoch(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }
}

/// Build a default filename containing a timestamp.
String defaultExpensesFilename({String prefix = 'expenses'}) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${prefix}_${now.year}-${two(now.month)}-${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}.xlsx';
}
