import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../providers/providers.dart';
import '../services/backup_service.dart';
import '../widgets/error_snack.dart';
import 'material_detail_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionTitle('Materials'),
          materialsAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'No materials yet. Tap "Add material" below to create one.',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in list)
                    ListTile(
                      title: Text(m.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaterialDetailScreen(material: m),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $e'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add material'),
                onPressed: () => _addMaterial(context, ref),
              ),
            ),
          ),
          const Divider(),
          const _SectionTitle('Danger zone'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'A full backup (Excel + database copy) is automatically written to Downloads before any data is deleted.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete ALL data'),
                onPressed: () => _wipeEverything(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMaterial(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add material'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'e.g. Diesel, Labour, Machine'),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
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
    if (name == null) return;
    try {
      await ref.read(materialRepoProvider).createMaterial(name);
      notifyDataChanged(ref);
    } catch (e) {
      if (context.mounted) {
        showError(context, 'Could not add material: $e');
      }
    }
  }

  Future<void> _wipeEverything(BuildContext context, WidgetRef ref) async {
    // 1. Type DELETE confirm
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final ok = ctrl.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            title: const Text('Delete ALL data?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'A full backup will first be written to Downloads. After that, every expense, material, quality, and unit is permanently erased.'),
                const SizedBox(height: 12),
                const Text('Type DELETE to confirm:'),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ok ? Colors.red.shade700 : Colors.grey,
                ),
                onPressed: ok ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Delete everything'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    // 2. Run backup + wipe.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final db = ref.read(databaseProvider);
      final svc = BackupService(
        db: db,
        materialRepo: ref.read(materialRepoProvider),
        expenseRepo: ref.read(expenseRepoProvider),
      );
      final result = await svc.createFullBackup();
      await db.wipeAll();
      notifyDataChanged(ref);
      if (context.mounted) Navigator.pop(context); // close progress
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('All data deleted'),
            content: Text(
                'Backup saved to:\n${result.backupDirPath}\n\nExcel: ${result.excelPath.split('/').last}\nDB copy: ${result.dbCopyPath.split('/').last}'),
            actions: [
              TextButton(
                onPressed: () async {
                  await OpenFilex.open(result.excelPath);
                },
                child: const Text('Open Excel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close progress
        showError(context, 'Wipe failed: $e');
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}
