import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/passcode_service.dart';

/// Locks the app at startup until the user enters a valid passcode (main or
/// decoy — both work, the screen doesn't reveal which is which).
class PasscodeLockScreen extends ConsumerStatefulWidget {
  const PasscodeLockScreen({super.key, required this.onUnlocked});

  /// Called after a successful unlock; the host installs the vault DB into
  /// the provider scope and navigates to Home.
  final void Function(UnlockResult result) onUnlocked;

  @override
  ConsumerState<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends ConsumerState<PasscodeLockScreen> {
  final _ctrl = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(passcodeServiceProvider)
          .tryUnlock(_ctrl.text);
      if (result == null) {
        setState(() {
          _error = 'Incorrect passcode';
          _checking = false;
        });
        _ctrl.clear();
        return;
      }
      widget.onUnlocked(result);
    } catch (e) {
      setState(() {
        _error = 'Unlock failed: $e';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Expense Tracker',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your passcode',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '••••',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_open),
                label: const Text('Unlock'),
                onPressed: _checking ? null : _submit,
              ),
              const Spacer(),
              const Text(
                'No passcode recovery. Keep yours safe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
