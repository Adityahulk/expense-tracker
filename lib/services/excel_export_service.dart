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

    _writeExpenseSheet(sheet, rows);
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

    _writeExpenseSheet(excel['Expenses'], expenses);

    final mSheet = excel['Materials'];
    _writeMasterSheet(
      mSheet,
      headers: const ['ID', 'Name', 'Created'],
      widths: const [8, 24, 22],
      rows: [
        for (final m in materials)
          [
            IntCellValue(m.id ?? 0),
            TextCellValue(m.name),
            TextCellValue(_isoFromEpoch(m.createdAt)),
          ],
      ],
    );

    final qSheet = excel['Qualities'];
    _writeMasterSheet(
      qSheet,
      headers: const ['Material', 'Quality'],
      widths: const [24, 20],
      rows: [
        for (final m in materials)
          for (final q in (qualitiesByMaterial[m.id] ?? const <Quality>[]))
            [TextCellValue(m.name), TextCellValue(q.name)],
      ],
    );

    final uSheet = excel['Units'];
    _writeMasterSheet(
      uSheet,
      headers: const ['Material', 'Unit'],
      widths: const [24, 16],
      rows: [
        for (final m in materials)
          for (final u in (unitsByMaterial[m.id] ?? const <UnitItem>[]))
            [TextCellValue(m.name), TextCellValue(u.name)],
      ],
    );

    final sSheet = excel['Suppliers'];
    _writeMasterSheet(
      sSheet,
      headers: const ['ID', 'Name', 'Created'],
      widths: const [8, 24, 22],
      rows: [
        for (final s in suppliers)
          [
            IntCellValue(s.id ?? 0),
            TextCellValue(s.name),
            TextCellValue(_isoFromEpoch(s.createdAt)),
          ],
      ],
    );

    final stSheet = excel['Sites'];
    _writeMasterSheet(
      stSheet,
      headers: const ['ID', 'Name', 'Plot count', 'Created'],
      widths: const [8, 24, 12, 22],
      rows: [
        for (final s in sites)
          [
            IntCellValue(s.id ?? 0),
            TextCellValue(s.name),
            IntCellValue(s.plotCount),
            TextCellValue(_isoFromEpoch(s.createdAt)),
          ],
      ],
    );

    return _save(excel);
  }

  // ── Expense sheet (with formatting) ──────────────────────────────────────

  /// Column layout: title, width (Excel-character units), alignment.
  static const List<_ColSpec> _expenseCols = [
    _ColSpec('Date', 13, HorizontalAlign.Left),
    _ColSpec('Material', 18, HorizontalAlign.Left),
    _ColSpec('Quality', 14, HorizontalAlign.Left),
    _ColSpec('Quantity', 11, HorizontalAlign.Right),
    _ColSpec('Unit', 10, HorizontalAlign.Left),
    _ColSpec('Cost', 13, HorizontalAlign.Right),
    _ColSpec('From', 32, HorizontalAlign.Left, wrap: true),
    _ColSpec('To', 32, HorizontalAlign.Left, wrap: true),
    _ColSpec('Spent by', 18, HorizontalAlign.Left),
    _ColSpec('Note', 36, HorizontalAlign.Left, wrap: true),
    _ColSpec('Recorded at', 21, HorizontalAlign.Left),
  ];

  void _writeExpenseSheet(Sheet sheet, List<ExpenseRow> rows) {
    // Header
    for (var i = 0; i < _expenseCols.length; i++) {
      final col = _expenseCols[i];
      sheet.setColumnWidth(i, col.width);
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(col.title);
      cell.cellStyle = _headerStyle;
    }
    // Data rows
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final values = _expenseCellValues(row);
      for (var c = 0; c < values.length; c++) {
        final col = _expenseCols[c];
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        cell.value = values[c];
        cell.cellStyle = _bodyStyle(
          align: col.align,
          wrap: col.wrap,
        );
      }
    }
  }

  List<CellValue> _expenseCellValues(ExpenseRow r) {
    final e = r.expense;
    return <CellValue>[
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
    ];
  }

  // ── Master sheets (generic helper) ───────────────────────────────────────

  void _writeMasterSheet(
    Sheet sheet, {
    required List<String> headers,
    required List<double> widths,
    required List<List<CellValue>> rows,
  }) {
    assert(headers.length == widths.length);
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        cell.value = row[c];
        cell.cellStyle = _bodyStyle(
          align: row[c] is IntCellValue || row[c] is DoubleCellValue
              ? HorizontalAlign.Right
              : HorizontalAlign.Left,
        );
      }
    }
  }

  // ── Styles ────────────────────────────────────────────────────────────────

  static final CellStyle _headerStyle = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.grey300,
    fontColorHex: ExcelColor.black,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  CellStyle _bodyStyle({
    required HorizontalAlign align,
    bool wrap = false,
  }) =>
      CellStyle(
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        textWrapping: wrap ? TextWrapping.WrapText : null,
      );

  // ── Misc ──────────────────────────────────────────────────────────────────

  static Uint8List _save(Excel excel) {
    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel.save returned null bytes');
    }
    return Uint8List.fromList(bytes);
  }

  static String _isoFromEpoch(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }
}

class _ColSpec {
  final String title;
  final double width;
  final HorizontalAlign align;
  final bool wrap;
  const _ColSpec(this.title, this.width, this.align, {this.wrap = false});
}

/// Build a default filename containing a timestamp.
String defaultExpensesFilename({String prefix = 'expenses'}) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${prefix}_${now.year}-${two(now.month)}-${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}.xlsx';
}
