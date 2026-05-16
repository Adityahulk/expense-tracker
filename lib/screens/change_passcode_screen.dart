import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/passcode_service.dart';
import '../widgets/error_snack.dart';

/// Two purposes:
///   1. "Change passcode" — changes the CURRENT vault's passcode.
///   2. "Set decoy passcode" — creates the second vault's passcode (only
///      reachable from the main vault).
class ChangePasscodeScreen extends ConsumerStatefulWidget {
  const ChangePasscodeScreen({
    super.key,
    required this.title,
    required this.mode,
  });

  final String title;
  final ChangePasscodeMode mode;

  @override
  ConsumerState<ChangePasscodeScreen> createState() =>
      _ChangePasscodeScreenState();
}

enum ChangePasscodeMode { changeCurrent, setDecoy }

class _ChangePasscodeScreenState extends ConsumerState<ChangePasscodeScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(passcodeServiceProvider);
      if (widget.mode == ChangePasscodeMode.setDecoy) {
        await svc.setupDecoy(_newCtrl.text);
      } else {
        // Determine vault name from the currently-mounted DB.
        final db = ref.read(databaseProvider);
        await svc.changePasscode(
          vaultName: db.vaultName,
          newPasscode: _newCtrl.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on PasscodeException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (e) {
      if (mounted) showError(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _newCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New passcode (4–16 digits)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 4) return 'At least 4 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm passcode',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '') == _newCtrl.text ? null : 'Does not match',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: const Text('Save'),
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
