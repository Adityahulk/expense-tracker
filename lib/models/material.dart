class MaterialItem {
  final int? id;
  final String name;
  final int createdAt;

  const MaterialItem({
    this.id,
    required this.name,
    required this.createdAt,
  });

  MaterialItem copyWith({int? id, String? name, int? createdAt}) =>
      MaterialItem(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt,
      };

  factory MaterialItem.fromMap(Map<String, Object?> m) => MaterialItem(
        id: m['id'] as int?,
        name: m['name'] as String,
        createdAt: m['created_at'] as int,
      );
}
