import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/supplier.dart';
import '../providers/providers.dart';
import '../widgets/error_snack.dart';

class SupplierDetailScreen extends ConsumerWidget {
  const SupplierDetailScreen({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename supplier',
            onPressed: () => _rename(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete supplier',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(supplier.name,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              'Use Rename or Delete from the actions above. Suppliers can be selected as From or To when adding an expense.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final newName = await _textInputDialog(
      context: context,
      title: 'Rename supplier',
      initial: supplier.name,
      label: 'Supplier name',
    );
    if (newName == null) return;
    try {
      await ref
          .read(supplierRepoProvider)
          .renameSupplier(supplier.id!, newName);
      notifyDataChanged(ref);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showError(context, 'Rename failed: $e');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final count = await ref
        .read(supplierRepoProvider)
        .expenseCountForSupplier(supplier.id!);
    if (!context.mounted) return;
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot delete'),
          content: Text(
              '$count expense(s) reference this supplier. Remove those entries first.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${supplier.name}"?'),
        content: const Text('No expenses use this supplier, so this is safe.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade100),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(supplierRepoProvider).deleteSupplier(supplier.id!);
      notifyDataChanged(ref);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showError(context, 'Delete failed: $e');
    }
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
