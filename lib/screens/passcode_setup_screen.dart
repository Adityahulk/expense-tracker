import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/passcode_service.dart';
import '../widgets/error_snack.dart';

/// First-launch screen: set up the main passcode.
class PasscodeSetupScreen extends ConsumerStatefulWidget {
  const PasscodeSetupScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<PasscodeSetupScreen> createState() =>
      _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends ConsumerState<PasscodeSetupScreen> {
  final _firstCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(passcodeServiceProvider).setupMain(_firstCtrl.text);
      widget.onComplete();
    } on PasscodeException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (e) {
      if (mounted) showError(context, 'Setup failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up passcode')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Icon(Icons.lock_outline,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Create a passcode to lock the app.\n'
                'You\'ll be asked for it every time you open Expense Tracker.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _firstCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passcode (4–16 digits)',
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
                    (v ?? '') == _firstCtrl.text ? null : 'Does not match',
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
                label: const Text('Create passcode'),
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
