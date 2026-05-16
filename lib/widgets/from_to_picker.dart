import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/route_endpoint.dart';
import '../models/site.dart';
import '../models/supplier.dart';
import '../providers/providers.dart';
import 'plot_number_field.dart';

/// One side (From or To) of an expense route. User chooses a kind chip
/// (Supplier / Site / Plot), then picks the relevant master-data row.
/// For Plot, a site dropdown appears first and a plot number field
/// appears once a site is chosen.
class FromToPicker extends ConsumerStatefulWidget {
  const FromToPicker({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final RouteEndpoint value;
  final ValueChanged<RouteEndpoint> onChanged;

  @override
  ConsumerState<FromToPicker> createState() => _FromToPickerState();
}

class _FromToPickerState extends ConsumerState<FromToPicker> {
  EndpointKind? get _kind => widget.value.kind;

  void _setKind(EndpointKind? newKind) {
    if (newKind == _kind) return;
    widget.onChanged(RouteEndpoint(kind: newKind));
  }

  void _pickSupplier(int? id) {
    widget.onChanged(RouteEndpoint(
      kind: EndpointKind.supplier,
      supplierId: id,
    ));
  }

  void _pickSiteForKindSite(int? id) {
    widget.onChanged(RouteEndpoint(
      kind: EndpointKind.site,
      siteId: id,
    ));
  }

  void _pickSiteForKindPlot(int? id) {
    widget.onChanged(RouteEndpoint(
      kind: EndpointKind.plot,
      siteId: id,
      plotNumber: null, // reset plot when site changes
    ));
  }

  void _pickPlot(int? plot) {
    widget.onChanged(RouteEndpoint(
      kind: EndpointKind.plot,
      siteId: widget.value.siteId,
      plotNumber: plot,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                '${widget.label} *',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Supplier'),
                selected: _kind == EndpointKind.supplier,
                onSelected: (_) => _setKind(EndpointKind.supplier),
              ),
              ChoiceChip(
                label: const Text('Site'),
                selected: _kind == EndpointKind.site,
                onSelected: (_) => _setKind(EndpointKind.site),
              ),
              ChoiceChip(
                label: const Text('Plot'),
                selected: _kind == EndpointKind.plot,
                onSelected: (_) => _setKind(EndpointKind.plot),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_kind == EndpointKind.supplier) _buildSupplierPicker(),
          if (_kind == EndpointKind.site) _buildSitePicker(forPlot: false),
          if (_kind == EndpointKind.plot) ...[
            _buildSitePicker(forPlot: true),
            const SizedBox(height: 12),
            _buildPlotPicker(),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplierPicker() {
    final asyncSuppliers = ref.watch(suppliersProvider);
    return asyncSuppliers.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No suppliers yet. Add one from Settings → Suppliers.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        // Clear stale selection if the supplier was deleted.
        if (widget.value.supplierId != null &&
            !list.any((s) => s.id == widget.value.supplierId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _pickSupplier(null);
          });
        }
        return DropdownButtonFormField<int?>(
          value: widget.value.supplierId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Supplier *',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Pick a supplier')),
            for (final s in list)
              DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
          ],
          validator: (v) => v == null ? 'Pick a supplier' : null,
          onChanged: _pickSupplier,
        );
      },
    );
  }

  Widget _buildSitePicker({required bool forPlot}) {
    final asyncSites = ref.watch(sitesProvider);
    return asyncSites.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No sites yet. Add one from Settings → Sites.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        // Clear stale selection if the site was deleted.
        if (widget.value.siteId != null &&
            !list.any((s) => s.id == widget.value.siteId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              forPlot
                  ? _pickSiteForKindPlot(null)
                  : _pickSiteForKindSite(null);
            }
          });
        }
        return DropdownButtonFormField<int?>(
          value: widget.value.siteId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Site *',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Pick a site')),
            for (final s in list)
              DropdownMenuItem<int?>(
                value: s.id,
                child: Text(forPlot
                    ? '${s.name} (${s.plotCount} plots)'
                    : s.name),
              ),
          ],
          validator: (v) => v == null ? 'Pick a site' : null,
          onChanged: forPlot ? _pickSiteForKindPlot : _pickSiteForKindSite,
        );
      },
    );
  }

  Widget _buildPlotPicker() {
    final siteId = widget.value.siteId;
    if (siteId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('Pick a site first to enter the plot number.',
            style: TextStyle(color: Colors.black54)),
      );
    }
    final asyncSites = ref.watch(sitesProvider);
    return asyncSites.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (list) {
        final site = list.firstWhere(
          (s) => s.id == siteId,
          orElse: () => const Site(
              id: -1, name: '', plotCount: 0, createdAt: 0),
        );
        if (site.id == -1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Selected site no longer exists.',
                style: TextStyle(color: Colors.red)),
          );
        }
        return PlotNumberField(
          plotCount: site.plotCount,
          value: widget.value.plotNumber,
          onChanged: _pickPlot,
        );
      },
    );
  }
}

/// Helper for callers wanting a starting "From" for a new expense.
RouteEndpoint emptyFromEndpoint(List<Supplier> _, List<Site> __) =>
    const RouteEndpoint.empty();
