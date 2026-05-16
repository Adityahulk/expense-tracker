import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/services/passcode_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Use the in-memory test backend that flutter_secure_storage provides for
  // tests. Available via `setMockInitialValues`.
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('isFirstRun is true on a clean install', () async {
    final svc = PasscodeService();
    expect(await svc.isFirstRun(), isTrue);
  });

  test('setupMain stores hash; isFirstRun becomes false', () async {
    final svc = PasscodeService();
    await svc.setupMain('1234');
    expect(await svc.isFirstRun(), isFalse);
  });

  test('tryUnlock returns vault A with role=main for the main passcode',
      () async {
    final svc = PasscodeService();
    await svc.setupMain('1234');
    final r = await svc.tryUnlock('1234');
    expect(r, isNotNull);
    expect(r!.vaultName, equals(kVaultA));
    expect(r.role, equals(VaultRole.main));
  });

  test('tryUnlock returns null for wrong passcode', () async {
    final svc = PasscodeService();
    await svc.setupMain('1234');
    expect(await svc.tryUnlock('9999'), isNull);
    expect(await svc.tryUnlock(''), isNull);
  });

  test('setupDecoy rejects duplicate of main passcode', () async {
    final svc = PasscodeService();
    await svc.setupMain('1234');
    expect(
      () => svc.setupDecoy('1234'),
      throwsA(isA<PasscodeException>()),
    );
  });

  test('setupDecoy then unlock returns vault B with role=decoy', () async {
    final svc = PasscodeService();
    await svc.setupMain('1234');
    await svc.setupDecoy('9876');
    final r = await svc.tryUnlock('9876');
    expect(r, isNotNull);
    expect(r!.vaultName, equals(kVaultB));
    expect(r.role, equals(VaultRole.decoy));
  });

  test('changePasscode updates only the targeted vault', () async {
    final svc = PasscodeService();
    await svc.setupMain('1234');
    await svc.setupDecoy('9876');
    await svc.changePasscode(vaultName: kVaultA, newPasscode: '1111');
    expect(await svc.tryUnlock('1111'), isNotNull);
    expect(await svc.tryUnlock('1234'), isNull);
    // Decoy unchanged.
    final decoy = await svc.tryUnlock('9876');
    expect(decoy?.role, equals(VaultRole.decoy));
  });

  test('changePasscode rejects new value matching other vault', () async {
    final svc = PasscodeService();
    await svc.setupMain('1234');
    await svc.setupDecoy('9876');
    expect(
      () => svc.changePasscode(vaultName: kVaultA, newPasscode: '9876'),
      throwsA(isA<PasscodeException>()),
    );
  });

  test('hasDecoyConfigured reflects state', () async {
    final svc = PasscodeService();
    await svc.setupMain('1234');
    expect(await svc.hasDecoyConfigured(), isFalse);
    await svc.setupDecoy('9876');
    expect(await svc.hasDecoyConfigured(), isTrue);
  });

  test('short passcodes are rejected', () async {
    final svc = PasscodeService();
    expect(
      () => svc.setupMain('12'),
      throwsA(isA<PasscodeException>()),
    );
  });
}
