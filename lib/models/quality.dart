class Quality {
  final int? id;
  final int materialId;
  final String name;

  const Quality({this.id, required this.materialId, required this.name});

  Quality copyWith({int? id, int? materialId, String? name}) => Quality(
        id: id ?? this.id,
        materialId: materialId ?? this.materialId,
        name: name ?? this.name,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'material_id': materialId,
        'name': name,
      };

  factory Quality.fromMap(Map<String, Object?> m) => Quality(
        id: m['id'] as int?,
        materialId: m['material_id'] as int,
        name: m['name'] as String,
      );
}
