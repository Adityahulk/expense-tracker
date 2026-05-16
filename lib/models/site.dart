class Site {
  final int? id;
  final String name;
  final int plotCount;
  final int createdAt;

  const Site({
    this.id,
    required this.name,
    required this.plotCount,
    required this.createdAt,
  });

  Site copyWith({int? id, String? name, int? plotCount, int? createdAt}) =>
      Site(
        id: id ?? this.id,
        name: name ?? this.name,
        plotCount: plotCount ?? this.plotCount,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'plot_count': plotCount,
        'created_at': createdAt,
      };

  factory Site.fromMap(Map<String, Object?> m) => Site(
        id: m['id'] as int?,
        name: m['name'] as String,
        plotCount: m['plot_count'] as int,
        createdAt: m['created_at'] as int,
      );
}
