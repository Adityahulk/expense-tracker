import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/repositories/expense_repo.dart';
import 'package:expense_tracker/repositories/material_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late MaterialRepo materialRepo;
  late ExpenseRepo expenseRepo;
  late int matDieselId;
  late int qualPremiumId;
  late int unitLitreId;

  setUp(() async {
    AppDatabase.resetForTesting();
    // Use in-memory DB.
    db = await AppDatabase.open(overridePath: inMemoryDatabasePath);
    materialRepo = MaterialRepo(db);
    expenseRepo = ExpenseRepo(db);

    matDieselId = await materialRepo.createMaterial('Diesel');
    qualPremiumId = await materialRepo.createQuality(matDieselId, 'Premium');
    unitLitreId = await materialRepo.createUnit(matDieselId, 'Litre');
  });

  tearDown(() async {
    await db.close();
  });

  Expense baseExpense({
    int? id,
    String person = 'Alice',
    String? note,
    int? qualityId,
    int? unitId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Expense(
      id: id,
      materialId: matDieselId,
      qualityId: qualityId ?? qualPremiumId,
      unitId: unitId ?? unitLitreId,
      cost: 5000.0,
      quantity: 50.0,
      date: '2026-05-12',
      note: note,
      personName: person,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('no duplicates on empty DB', () async {
    final dups = await expenseRepo.findDuplicates(baseExpense());
    expect(dups, isEmpty);
  });

  test('duplicate found when all fields match except person name', () async {
    await expenseRepo.insert(baseExpense(person: 'Alice'));
    final dups = await expenseRepo.findDuplicates(baseExpense(person: 'Bob'));
    expect(dups, hasLength(1));
    expect(dups.first.personName, equals('Alice'));
  });

  test('different cost is not a duplicate', () async {
    await expenseRepo.insert(baseExpense());
    final candidate = baseExpense().copyWith(cost: 5001.0);
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, isEmpty);
  });

  test('different date is not a duplicate', () async {
    await expenseRepo.insert(baseExpense());
    final candidate = baseExpense().copyWith(date: '2026-05-13');
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, isEmpty);
  });

  test('null quality matches null quality', () async {
    final e = baseExpense().copyWith(clearQualityId: true);
    await expenseRepo.insert(e);
    final dups = await expenseRepo.findDuplicates(e);
    expect(dups, hasLength(1));
  });

  test('null quality does NOT match non-null quality', () async {
    await expenseRepo.insert(baseExpense().copyWith(clearQualityId: true));
    final candidate = baseExpense(); // has qualityId
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, isEmpty);
  });

  test('note case and whitespace are ignored', () async {
    await expenseRepo.insert(baseExpense(note: '  Refuel    '));
    final candidate = baseExpense(note: 'refuel');
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, hasLength(1));
  });

  test('empty/null/whitespace notes are equivalent', () async {
    await expenseRepo.insert(baseExpense(note: null));
    final dups = await expenseRepo.findDuplicates(baseExpense(note: '   '));
    expect(dups, hasLength(1));
  });

  test('different note text is NOT a duplicate', () async {
    await expenseRepo.insert(baseExpense(note: 'refuel'));
    final dups = await expenseRepo.findDuplicates(baseExpense(note: 'cash'));
    expect(dups, isEmpty);
  });

  test('excludeId hides self when editing', () async {
    final id = await expenseRepo.insert(baseExpense());
    final me = (await expenseRepo.findById(id))!;
    final dups = await expenseRepo.findDuplicates(me, excludeId: id);
    expect(dups, isEmpty);
  });

  test('excludeId still detects other matching rows when editing', () async {
    await expenseRepo.insert(baseExpense(person: 'Carol'));
    final id = await expenseRepo.insert(baseExpense(person: 'Alice'));
    final me = (await expenseRepo.findById(id))!;
    final dups = await expenseRepo.findDuplicates(me, excludeId: id);
    expect(dups, hasLength(1));
    expect(dups.first.personName, equals('Carol'));
  });

  test('search by material returns only matching rows', () async {
    final wood = await materialRepo.createMaterial('Wood');
    await expenseRepo.insert(baseExpense());
    await expenseRepo.insert(baseExpense().copyWith(
      materialId: wood,
      clearQualityId: true,
      clearUnitId: true,
    ));
    final results = await expenseRepo.search(
      ExpenseFilter(materialIds: [matDieselId]),
    );
    expect(results, hasLength(1));
    expect(results.first.materialName, equals('Diesel'));
  });

  test('search by date range', () async {
    await expenseRepo.insert(baseExpense().copyWith(date: '2026-05-01'));
    await expenseRepo.insert(baseExpense().copyWith(date: '2026-05-15'));
    await expenseRepo.insert(baseExpense().copyWith(date: '2026-06-01'));
    final results = await expenseRepo.search(
      const ExpenseFilter(dateFrom: '2026-05-10', dateTo: '2026-05-31'),
    );
    expect(results, hasLength(1));
    expect(results.first.expense.date, equals('2026-05-15'));
  });

  test('search by cost range', () async {
    await expenseRepo.insert(baseExpense().copyWith(cost: 100));
    await expenseRepo.insert(baseExpense().copyWith(cost: 500));
    await expenseRepo.insert(baseExpense().copyWith(cost: 1000));
    final results = await expenseRepo
        .search(const ExpenseFilter(minCost: 200, maxCost: 800));
    expect(results, hasLength(1));
    expect(results.first.expense.cost, equals(500));
  });

  test('wipeAll empties everything and FKs still work after', () async {
    await expenseRepo.insert(baseExpense());
    expect((await expenseRepo.listAll()), hasLength(1));
    await db.wipeAll();
    expect((await expenseRepo.listAll()), isEmpty);
    expect((await materialRepo.listMaterials()), isEmpty);
    // Re-insert flow still works after wipe.
    final m = await materialRepo.createMaterial('Diesel');
    expect(m, greaterThan(0));
  });

  test('expenseCountForMaterial is accurate', () async {
    await expenseRepo.insert(baseExpense());
    await expenseRepo.insert(baseExpense().copyWith(cost: 200));
    final cnt = await materialRepo.expenseCountForMaterial(matDieselId);
    expect(cnt, equals(2));
  });
}
