import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/site.dart';
import '../providers/providers.dart';
import '../repositories/site_repo.dart';
import '../widgets/error_snack.dart';

class SiteDetailScreen extends ConsumerStatefulWidget {
  const SiteDetailScreen({super.key, required this.site});

  final Site site;

  @override
  ConsumerState<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends ConsumerState<SiteDetailScreen> {
  late final TextEditingController _plotCountCtrl =
      TextEditingController(text: widget.site.plotCount.toString());
  bool _saving = false;

  @override
  void dispose() {
    _plotCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final newName = await _textInputDialog(
      context: context,
      title: 'Rename site',
      initial: widget.site.name,
      label: 'Site name',
    );
    if (newName == null) return;
    try {
      await ref.read(siteRepoProvider).renameSite(widget.site.id!, newName);
      notifyDataChanged(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, 'Rename failed: $e');
    }
  }

  Future<void> _saveCount() async {
    final newCount = int.tryParse(_plotCountCtrl.text.trim());
    if (newCount == null || newCount < 0) {
      showError(context, 'Plot count must be 0 or a positive number.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(siteRepoProvider).setPlotCount(widget.site.id!, newCount);
      notifyDataChanged(ref);
      if (mounted) {
        showInfo(context, 'Plot count updated.');
      }
    } on PlotCountTooLowException catch (e) {
      if (mounted) showError(context, e.toString());
    } catch (e) {
      if (mounted) showError(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final count =
        await ref.read(siteRepoProvider).expenseCountForSite(widget.site.id!);
    if (!mounted) return;
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot delete'),
          content: Text(
              '$count expense(s) reference this site. Remove those entries first.'),
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
        title: Text('Delete "${widget.site.name}"?'),
        content: const Text('No expenses use this site, so this is safe.'),
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
      await ref.read(siteRepoProvider).deleteSite(widget.site.id!);
      notifyDataChanged(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename site',
            onPressed: _rename,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete site',
            onPressed: _delete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plot count',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Plots are addressed by number 1..N. Set N to the highest plot number on this site.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _plotCountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Number of plots',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: _saving ? null : _saveCount,
                ),
              ],
            ),
          ],
        ),
      ),
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
