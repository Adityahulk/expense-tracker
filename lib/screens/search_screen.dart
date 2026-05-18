import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../models/expense.dart';
import '../models/material.dart';
import '../models/quality.dart';
import '../models/site.dart';
import '../models/supplier.dart';
import '../providers/providers.dart';
import '../repositories/expense_repo.dart';
import '../services/excel_export_service.dart';
import '../services/file_save.dart';
import '../widgets/error_snack.dart';
import '../widgets/expense_tile.dart';
import 'add_edit_expense_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final Set<int> _materialIds = {};
  final Set<int> _qualityIds = {};
  final Set<int> _supplierIds = {};
  final Set<int> _siteIds = {};
  DateTime? _from;
  DateTime? _to;
  final _minCostCtrl = TextEditingController();
  final _maxCostCtrl = TextEditingController();
  final _plotCtrl = TextEditingController();

  List<ExpenseRow>? _results;
  bool _running = false;
  bool _exporting = false;

  @override
  void dispose() {
    _minCostCtrl.dispose();
    _maxCostCtrl.dispose();
    _plotCtrl.dispose();
    super.dispose();
  }

  ExpenseFilter _buildFilter() => ExpenseFilter(
        materialIds: _materialIds.toList(),
        qualityIds: _qualityIds.toList(),
        supplierIds: _supplierIds.toList(),
        siteIds: _siteIds.toList(),
        plotNumber: int.tryParse(_plotCtrl.text.trim()),
        dateFrom: _from == null ? null : DateFormat('yyyy-MM-dd').format(_from!),
        dateTo: _to == null ? null : DateFormat('yyyy-MM-dd').format(_to!),
        minCost: double.tryParse(_minCostCtrl.text.trim()),
        maxCost: double.tryParse(_maxCostCtrl.text.trim()),
      );

  Future<void> _runSearch() async {
    setState(() => _running = true);
    try {
      final rows = await ref.read(expenseRepoProvider).search(_buildFilter());
      setState(() => _results = rows);
    } catch (e) {
      if (mounted) showError(context, 'Search failed: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _export() async {
    final results = _results;
    if (results == null || results.isEmpty) {
      showInfo(context, 'No rows to export. Run a search first.');
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = ExcelExportService().buildExpensesXlsx(results);
      final saved = await FileSave.save(
        bytes: bytes,
        defaultFilename: defaultExpensesFilename(),
        dialogTitle: 'Save expenses Excel',
      );
      if (!mounted) return;
      if (saved == null) {
        showInfo(context, 'Export cancelled.');
        return;
      }
      showInfo(
        context,
        'Saved ${saved.filename}',
        action: saved.isContentUri
            ? null
            : SnackBarAction(
                label: 'Open',
                onPressed: () => OpenFilex.open(saved.location),
              ),
        duration: const Duration(seconds: 8),
      );
    } catch (e) {
      if (mounted) showError(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialsProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final sitesAsync = ref.watch(sitesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search / Filter'),
        actions: [
          IconButton(
            tooltip: 'Export to Excel',
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download_outlined),
            onPressed: _exporting ? null : _export,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              children: [
                _sectionLabel('Materials'),
                materialsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (mats) => _materialChips(mats),
                ),
                const SizedBox(height: 12),
                if (_materialIds.isNotEmpty) ...[
                  _sectionLabel('Qualities'),
                  _QualityFilter(
                    materialIds: _materialIds.toList(),
                    selected: _qualityIds,
                    onChanged: (s) => setState(() {
                      _qualityIds
                        ..clear()
                        ..addAll(s);
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                _sectionLabel('Suppliers (matches From or To)'),
                suppliersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (list) => _supplierChips(list),
                ),
                const SizedBox(height: 12),
                _sectionLabel('Sites (matches From or To)'),
                sitesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (list) => _siteChips(list),
                ),
                const SizedBox(height: 12),
                _sectionLabel('Plot # (matches From or To)'),
                TextField(
                  controller: _plotCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Plot number',
                    hintText: 'e.g. 17',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                  onChanged: (_) {
                    // Live rerun? No — let user hit Search. Keep state.
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                _sectionLabel('Date range'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_from == null
                            ? 'From'
                            : DateFormat('d MMM yyyy').format(_from!)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _from ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _from = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_to == null
                            ? 'To'
                            : DateFormat('d MMM yyyy').format(_to!)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _to ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _to = d);
                        },
                      ),
                    ),
                    if (_from != null || _to != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear dates',
                        onPressed: () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionLabel('Cost range'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minCostCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maxCostCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: _running
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: const Text('Search'),
                        onPressed: _running ? null : _runSearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _materialIds.clear();
                        _qualityIds.clear();
                        _supplierIds.clear();
                        _siteIds.clear();
                        _from = null;
                        _to = null;
                        _minCostCtrl.clear();
                        _maxCostCtrl.clear();
                        _plotCtrl.clear();
                        _results = null;
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                if (_results != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Results: ${_results!.length}'
                      ' · Total: ₹${_results!.fold<double>(0, (a, r) => a + r.expense.cost).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                if (_results != null && _results!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('No matching expenses.',
                            style: TextStyle(color: Colors.black54))),
                  ),
                if (_results != null)
                  for (final r in _results!)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ExpenseTile(
                        row: r,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditExpenseScreen(existing: r.expense),
                            ),
                          );
                          await _runSearch();
                        },
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _materialChips(List<MaterialItem> mats) {
    if (mats.isEmpty) {
      return const Text('No materials defined.',
          style: TextStyle(color: Colors.black54));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final m in mats)
          FilterChip(
            label: Text(m.name),
            selected: _materialIds.contains(m.id),
            onSelected: (sel) => setState(() {
              if (sel) {
                _materialIds.add(m.id!);
              } else {
                _materialIds.remove(m.id!);
                _qualityIds.clear();
              }
            }),
          ),
      ],
    );
  }

  Widget _supplierChips(List<Supplier> list) {
    if (list.isEmpty) {
      return const Text('No suppliers defined.',
          style: TextStyle(color: Colors.black54));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final s in list)
          FilterChip(
            label: Text(s.name),
            selected: _supplierIds.contains(s.id),
            onSelected: (sel) => setState(() {
              if (sel) {
                _supplierIds.add(s.id!);
              } else {
                _supplierIds.remove(s.id!);
              }
            }),
          ),
      ],
    );
  }

  Widget _siteChips(List<Site> list) {
    if (list.isEmpty) {
      return const Text('No sites defined.',
          style: TextStyle(color: Colors.black54));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final s in list)
          FilterChip(
            label: Text(s.name),
            selected: _siteIds.contains(s.id),
            onSelected: (sel) => setState(() {
              if (sel) {
                _siteIds.add(s.id!);
              } else {
                _siteIds.remove(s.id!);
              }
            }),
          ),
      ],
    );
  }
}

class _QualityFilter extends ConsumerWidget {
  const _QualityFilter({
    required this.materialIds,
    required this.selected,
    required this.onChanged,
  });
  final List<int> materialIds;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final futures =
        materialIds.map((m) => ref.watch(qualitiesProvider(m).future));
    return FutureBuilder<List<List<Quality>>>(
      future: Future.wait(futures),
      builder: (ctx, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final all = snap.data!.expand((x) => x).toList();
        if (all.isEmpty) {
          return const Text('No qualities on selected materials.',
              style: TextStyle(color: Colors.black54));
        }
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final q in all)
              FilterChip(
                label: Text(q.name),
                selected: selected.contains(q.id),
                onSelected: (sel) {
                  final next = Set<int>.from(selected);
                  if (sel) {
                    next.add(q.id!);
                  } else {
                    next.remove(q.id!);
                  }
                  onChanged(next);
                },
              ),
          ],
        );
      },
    );
  }
}
