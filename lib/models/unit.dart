class UnitItem {
  final int? id;
  final int materialId;
  final String name;

  const UnitItem({this.id, required this.materialId, required this.name});

  UnitItem copyWith({int? id, int? materialId, String? name}) => UnitItem(
        id: id ?? this.id,
        materialId: materialId ?? this.materialId,
        name: name ?? this.name,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'material_id': materialId,
        'name': name,
      };

  factory UnitItem.fromMap(Map<String, Object?> m) => UnitItem(
        id: m['id'] as int?,
        materialId: m['material_id'] as int,
        name: m['name'] as String,
      );
}
