import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'screens/passcode_lock_screen.dart';
import 'screens/passcode_setup_screen.dart';
import 'services/passcode_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ExpenseTrackerApp()));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _AppGate(),
    );
  }
}

/// Top-level gate that decides what to render:
/// - First-run setup if no passcode is configured
/// - Passcode lock until unlocked
/// - HomeScreen once a vault DB is mounted into [activeDatabaseStateProvider]
class _AppGate extends ConsumerStatefulWidget {
  const _AppGate();

  @override
  ConsumerState<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<_AppGate> {
  bool? _isFirstRun;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _detectFirstRun();
  }

  Future<void> _detectFirstRun() async {
    try {
      final first = await ref.read(passcodeServiceProvider).isFirstRun();
      if (mounted) {
        setState(() {
          _isFirstRun = first;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFirstRun = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _onUnlocked(UnlockResult result) async {
    final db = await AppDatabase.open(vaultName: result.vaultName);
    if (!mounted) return;
    ref.read(activeDatabaseStateProvider.notifier).state = db;
    ref.read(activeVaultRoleProvider.notifier).state = result.role;
    setState(() {}); // rebuild gate
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_isFirstRun == true) {
      return PasscodeSetupScreen(
        onComplete: () {
          setState(() {
            _isFirstRun = false;
          });
        },
      );
    }
    final activeDb = ref.watch(activeDatabaseStateProvider);
    if (activeDb == null) {
      return PasscodeLockScreen(onUnlocked: _onUnlocked);
    }
    return const HomeScreen();
  }
}
