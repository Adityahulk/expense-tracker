import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/expense.dart';
import '../models/material.dart';
import '../models/quality.dart';
import '../models/site.dart';
import '../models/supplier.dart';
import '../models/unit.dart';
import '../repositories/expense_repo.dart';
import '../repositories/material_repo.dart';
import '../repositories/site_repo.dart';
import '../repositories/supplier_repo.dart';
import '../services/passcode_service.dart';

/// Holds the currently-unlocked vault DB. `null` before the lock screen is
/// passed.
final activeDatabaseStateProvider = StateProvider<AppDatabase?>((_) => null);

/// Exposes the currently-unlocked DB as a non-nullable AppDatabase. Reading
/// this before unlock throws.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = ref.watch(activeDatabaseStateProvider);
  if (db == null) {
    throw StateError(
        'databaseProvider read before vault was unlocked. This is a bug.');
  }
  return db;
});

final activeVaultRoleProvider = StateProvider<VaultRole>((_) => VaultRole.main);

final passcodeServiceProvider = Provider<PasscodeService>((_) {
  return PasscodeService();
});

final materialRepoProvider = Provider<MaterialRepo>((ref) {
  return MaterialRepo(ref.watch(databaseProvider));
});

final supplierRepoProvider = Provider<SupplierRepo>((ref) {
  return SupplierRepo(ref.watch(databaseProvider));
});

final siteRepoProvider = Provider<SiteRepo>((ref) {
  return SiteRepo(ref.watch(databaseProvider));
});

final expenseRepoProvider = Provider<ExpenseRepo>((ref) {
  return ExpenseRepo(ref.watch(databaseProvider));
});

// ─── Reactive lists ──────────────────────────────────────────────────────────

final _refreshCounterProvider = StateProvider<int>((_) => 0);

void notifyDataChanged(WidgetRef ref) {
  ref.read(_refreshCounterProvider.notifier).state++;
}

final materialsProvider = FutureProvider.autoDispose<List<MaterialItem>>((ref) {
  ref.watch(_refreshCounterProvider);
  return ref.watch(materialRepoProvider).listMaterials();
});

final qualitiesProvider =
    FutureProvider.autoDispose.family<List<Quality>, int>((ref, materialId) {
  ref.watch(_refreshCounterProvider);
  return ref.watch(materialRepoProvider).listQualities(materialId);
});

final unitsProvider =
    FutureProvider.autoDispose.family<List<UnitItem>, int>((ref, materialId) {
  ref.watch(_refreshCounterProvider);
  return ref.watch(materialRepoProvider).listUnits(materialId);
});

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) {
  ref.watch(_refreshCounterProvider);
  return ref.watch(supplierRepoProvider).listSuppliers();
});

final sitesProvider = FutureProvider.autoDispose<List<Site>>((ref) {
  ref.watch(_refreshCounterProvider);
  return ref.watch(siteRepoProvider).listSites();
});

final recentExpensesProvider =
    FutureProvider.autoDispose<List<ExpenseRow>>((ref) {
  ref.watch(_refreshCounterProvider);
  return ref.watch(expenseRepoProvider).listRecent(limit: 100);
});
