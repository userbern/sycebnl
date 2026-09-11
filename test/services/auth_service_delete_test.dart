import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sycebnl_accounting/services/auth_service.dart';
import 'package:sycebnl_accounting/services/database_service.dart';

/// `AuthService.deleteCompte`/`deleteTiers` interrogeaient une table
/// `ligne_ecriture` inexistante (la vraie table s'appelle `ecritures`) : la
/// vérification "des écritures existent pour ce compte/tiers" échouait donc
/// systématiquement avec une erreur SQL, rendant toute suppression
/// impossible — y compris quand aucune écriture n'existait. Corrigé pour
/// pointer vers `ecritures`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('syca_delete_test_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('deleteCompte supprime un compte sans écriture liée', () async {
    final dossierPath = p.join(tempDir.path, 'entreprise_test.syca');
    await DatabaseService.createDatabase(
      dossierPath,
      adminLogin: 'chef',
      adminPassword: 'ChefPassw0rd!',
    );
    await DatabaseService.closeDatabase();
    await DatabaseService.connectToDatabase(dossierPath);

    await AuthService.createCompte(
      numeroCompte: '999999',
      intitule: 'Compte test',
      type: 'detail',
      nature: 'actif',
    );
    final comptes = await AuthService.getComptes();
    final compte = comptes.firstWhere((c) => c.numeroCompte == '999999');

    await AuthService.deleteCompte(int.parse(compte.id));

    final apres = await AuthService.getComptes();
    expect(apres.any((c) => c.numeroCompte == '999999'), isFalse);
  });

  test('deleteTiers supprime un tiers sans écriture liée', () async {
    final dossierPath = p.join(tempDir.path, 'entreprise_test.syca');
    await DatabaseService.createDatabase(
      dossierPath,
      adminLogin: 'chef',
      adminPassword: 'ChefPassw0rd!',
    );
    await DatabaseService.closeDatabase();
    await DatabaseService.connectToDatabase(dossierPath);

    await AuthService.createTiers(
      numeroCompte: '411001',
      intitule: 'Tiers test',
      type: 'client',
      compteCollectif: '411',
    );
    final tiersList = await AuthService.getTiers();
    final tiers = tiersList.firstWhere((t) => t.numeroCompte == '411001');

    await AuthService.deleteTiers(int.parse(tiers.id));

    final apres = await AuthService.getTiers();
    expect(apres.any((t) => t.numeroCompte == '411001'), isFalse);
  });
}
