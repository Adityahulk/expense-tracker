import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../db/database.dart';
import '../models/quality.dart';
import '../models/unit.dart';
import '../repositories/expense_repo.dart';
import '../repositories/material_repo.dart';
import '../repositories/site_repo.dart';
import '../repositories/supplier_repo.dart';
import 'excel_export_service.dart';

class BackupBundle {
  final Uint8List zipBytes;
  final String suggestedFilename;
  final int totalExpenses;

  const BackupBundle({
    required this.zipBytes,
    required this.suggestedFilename,
    required this.totalExpenses,
  });
}

class BackupService {
  BackupService({
    required this.db,
    required this.materialRepo,
    required this.supplierRepo,
    required this.siteRepo,
    required this.expenseRepo,
  });

  final AppDatabase db;
  final MaterialRepo materialRepo;
  final SupplierRepo supplierRepo;
  final SiteRepo siteRepo;
  final ExpenseRepo expenseRepo;

  /// Pulls all data, builds Excel + db bytes, zips them, returns the bundle.
  Future<BackupBundle> buildFullBackupZip() async {
    final expenses = await expenseRepo.listAll();
    final materials = await materialRepo.listMaterials();
    final qualitiesByMaterial = <int, List<Quality>>{};
    final unitsByMaterial = <int, List<UnitItem>>{};
    for (final m in materials) {
      if (m.id == null) continue;
      qualitiesByMaterial[m.id!] = await materialRepo.listQualities(m.id!);
      unitsByMaterial[m.id!] = await materialRepo.listUnits(m.id!);
    }
    final suppliers = await supplierRepo.listSuppliers();
    final sites = await siteRepo.listSites();

    final excelService = ExcelExportService();
    final excelBytes = excelService.buildFullBackupXlsx(
      expenses: expenses,
      materials: materials,
      qualitiesByMaterial: qualitiesByMaterial,
      unitsByMaterial: unitsByMaterial,
      suppliers: suppliers,
      sites: sites,
    );
    final dbBytes = await db.readBytes();

    final archive = Archive();
    archive.addFile(ArchiveFile(
      'expense-tracker-backup.xlsx',
      excelBytes.length,
      excelBytes,
    ));
    archive.addFile(ArchiveFile(
      'expense_tracker.db',
      dbBytes.length,
      dbBytes,
    ));
    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      throw StateError('ZipEncoder.encode returned null');
    }

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final ts = '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';

    return BackupBundle(
      zipBytes: Uint8List.fromList(zipped),
      suggestedFilename: 'expense-tracker_backup_$ts.zip',
      totalExpenses: expenses.length,
    );
  }
}
