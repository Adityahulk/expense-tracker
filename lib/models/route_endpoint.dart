/// One end (From or To) of an expense's material flow.
/// Exactly one of the three kinds applies; the corresponding ID(s) are set.
enum EndpointKind { supplier, site, plot }

class RouteEndpoint {
  final EndpointKind? kind;
  final int? supplierId;
  final int? siteId;
  final int? plotNumber;

  const RouteEndpoint({
    this.kind,
    this.supplierId,
    this.siteId,
    this.plotNumber,
  });

  const RouteEndpoint.empty()
      : kind = null,
        supplierId = null,
        siteId = null,
        plotNumber = null;

  bool get isComplete {
    switch (kind) {
      case null:
        return false;
      case EndpointKind.supplier:
        return supplierId != null;
      case EndpointKind.site:
        return siteId != null;
      case EndpointKind.plot:
        return siteId != null && plotNumber != null;
    }
  }

  RouteEndpoint withKind(EndpointKind? newKind) {
    if (newKind == kind) return this;
    return RouteEndpoint(kind: newKind);
  }

  RouteEndpoint withSupplier(int? id) => RouteEndpoint(
        kind: EndpointKind.supplier,
        supplierId: id,
      );

  RouteEndpoint withSite(int? id) {
    // changing site clears plot number (since plot numbers are site-scoped)
    return RouteEndpoint(
      kind: kind,
      siteId: id,
      supplierId: null,
      plotNumber: kind == EndpointKind.plot ? null : null,
    );
  }

  RouteEndpoint withPlot({int? siteId, int? plotNumber}) => RouteEndpoint(
        kind: EndpointKind.plot,
        siteId: siteId ?? this.siteId,
        plotNumber: plotNumber,
      );

  static String kindToString(EndpointKind k) => switch (k) {
        EndpointKind.supplier => 'supplier',
        EndpointKind.site => 'site',
        EndpointKind.plot => 'plot',
      };

  static EndpointKind? kindFromString(String? s) => switch (s) {
        'supplier' => EndpointKind.supplier,
        'site' => EndpointKind.site,
        'plot' => EndpointKind.plot,
        _ => null,
      };

  /// Render a human label, e.g. "Supplier: Acme", "Site: Foo",
  /// "Plot: Foo — #17". [supplierName] / [siteName] are looked up by id.
  String display({
    required String? supplierName,
    required String? siteName,
  }) {
    switch (kind) {
      case null:
        return '—';
      case EndpointKind.supplier:
        return 'Supplier: ${supplierName ?? '(unknown)'}';
      case EndpointKind.site:
        return 'Site: ${siteName ?? '(unknown)'}';
      case EndpointKind.plot:
        return 'Plot: ${siteName ?? '(unknown)'} — #${plotNumber ?? '?'}';
    }
  }
}
