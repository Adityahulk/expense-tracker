import 'dart:io';

import 'package:path/path.dart' as p;

import '../db/database.dart';
import '../models/quality.dart';
import '../models/unit.dart';
import '../repositories/expense_repo.dart';
import '../repositories/material_repo.dart';
import 'excel_export_service.dart';
import 'file_paths.dart';

class BackupResult {
  final String backupDirPath;
  final String excelPath;
  final String dbCopyPath;
  const BackupResult({
    required this.backupDirPath,
    required this.excelPath,
    required this.dbCopyPath,
  });
}

class BackupService {
  BackupService({
    required this.db,
    required this.materialRepo,
    required this.expenseRepo,
  });

  final AppDatabase db;
  final MaterialRepo materialRepo;
  final ExpenseRepo expenseRepo;

  /// Writes an Excel backup AND a raw SQLite copy into
  /// `<Downloads>/expense-tracker/backup_<ts>/` and returns both paths.
  Future<BackupResult> createFullBackup() async {
    final downloads = await FilePaths.downloadsDir();
    final ts = FilePaths.timestampSuffix();
    final backupDir = Directory(p.join(downloads, 'backup_$ts'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    // 1. Excel: pulls expenses + master data.
    final expenses = await expenseRepo.listAll();
    final materials = await materialRepo.listMaterials();
    final qualitiesByMaterial = <int, List<Quality>>{};
    final unitsByMaterial = <int, List<UnitItem>>{};
    for (final m in materials) {
      if (m.id == null) continue;
      qualitiesByMaterial[m.id!] = await materialRepo.listQualities(m.id!);
      unitsByMaterial[m.id!] = await materialRepo.listUnits(m.id!);
    }

    final excelService = ExcelExportService();
    final tmpExcelPath = await excelService.exportFullBackup(
      expenses: expenses,
      materials: materials,
      qualitiesByMaterial: qualitiesByMaterial,
      unitsByMaterial: unitsByMaterial,
    );
    // Move from Downloads root to the timestamped subfolder.
    final finalExcelPath = p.join(backupDir.path, p.basename(tmpExcelPath));
    await File(tmpExcelPath).rename(finalExcelPath);

    // 2. Raw SQLite copy (so any future tool can reconstruct everything).
    final dbCopyPath = p.join(backupDir.path, 'expense_tracker.db');
    await File(db.path).copy(dbCopyPath);

    return BackupResult(
      backupDirPath: backupDir.path,
      excelPath: finalExcelPath,
      dbCopyPath: dbCopyPath,
    );
  }
}
