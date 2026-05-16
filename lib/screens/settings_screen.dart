import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../providers/providers.dart';
import '../services/backup_service.dart';
import '../services/file_save.dart';
import '../services/passcode_service.dart';
import '../widgets/error_snack.dart';
import 'change_passcode_screen.dart';
import 'material_detail_screen.dart';
import 'site_detail_screen.dart';
import 'supplier_detail_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _decoyConfigured;

  @override
  void initState() {
    super.initState();
    _refreshDecoyState();
  }

  Future<void> _refreshDecoyState() async {
    final has = await ref.read(passcodeServiceProvider).hasDecoyConfigured();
    if (mounted) setState(() => _decoyConfigured = has);
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialsProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final sitesAsync = ref.watch(sitesProvider);
    final role = ref.watch(activeVaultRoleProvider);
    final isMainVault = role == VaultRole.main;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ─── Materials ──────────────────────────────────────────────────
          const _SectionTitle('Materials'),
          materialsAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return const _EmptySection(
                    text: 'No materials yet. Tap "Add material" below.');
              }
              return Column(children: [
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
              ]);
            },
            loading: () => const _Loading(),
            error: (e, _) => _ErrorBlock(e),
          ),
          _AddButton(
            label: 'Add material',
            onPressed: () => _addEntity(
              context,
              title: 'Add material',
              hint: 'e.g. Diesel, Labour, Machine',
              save: (name) =>
                  ref.read(materialRepoProvider).createMaterial(name),
            ),
          ),

          const Divider(),
          // ─── Suppliers ──────────────────────────────────────────────────
          const _SectionTitle('Suppliers'),
          suppliersAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return const _EmptySection(
                    text: 'No suppliers yet. Tap "Add supplier" below.');
              }
              return Column(children: [
                for (final s in list)
                  ListTile(
                    title: Text(s.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplierDetailScreen(supplier: s),
                      ),
                    ),
                  ),
              ]);
            },
            loading: () => const _Loading(),
            error: (e, _) => _ErrorBlock(e),
          ),
          _AddButton(
            label: 'Add supplier',
            onPressed: () => _addEntity(
              context,
              title: 'Add supplier',
              hint: 'e.g. Acme Logistics',
              save: (name) =>
                  ref.read(supplierRepoProvider).createSupplier(name),
            ),
          ),

          const Divider(),
          // ─── Sites ──────────────────────────────────────────────────────
          const _SectionTitle('Sites'),
          sitesAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return const _EmptySection(
                    text: 'No sites yet. Tap "Add site" below.');
              }
              return Column(children: [
                for (final s in list)
                  ListTile(
                    title: Text(s.name),
                    subtitle: Text('${s.plotCount} plot(s)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiteDetailScreen(site: s),
                      ),
                    ),
                  ),
              ]);
            },
            loading: () => const _Loading(),
            error: (e, _) => _ErrorBlock(e),
          ),
          _AddButton(
            label: 'Add site',
            onPressed: () => _addSite(context),
          ),

          const Divider(),
          // ─── Security ───────────────────────────────────────────────────
          const _SectionTitle('Security'),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Change passcode'),
            onTap: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasscodeScreen(
                    title: 'Change passcode',
                    mode: ChangePasscodeMode.changeCurrent,
                  ),
                ),
              );
              if (ok == true && mounted) {
                showInfo(context, 'Passcode updated.');
              }
            },
          ),
          if (isMainVault)
            ExpansionTile(
              leading: const Icon(Icons.tune),
              title: const Text('Advanced'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                ListTile(
                  leading: Icon(_decoyConfigured == true
                      ? Icons.shield_outlined
                      : Icons.shield),
                  title: Text(_decoyConfigured == true
                      ? 'Change decoy passcode'
                      : 'Set decoy passcode'),
                  subtitle: const Text(
                      'A separate passcode that opens an alternate empty vault.'),
                  onTap: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangePasscodeScreen(
                          title: _decoyConfigured == true
                              ? 'Change decoy passcode'
                              : 'Set decoy passcode',
                          mode: _decoyConfigured == true
                              ? ChangePasscodeMode.changeCurrent
                              : ChangePasscodeMode.setDecoy,
                        ),
                      ),
                    );
                    if (ok == true) {
                      await _refreshDecoyState();
                      if (mounted) showInfo(context, 'Saved.');
                    }
                  },
                ),
              ],
            ),

          const Divider(),
          // ─── Danger zone ────────────────────────────────────────────────
          const _SectionTitle('Danger zone'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'A full backup (Excel + database copy, zipped) is built first. '
              'After you save it, the data in this vault is permanently erased.',
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
                onPressed: () => _wipeEverything(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add helpers ───────────────────────────────────────────────────────────

  Future<void> _addEntity(
    BuildContext context, {
    required String title,
    required String hint,
    required Future<int> Function(String) save,
  }) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: hint),
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
      await save(name);
      notifyDataChanged(ref);
    } catch (e) {
      if (mounted) showError(context, 'Could not add: $e');
    }
  }

  Future<void> _addSite(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final countCtrl = TextEditingController(text: '0');
    final result = await showDialog<({String name, int count})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add site'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Site name', hintText: 'e.g. Foo Site'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Number of plots',
                hintText: 'e.g. 200',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final count = int.tryParse(countCtrl.text.trim()) ?? -1;
              if (name.isEmpty || count < 0) return;
              Navigator.pop(ctx, (name: name, count: count));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref
          .read(siteRepoProvider)
          .createSite(result.name, plotCount: result.count);
      notifyDataChanged(ref);
    } catch (e) {
      if (mounted) showError(context, 'Could not add: $e');
    }
  }

  // ── Danger zone ───────────────────────────────────────────────────────────

  Future<void> _wipeEverything(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final ok = ctrl.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            title: const Text('Delete ALL data?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'You\'ll be asked where to save the backup .zip first. '
                    'After it saves, every expense and master entry in this vault '
                    'is permanently erased.'),
                const SizedBox(height: 12),
                const Text('Type DELETE to confirm:'),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setLocal(() {}),
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
                child: const Text('Continue'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

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
        supplierRepo: ref.read(supplierRepoProvider),
        siteRepo: ref.read(siteRepoProvider),
        expenseRepo: ref.read(expenseRepoProvider),
      );
      final bundle = await svc.buildFullBackupZip();
      if (!mounted) return;
      Navigator.pop(context); // close progress

      final saved = await FileSave.save(
        bytes: bundle.zipBytes,
        defaultFilename: bundle.suggestedFilename,
        dialogTitle: 'Save backup .zip',
      );
      if (saved == null) {
        if (mounted) showInfo(context, 'Cancelled. No data deleted.');
        return;
      }

      await db.wipeAll();
      notifyDataChanged(ref);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('All data deleted'),
          content: Text(
              'Backup saved as ${saved.filename}\n\n'
              '${bundle.totalExpenses} expense(s) were exported before deletion.'),
          actions: [
            if (!saved.isContentUri)
              TextButton(
                onPressed: () async {
                  await OpenFilex.open(saved.location);
                },
                child: const Text('Open backup'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close progress
        showError(context, 'Operation failed: $e');
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

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child:
            Text(text, style: const TextStyle(color: Colors.black54)),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock(this.e);
  final Object e;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e'),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(label),
            onPressed: onPressed,
          ),
        ),
      );
}
