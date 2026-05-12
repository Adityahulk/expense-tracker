import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/expense.dart';
import '../models/material.dart';
import '../models/quality.dart';
import '../models/unit.dart';
import '../repositories/expense_repo.dart';
import '../repositories/material_repo.dart';

/// Set in main() via ProviderScope.overrides before runApp.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in main()');
});

final materialRepoProvider = Provider<MaterialRepo>((ref) {
  return MaterialRepo(ref.watch(databaseProvider));
});

final expenseRepoProvider = Provider<ExpenseRepo>((ref) {
  return ExpenseRepo(ref.watch(databaseProvider));
});

// ─── Reactive lists ──────────────────────────────────────────────────────────

/// Bumps after any mutation so all watchers refresh.
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

final recentExpensesProvider =
    FutureProvider.autoDispose<List<ExpenseRow>>((ref) {
  ref.watch(_refreshCounterProvider);
  return ref.watch(expenseRepoProvider).listRecent(limit: 100);
});
