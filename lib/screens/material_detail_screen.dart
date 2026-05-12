import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material.dart';
import '../models/quality.dart';
import '../models/unit.dart';
import '../providers/providers.dart';
import '../widgets/error_snack.dart';

class MaterialDetailScreen extends ConsumerWidget {
  const MaterialDetailScreen({super.key, required this.material});

  final MaterialItem material;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualitiesAsync = ref.watch(qualitiesProvider(material.id!));
    final unitsAsync = ref.watch(unitsProvider(material.id!));
    return Scaffold(
      appBar: AppBar(
        title: Text(material.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename material',
            onPressed: () => _renameMaterial(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete material',
            onPressed: () => _deleteMaterial(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: 'Qualities', onAdd: () => _addQuality(context, ref)),
          qualitiesAsync.when(
            data: (qs) => _QualityList(qualities: qs),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $e'),
            ),
          ),
          const Divider(),
          _SectionHeader(title: 'Units', onAdd: () => _addUnit(context, ref)),
          unitsAsync.when(
            data: (us) => _UnitList(units: us),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $e'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameMaterial(BuildContext context, WidgetRef ref) async {
    final newName = await _textInputDialog(
      context: context,
      title: 'Rename material',
      initial: material.name,
      label: 'Material name',
    );
    if (newName == null) return;
    try {
      await ref.read(materialRepoProvider).renameMaterial(material.id!, newName);
      notifyDataChanged(ref);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showError(context, 'Rename failed: $e');
    }
  }

  Future<void> _deleteMaterial(BuildContext context, WidgetRef ref) async {
    final count = await ref
        .read(materialRepoProvider)
        .expenseCountForMaterial(material.id!);
    if (!context.mounted) return;
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot delete'),
          content: Text(
              'There are $count expense(s) using this material. Delete those first, or rename the material.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${material.name}"?'),
        content: const Text(
            'This will also remove its qualities and units. No expenses use this material, so this is safe.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade100),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(materialRepoProvider).deleteMaterial(material.id!);
      notifyDataChanged(ref);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showError(context, 'Delete failed: $e');
    }
  }

  Future<void> _addQuality(BuildContext context, WidgetRef ref) async {
    final name = await _textInputDialog(
      context: context,
      title: 'Add quality',
      label: 'e.g. Premium, Heavy duty',
    );
    if (name == null) return;
    try {
      await ref.read(materialRepoProvider).createQuality(material.id!, name);
      notifyDataChanged(ref);
    } catch (e) {
      if (context.mounted) showError(context, 'Could not add: $e');
    }
  }

  Future<void> _addUnit(BuildContext context, WidgetRef ref) async {
    final name = await _textInputDialog(
      context: context,
      title: 'Add unit',
      label: 'e.g. Litre, Hour, Day',
    );
    if (name == null) return;
    try {
      await ref.read(materialRepoProvider).createUnit(material.id!, name);
      notifyDataChanged(ref);
    } catch (e) {
      if (context.mounted) showError(context, 'Could not add: $e');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
      );
}

class _QualityList extends ConsumerWidget {
  const _QualityList({required this.qualities});
  final List<Quality> qualities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (qualities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child:
            Text('No qualities yet.', style: TextStyle(color: Colors.black54)),
      );
    }
    return Column(
      children: [
        for (final q in qualities)
          ListTile(
            title: Text(q.name),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final newName = await _textInputDialog(
                    context: context,
                    title: 'Rename quality',
                    initial: q.name,
                    label: 'Quality name',
                  );
                  if (newName == null) return;
                  try {
                    await ref
                        .read(materialRepoProvider)
                        .renameQuality(q.id!, newName);
                    notifyDataChanged(ref);
                  } catch (e) {
                    if (context.mounted) showError(context, 'Rename failed: $e');
                  }
                } else if (v == 'delete') {
                  final count = await ref
                      .read(materialRepoProvider)
                      .expenseCountForQuality(q.id!);
                  if (!context.mounted) return;
                  if (count > 0) {
                    showError(context,
                        '$count expense(s) reference this quality; cannot delete.');
                    return;
                  }
                  await ref.read(materialRepoProvider).deleteQuality(q.id!);
                  notifyDataChanged(ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
      ],
    );
  }
}

class _UnitList extends ConsumerWidget {
  const _UnitList({required this.units});
  final List<UnitItem> units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (units.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text('No units yet.', style: TextStyle(color: Colors.black54)),
      );
    }
    return Column(
      children: [
        for (final u in units)
          ListTile(
            title: Text(u.name),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final newName = await _textInputDialog(
                    context: context,
                    title: 'Rename unit',
                    initial: u.name,
                    label: 'Unit name',
                  );
                  if (newName == null) return;
                  try {
                    await ref
                        .read(materialRepoProvider)
                        .renameUnit(u.id!, newName);
                    notifyDataChanged(ref);
                  } catch (e) {
                    if (context.mounted) showError(context, 'Rename failed: $e');
                  }
                } else if (v == 'delete') {
                  final count = await ref
                      .read(materialRepoProvider)
                      .expenseCountForUnit(u.id!);
                  if (!context.mounted) return;
                  if (count > 0) {
                    showError(context,
                        '$count expense(s) reference this unit; cannot delete.');
                    return;
                  }
                  await ref.read(materialRepoProvider).deleteUnit(u.id!);
                  notifyDataChanged(ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
      ],
    );
  }
}

Future<String?> _textInputDialog({
  required BuildContext context,
  required String title,
  required String label,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isEmpty) return;
            Navigator.pop(ctx, v);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
