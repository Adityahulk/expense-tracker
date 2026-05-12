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
    required this.createdAt,
    required this.updatedAt,
  });

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
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );
}

/// Convenience type for rows joined with master-data names — used in lists / Excel.
class ExpenseRow {
  final Expense expense;
  final String materialName;
  final String? qualityName;
  final String? unitName;

  const ExpenseRow({
    required this.expense,
    required this.materialName,
    this.qualityName,
    this.unitName,
  });
}
