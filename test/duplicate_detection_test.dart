import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/route_endpoint.dart';
import 'package:expense_tracker/repositories/expense_repo.dart';
import 'package:expense_tracker/repositories/material_repo.dart';
import 'package:expense_tracker/repositories/site_repo.dart';
import 'package:expense_tracker/repositories/supplier_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late MaterialRepo materialRepo;
  late SupplierRepo supplierRepo;
  late SiteRepo siteRepo;
  late ExpenseRepo expenseRepo;
  late int matDieselId;
  late int qualPremiumId;
  late int unitLitreId;
  late int supplierAcmeId;
  late int supplierBetaId;
  late int siteFooId;
  late int siteBarId;

  setUp(() async {
    AppDatabase.resetForTesting();
    db = await AppDatabase.open(overridePath: inMemoryDatabasePath);
    materialRepo = MaterialRepo(db);
    supplierRepo = SupplierRepo(db);
    siteRepo = SiteRepo(db);
    expenseRepo = ExpenseRepo(db);

    matDieselId = await materialRepo.createMaterial('Diesel');
    qualPremiumId = await materialRepo.createQuality(matDieselId, 'Premium');
    unitLitreId = await materialRepo.createUnit(matDieselId, 'Litre');
    supplierAcmeId = await supplierRepo.createSupplier('Acme');
    supplierBetaId = await supplierRepo.createSupplier('Beta');
    siteFooId = await siteRepo.createSite('Foo', plotCount: 200);
    siteBarId = await siteRepo.createSite('Bar', plotCount: 50);
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
    RouteEndpoint? from,
    RouteEndpoint? to,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Expense.withRoutes(
      id: id,
      materialId: matDieselId,
      qualityId: qualityId ?? qualPremiumId,
      unitId: unitId ?? unitLitreId,
      cost: 5000.0,
      quantity: 50.0,
      date: '2026-05-12',
      note: note,
      personName: person,
      from: from ??
          RouteEndpoint(
              kind: EndpointKind.supplier, supplierId: supplierAcmeId),
      to: to ??
          RouteEndpoint(
              kind: EndpointKind.plot,
              siteId: siteFooId,
              plotNumber: 17),
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

  test('different From supplier is not a duplicate', () async {
    await expenseRepo.insert(baseExpense(
      from: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierAcmeId),
    ));
    final candidate = baseExpense(
      from: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierBetaId),
    );
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, isEmpty);
  });

  test('different From kind is not a duplicate', () async {
    await expenseRepo.insert(baseExpense(
      from: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierAcmeId),
    ));
    final candidate = baseExpense(
      from: RouteEndpoint(kind: EndpointKind.site, siteId: siteFooId),
    );
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, isEmpty);
  });

  test('same plot site, different plot number is not a duplicate', () async {
    await expenseRepo.insert(baseExpense(
      to: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteFooId, plotNumber: 17),
    ));
    final candidate = baseExpense(
      to: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteFooId, plotNumber: 18),
    );
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, isEmpty);
  });

  test('same plot kind, same site, same number IS a duplicate', () async {
    await expenseRepo.insert(baseExpense(
      to: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteFooId, plotNumber: 17),
    ));
    final candidate = baseExpense(
      to: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteFooId, plotNumber: 17),
    );
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, hasLength(1));
  });

  test('null quality matches null quality', () async {
    final e = baseExpense().copyWith(clearQualityId: true);
    await expenseRepo.insert(e);
    final dups = await expenseRepo.findDuplicates(e);
    expect(dups, hasLength(1));
  });

  test('note case and whitespace are ignored', () async {
    await expenseRepo.insert(baseExpense(note: '  Refuel    '));
    final candidate = baseExpense(note: 'refuel');
    final dups = await expenseRepo.findDuplicates(candidate);
    expect(dups, hasLength(1));
  });

  test('excludeId hides self when editing', () async {
    final id = await expenseRepo.insert(baseExpense());
    final me = (await expenseRepo.findById(id))!;
    final dups = await expenseRepo.findDuplicates(me, excludeId: id);
    expect(dups, isEmpty);
  });

  test('search by supplier matches either side', () async {
    await expenseRepo.insert(baseExpense()); // From=Acme, To=Plot Foo#17
    await expenseRepo.insert(baseExpense(
      from: RouteEndpoint(
          kind: EndpointKind.site, siteId: siteFooId),
      to: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierAcmeId),
    ));
    await expenseRepo.insert(baseExpense(
      from: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierBetaId),
      to: RouteEndpoint(
          kind: EndpointKind.site, siteId: siteBarId),
    ));
    final results = await expenseRepo
        .search(ExpenseFilter(supplierIds: [supplierAcmeId]));
    expect(results, hasLength(2));
  });

  test('search by plot number matches either side', () async {
    // Expense 1: From=Acme(supplier), To=Plot Foo#17
    await expenseRepo.insert(baseExpense());
    // Expense 2: From=Plot Foo#25, To=Beta(supplier) — no plot 17 anywhere
    await expenseRepo.insert(baseExpense(
      from: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteFooId, plotNumber: 25),
      to: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierBetaId),
    ));
    // Expense 3: From=Acme(supplier), To=Plot Bar#17 — different site, same plot #
    await expenseRepo.insert(baseExpense(
      to: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteBarId, plotNumber: 17),
    ));
    // Expense 4: no plot at all (both sides are suppliers)
    await expenseRepo.insert(baseExpense(
      from: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierBetaId),
      to: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierAcmeId),
    ));

    // plot 17 — matches expenses 1 and 3 (Plot Foo#17 and Plot Bar#17)
    final r17 = await expenseRepo.search(const ExpenseFilter(plotNumber: 17));
    expect(r17, hasLength(2));

    // plot 17 + site Foo — matches only expense 1
    final r17Foo = await expenseRepo.search(
      ExpenseFilter(plotNumber: 17, siteIds: [siteFooId]),
    );
    expect(r17Foo, hasLength(1));

    // plot 999 — none
    final r999 = await expenseRepo.search(const ExpenseFilter(plotNumber: 999));
    expect(r999, isEmpty);
  });

  test('search by site matches either side', () async {
    await expenseRepo.insert(baseExpense()); // To plot on Foo
    await expenseRepo.insert(baseExpense(
      from: RouteEndpoint(
          kind: EndpointKind.site, siteId: siteBarId),
      to: RouteEndpoint(
          kind: EndpointKind.supplier, supplierId: supplierAcmeId),
    ));
    final foo = await expenseRepo.search(ExpenseFilter(siteIds: [siteFooId]));
    expect(foo, hasLength(1));
    final bar = await expenseRepo.search(ExpenseFilter(siteIds: [siteBarId]));
    expect(bar, hasLength(1));
  });

  test('listRecent joins display names correctly', () async {
    await expenseRepo.insert(baseExpense());
    final rows = await expenseRepo.listRecent(limit: 10);
    expect(rows, hasLength(1));
    expect(rows.first.fromSupplierName, equals('Acme'));
    expect(rows.first.toSiteName, equals('Foo'));
    expect(rows.first.fromDisplay(), equals('Supplier: Acme'));
    expect(rows.first.toDisplay(), equals('Plot: Foo — #17'));
  });

  test('search by date range still works', () async {
    await expenseRepo.insert(baseExpense().copyWith(date: '2026-05-01'));
    await expenseRepo.insert(baseExpense().copyWith(date: '2026-05-15'));
    await expenseRepo.insert(baseExpense().copyWith(date: '2026-06-01'));
    final results = await expenseRepo.search(
      const ExpenseFilter(dateFrom: '2026-05-10', dateTo: '2026-05-31'),
    );
    expect(results, hasLength(1));
    expect(results.first.expense.date, equals('2026-05-15'));
  });

  test('wipeAll empties everything and FKs still work after', () async {
    await expenseRepo.insert(baseExpense());
    expect((await expenseRepo.listAll()), hasLength(1));
    await db.wipeAll();
    expect((await expenseRepo.listAll()), isEmpty);
    expect((await materialRepo.listMaterials()), isEmpty);
    expect((await supplierRepo.listSuppliers()), isEmpty);
    expect((await siteRepo.listSites()), isEmpty);
    final m = await materialRepo.createMaterial('Diesel');
    expect(m, greaterThan(0));
  });
}
