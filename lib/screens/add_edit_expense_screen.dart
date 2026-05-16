import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../models/material.dart';
import '../models/route_endpoint.dart';
import '../providers/providers.dart';
import '../widgets/autocomplete_field.dart';
import '../widgets/error_snack.dart';
import '../widgets/from_to_picker.dart';

class AddEditExpenseScreen extends ConsumerStatefulWidget {
  const AddEditExpenseScreen({super.key, this.existing});

  /// If non-null, we're editing this expense.
  final Expense? existing;

  @override
  ConsumerState<AddEditExpenseScreen> createState() =>
      _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends ConsumerState<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _costCtrl = TextEditingController();
  final _costPerUnitCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _personCtrl = TextEditingController();

  int? _materialId;
  int? _qualityId;
  int? _unitId;
  DateTime _date = DateTime.now();
  RouteEndpoint _from = const RouteEndpoint.empty();
  RouteEndpoint _to = const RouteEndpoint.empty();
  bool _saving = false;
  bool _updatingCalculatedCost = false;
  _CostInputSource _lastCostInputSource = _CostInputSource.totalCost;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _materialId = ex.materialId;
      _qualityId = ex.qualityId;
      _unitId = ex.unitId;
      _costCtrl.text = _trimZero(ex.cost);
      _qtyCtrl.text = _trimZero(ex.quantity);
      if (ex.quantity != 0) {
        _costPerUnitCtrl.text = _formatCalculatedNumber(ex.cost / ex.quantity);
      }
      _noteCtrl.text = ex.note ?? '';
      _personCtrl.text = ex.personName;
      _from = ex.fromEndpoint;
      _to = ex.toEndpoint;
      _date = DateTime.parse(ex.date);
    }
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    _costPerUnitCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  static String _trimZero(double v) {
    final s = v.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String _formatCalculatedNumber(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit expense' : 'Add expense'),
      ),
      body: materialsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading materials: $e')),
        data: (materials) {
          if (materials.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No materials defined yet. Open Settings and add at least one material (e.g. Diesel) before adding expenses.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back')),
                ],
              ),
            );
          }
          return _buildForm(materials);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(_saving
                ? 'Saving...'
                : (_isEditing ? 'Save changes' : 'Save expense')),
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }

  Widget _buildForm(List<MaterialItem> materials) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FromToPicker(
            label: 'From',
            icon: Icons.arrow_outward,
            value: _from,
            onChanged: (v) => setState(() => _from = v),
          ),
          const SizedBox(height: 16),
          FromToPicker(
            label: 'To',
            icon: Icons.arrow_downward,
            value: _to,
            onChanged: (v) => setState(() => _to = v),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            value: _materialId,
            decoration: const InputDecoration(
              labelText: 'Material *',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: [
              for (final m in materials)
                DropdownMenuItem(value: m.id, child: Text(m.name)),
            ],
            validator: (v) => v == null ? 'Pick a material' : null,
            onChanged: (v) {
              setState(() {
                _materialId = v;
                _qualityId = null;
                _unitId = null;
              });
            },
          ),
          const SizedBox(height: 12),
          if (_materialId != null)
            Consumer(builder: (ctx, ref, _) {
              final qAsync = ref.watch(qualitiesProvider(_materialId!));
              return qAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text('Error loading qualities: $e'),
                data: (qs) {
                  if (qs.isEmpty) return const SizedBox.shrink();
                  if (_qualityId != null &&
                      !qs.any((q) => q.id == _qualityId)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _qualityId = null);
                    });
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<int?>(
                      value: _qualityId,
                      decoration: const InputDecoration(
                        labelText: 'Quality (optional)',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('—')),
                        for (final q in qs)
                          DropdownMenuItem<int?>(
                              value: q.id, child: Text(q.name)),
                      ],
                      onChanged: (v) => setState(() => _qualityId = v),
                    ),
                  );
                },
              );
            }),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateNonNegativeNumber,
                  onChanged: (_) => _recalculateCosts(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _materialId == null
                    ? const SizedBox.shrink()
                    : Consumer(builder: (ctx, ref, _) {
                        final uAsync = ref.watch(unitsProvider(_materialId!));
                        return uAsync.when(
                          loading: () =>
                              const LinearProgressIndicator(minHeight: 2),
                          error: (e, _) => Text('Error: $e'),
                          data: (us) {
                            if (us.isEmpty) return const SizedBox.shrink();
                            if (_unitId != null &&
                                !us.any((u) => u.id == _unitId)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _unitId = null);
                              });
                            }
                            return DropdownButtonFormField<int?>(
                              value: _unitId,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                    value: null, child: Text('—')),
                                for (final u in us)
                                  DropdownMenuItem<int?>(
                                      value: u.id, child: Text(u.name)),
                              ],
                              onChanged: (v) => setState(() => _unitId = v),
                            );
                          },
                        );
                      }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _costPerUnitCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Cost per unit',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
            validator: _validateOptionalNonNegativeNumber,
            onChanged: (_) {
              _lastCostInputSource = _CostInputSource.costPerUnit;
              _recalculateCosts();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _costCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Cost *',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
            validator: _validateNonNegativeNumber,
            onChanged: (_) {
              _lastCostInputSource = _CostInputSource.totalCost;
              _recalculateCosts();
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date *',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          AutocompleteField(
            controller: _personCtrl,
            label: 'Spent by (optional)',
            hint: 'e.g. Ramesh / Acme Co.',
            suggestionsLoader: () =>
                ref.read(expenseRepoProvider).distinctPersonNames(),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String? _validateNonNegativeNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Not a number';
    if (parsed < 0) return 'Must be ≥ 0';
    return null;
  }

  String? _validateOptionalNonNegativeNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Not a number';
    if (parsed < 0) return 'Must be ≥ 0';
    return null;
  }

  void _recalculateCosts() {
    if (_updatingCalculatedCost) return;

    final quantity = double.tryParse(_qtyCtrl.text.trim());
    if (quantity == null || quantity == 0) return;

    _updatingCalculatedCost = true;
    try {
      switch (_lastCostInputSource) {
        case _CostInputSource.costPerUnit:
          final costPerUnit = double.tryParse(_costPerUnitCtrl.text.trim());
          if (costPerUnit == null) return;
          _costCtrl.text = _formatCalculatedNumber(quantity * costPerUnit);
          break;
        case _CostInputSource.totalCost:
          final cost = double.tryParse(_costCtrl.text.trim());
          if (cost == null) return;
          _costPerUnitCtrl.text = _formatCalculatedNumber(cost / quantity);
          break;
      }
    } finally {
      _updatingCalculatedCost = false;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _endpointError(RouteEndpoint e, String label) {
    if (e.kind == null) return '$label: pick a kind (Supplier, Site, or Plot).';
    switch (e.kind!) {
      case EndpointKind.supplier:
        if (e.supplierId == null) return '$label: pick a supplier.';
        break;
      case EndpointKind.site:
        if (e.siteId == null) return '$label: pick a site.';
        break;
      case EndpointKind.plot:
        if (e.siteId == null) return '$label: pick a site for the plot.';
        if (e.plotNumber == null) return '$label: enter a plot number.';
        break;
    }
    return null;
  }

  Future<void> _save() async {
    final fromErr = _endpointError(_from, 'From');
    if (fromErr != null) {
      showError(context, fromErr);
      return;
    }
    final toErr = _endpointError(_to, 'To');
    if (toErr != null) {
      showError(context, toErr);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final iso = DateFormat('yyyy-MM-dd').format(_date);
      final note = _noteCtrl.text.trim();
      final candidate = Expense.withRoutes(
        id: widget.existing?.id,
        materialId: _materialId!,
        qualityId: _qualityId,
        unitId: _unitId,
        cost: double.parse(_costCtrl.text.trim()),
        quantity: double.parse(_qtyCtrl.text.trim()),
        date: iso,
        note: note.isEmpty ? null : note,
        personName: _personCtrl.text.trim(),
        from: _from,
        to: _to,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      final repo = ref.read(expenseRepoProvider);
      final dups = await repo.findDuplicates(
        candidate,
        excludeId: widget.existing?.id,
      );

      bool proceed = true;
      if (dups.isNotEmpty) {
        if (!mounted) return;
        proceed = await _confirmDuplicate(dups.length) ?? false;
      }
      if (!proceed) {
        setState(() => _saving = false);
        return;
      }

      if (_isEditing) {
        await repo.update(candidate);
      } else {
        await repo.insert(candidate);
      }
      notifyDataChanged(ref);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, 'Save failed: $e');
      setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmDuplicate(int count) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate Entry'),
        content: Text(
          count == 1
              ? 'A matching expense already exists (same material, quality, quantity, unit, cost, date, note, From, and To — only the person name may differ). Do you want to continue?'
              : '$count matching expenses already exist (same material, quality, quantity, unit, cost, date, note, From, and To — only the person name may differ). Do you want to continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save anyway')),
        ],
      ),
    );
  }
}

enum _CostInputSource { costPerUnit, totalCost }
