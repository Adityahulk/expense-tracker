class Supplier {
  final int? id;
  final String name;
  final int createdAt;

  const Supplier({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Supplier copyWith({int? id, String? name, int? createdAt}) => Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt,
      };

  factory Supplier.fromMap(Map<String, Object?> m) => Supplier(
        id: m['id'] as int?,
        name: m['name'] as String,
        createdAt: m['created_at'] as int,
      );
}
