import 'route_endpoint.dart';

class Expense {
  final int? id;
  final int materialId;
  final int? qualityId;
  final int? unitId;
  final double cost;
  final double quantity;
  final String date; // ISO yyyy-MM-dd
  final String? note;
  final String personName;

  // Structured route — From side.
  final EndpointKind fromKind;
  final int? fromSupplierId;
  final int? fromSiteId;
  final int? fromPlotNumber;

  // Structured route — To side.
  final EndpointKind toKind;
  final int? toSupplierId;
  final int? toSiteId;
  final int? toPlotNumber;

  final int createdAt;
  final int updatedAt;

  const Expense({
    this.id,
    required this.materialId,
    this.qualityId,
    this.unitId,
    required this.cost,
    required this.quantity,
    required this.date,
    this.note,
    required this.personName,
    required this.fromKind,
    this.fromSupplierId,
    this.fromSiteId,
    this.fromPlotNumber,
    required this.toKind,
    this.toSupplierId,
    this.toSiteId,
    this.toPlotNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Build an Expense from a [RouteEndpoint] for each side. Convenience for
  /// the form layer.
  factory Expense.withRoutes({
    int? id,
    required int materialId,
    int? qualityId,
    int? unitId,
    required double cost,
    required double quantity,
    required String date,
    String? note,
    required String personName,
    required RouteEndpoint from,
    required RouteEndpoint to,
    required int createdAt,
    required int updatedAt,
  }) {
    assert(from.isComplete, 'From endpoint must be complete');
    assert(to.isComplete, 'To endpoint must be complete');
    return Expense(
      id: id,
      materialId: materialId,
      qualityId: qualityId,
      unitId: unitId,
      cost: cost,
      quantity: quantity,
      date: date,
      note: note,
      personName: personName,
      fromKind: from.kind!,
      fromSupplierId: from.supplierId,
      fromSiteId: from.siteId,
      fromPlotNumber: from.plotNumber,
      toKind: to.kind!,
      toSupplierId: to.supplierId,
      toSiteId: to.siteId,
      toPlotNumber: to.plotNumber,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  RouteEndpoint get fromEndpoint => RouteEndpoint(
        kind: fromKind,
        supplierId: fromSupplierId,
        siteId: fromSiteId,
        plotNumber: fromPlotNumber,
      );

  RouteEndpoint get toEndpoint => RouteEndpoint(
        kind: toKind,
        supplierId: toSupplierId,
        siteId: toSiteId,
        plotNumber: toPlotNumber,
      );

  Expense copyWith({
    int? id,
    int? materialId,
    int? qualityId,
    int? unitId,
    double? cost,
    double? quantity,
    String? date,
    String? note,
    String? personName,
    EndpointKind? fromKind,
    int? fromSupplierId,
    int? fromSiteId,
    int? fromPlotNumber,
    EndpointKind? toKind,
    int? toSupplierId,
    int? toSiteId,
    int? toPlotNumber,
    int? createdAt,
    int? updatedAt,
    bool clearQualityId = false,
    bool clearUnitId = false,
    bool clearNote = false,
  }) =>
      Expense(
        id: id ?? this.id,
        materialId: materialId ?? this.materialId,
        qualityId: clearQualityId ? null : (qualityId ?? this.qualityId),
        unitId: clearUnitId ? null : (unitId ?? this.unitId),
        cost: cost ?? this.cost,
        quantity: quantity ?? this.quantity,
        date: date ?? this.date,
        note: clearNote ? null : (note ?? this.note),
        personName: personName ?? this.personName,
        fromKind: fromKind ?? this.fromKind,
        fromSupplierId: fromSupplierId ?? this.fromSupplierId,
        fromSiteId: fromSiteId ?? this.fromSiteId,
        fromPlotNumber: fromPlotNumber ?? this.fromPlotNumber,
        toKind: toKind ?? this.toKind,
        toSupplierId: toSupplierId ?? this.toSupplierId,
        toSiteId: toSiteId ?? this.toSiteId,
        toPlotNumber: toPlotNumber ?? this.toPlotNumber,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'material_id': materialId,
        'quality_id': qualityId,
        'unit_id': unitId,
        'cost': cost,
        'quantity': quantity,
        'date': date,
        'note': note,
        'person_name': personName,
        'from_kind': RouteEndpoint.kindToString(fromKind),
        'from_supplier_id': fromSupplierId,
        'from_site_id': fromSiteId,
        'from_plot_number': fromPlotNumber,
        'to_kind': RouteEndpoint.kindToString(toKind),
        'to_supplier_id': toSupplierId,
        'to_site_id': toSiteId,
        'to_plot_number': toPlotNumber,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        materialId: m['material_id'] as int,
        qualityId: m['quality_id'] as int?,
        unitId: m['unit_id'] as int?,
        cost: (m['cost'] as num).toDouble(),
        quantity: (m['quantity'] as num).toDouble(),
        date: m['date'] as String,
        note: m['note'] as String?,
        personName: m['person_name'] as String,
        fromKind: RouteEndpoint.kindFromString(m['from_kind'] as String?)!,
        fromSupplierId: m['from_supplier_id'] as int?,
        fromSiteId: m['from_site_id'] as int?,
        fromPlotNumber: m['from_plot_number'] as int?,
        toKind: RouteEndpoint.kindFromString(m['to_kind'] as String?)!,
        toSupplierId: m['to_supplier_id'] as int?,
        toSiteId: m['to_site_id'] as int?,
        toPlotNumber: m['to_plot_number'] as int?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
}

/// Row joined with master-data display strings (suppliers, sites). Used for
/// the home list, search results, and Excel rows.
class ExpenseRow {
  final Expense expense;
  final String materialName;
  final String? qualityName;
  final String? unitName;
  final String? fromSupplierName;
  final String? fromSiteName;
  final String? toSupplierName;
  final String? toSiteName;

  const ExpenseRow({
    required this.expense,
    required this.materialName,
    this.qualityName,
    this.unitName,
    this.fromSupplierName,
    this.fromSiteName,
    this.toSupplierName,
    this.toSiteName,
  });

  String fromDisplay() => expense.fromEndpoint
      .display(supplierName: fromSupplierName, siteName: fromSiteName);
  String toDisplay() => expense.toEndpoint
      .display(supplierName: toSupplierName, siteName: toSiteName);
}
