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
  late SiteRepo siteRepo;
  late MaterialRepo materialRepo;
  late SupplierRepo supplierRepo;
  late ExpenseRepo expenseRepo;
  late int matId;
  late int unitId;
  late int qualityId;

  setUp(() async {
    AppDatabase.resetForTesting();
    db = await AppDatabase.open(overridePath: inMemoryDatabasePath);
    siteRepo = SiteRepo(db);
    materialRepo = MaterialRepo(db);
    supplierRepo = SupplierRepo(db);
    expenseRepo = ExpenseRepo(db);
    matId = await materialRepo.createMaterial('Diesel');
    qualityId = await materialRepo.createQuality(matId, 'Premium');
    unitId = await materialRepo.createUnit(matId, 'Litre');
  });

  tearDown(() async {
    await db.close();
  });

  test('createSite stores name and plot count', () async {
    final id = await siteRepo.createSite('Foo', plotCount: 200);
    final s = await siteRepo.findSite(id);
    expect(s, isNotNull);
    expect(s!.name, equals('Foo'));
    expect(s.plotCount, equals(200));
  });

  test('setPlotCount succeeds when no expenses block it', () async {
    final id = await siteRepo.createSite('Foo', plotCount: 200);
    await siteRepo.setPlotCount(id, 100);
    final s = await siteRepo.findSite(id);
    expect(s!.plotCount, equals(100));
  });

  test('setPlotCount rejects reduction below max used plot number', () async {
    final siteId = await siteRepo.createSite('Foo', plotCount: 200);
    final supplierId = await supplierRepo.createSupplier('Acme');
    final now = DateTime.now().millisecondsSinceEpoch;
    await expenseRepo.insert(Expense.withRoutes(
      materialId: matId,
      qualityId: qualityId,
      unitId: unitId,
      cost: 100.0,
      quantity: 1.0,
      date: '2026-05-12',
      personName: '',
      from: RouteEndpoint(kind: EndpointKind.supplier, supplierId: supplierId),
      to: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteId, plotNumber: 75),
      createdAt: now,
      updatedAt: now,
    ));
    expect(() => siteRepo.setPlotCount(siteId, 50),
        throwsA(isA<PlotCountTooLowException>()));
    final s = await siteRepo.findSite(siteId);
    expect(s!.plotCount, equals(200)); // unchanged
  });

  test('expenseCountForSite counts both From and To references', () async {
    final siteId = await siteRepo.createSite('Foo', plotCount: 200);
    final supplierId = await supplierRepo.createSupplier('Acme');
    final now = DateTime.now().millisecondsSinceEpoch;
    // From references the site.
    await expenseRepo.insert(Expense.withRoutes(
      materialId: matId,
      qualityId: qualityId,
      unitId: unitId,
      cost: 100.0,
      quantity: 1.0,
      date: '2026-05-12',
      personName: '',
      from: RouteEndpoint(kind: EndpointKind.site, siteId: siteId),
      to: RouteEndpoint(kind: EndpointKind.supplier, supplierId: supplierId),
      createdAt: now,
      updatedAt: now,
    ));
    // To references the site as a plot.
    await expenseRepo.insert(Expense.withRoutes(
      materialId: matId,
      qualityId: qualityId,
      unitId: unitId,
      cost: 100.0,
      quantity: 1.0,
      date: '2026-05-13',
      personName: '',
      from: RouteEndpoint(kind: EndpointKind.supplier, supplierId: supplierId),
      to: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteId, plotNumber: 5),
      createdAt: now,
      updatedAt: now,
    ));
    expect(await siteRepo.expenseCountForSite(siteId), equals(2));
  });

  test('maxUsedPlotNumber returns highest across both sides', () async {
    final siteId = await siteRepo.createSite('Foo', plotCount: 200);
    final supplierId = await supplierRepo.createSupplier('Acme');
    final now = DateTime.now().millisecondsSinceEpoch;
    await expenseRepo.insert(Expense.withRoutes(
      materialId: matId,
      qualityId: qualityId,
      unitId: unitId,
      cost: 100.0,
      quantity: 1.0,
      date: '2026-05-12',
      personName: '',
      from: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteId, plotNumber: 7),
      to: RouteEndpoint(kind: EndpointKind.supplier, supplierId: supplierId),
      createdAt: now,
      updatedAt: now,
    ));
    await expenseRepo.insert(Expense.withRoutes(
      materialId: matId,
      qualityId: qualityId,
      unitId: unitId,
      cost: 100.0,
      quantity: 1.0,
      date: '2026-05-13',
      personName: '',
      from: RouteEndpoint(kind: EndpointKind.supplier, supplierId: supplierId),
      to: RouteEndpoint(
          kind: EndpointKind.plot, siteId: siteId, plotNumber: 150),
      createdAt: now,
      updatedAt: now,
    ));
    expect(await siteRepo.maxUsedPlotNumber(siteId), equals(150));
  });

  test('maxUsedPlotNumber returns null when no plot references', () async {
    final siteId = await siteRepo.createSite('Foo', plotCount: 200);
    expect(await siteRepo.maxUsedPlotNumber(siteId), isNull);
  });

  test('deleteSite blocked is handled by detail screen, but repo allows when no refs', () async {
    final siteId = await siteRepo.createSite('Foo', plotCount: 200);
    expect(await siteRepo.expenseCountForSite(siteId), equals(0));
    await siteRepo.deleteSite(siteId);
    expect(await siteRepo.findSite(siteId), isNull);
  });
}
