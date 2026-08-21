import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sycebnl_accounting/services/database_service.dart';
import 'package:sycebnl_accounting/services/network/accounting_server_service.dart';
import 'package:sycebnl_accounting/services/network/network_client.dart';
import 'package:sycebnl_accounting/services/network/network_connection_service.dart';
import 'package:sycebnl_accounting/services/network/network_session_service.dart';
import 'package:sycebnl_accounting/services/network/remote_repository.dart';
import 'package:sycebnl_accounting/services/repository_provider.dart';
import 'package:sycebnl_accounting/services/local_repository.dart';

/// Test d'intégration bout en bout de la couche CLIENT réseau (étape 3) :
/// démarre le vrai serveur embarqué et s'y connecte avec les vraies classes
/// utilisées par l'application (`NetworkClient`, `RemoteRepository`,
/// `NetworkConnectionService`) — pas un client HTTP artisanal comme dans
/// `network_encrypted_dossier_test.dart`, qui ne couvre que le serveur.
///
/// `RemoteRepository` est testé en l'instanciant directement (pas via
/// `RepositoryProvider.current`) : le serveur, dans ce process de test,
/// délègue lui-même à `AuthService`, qui lit `RepositoryProvider.current`.
/// Si ce test basculait cette variable globale sur `RemoteRepository` puis
/// appelait `AuthService.getComptes()`, le handler serveur (qui tourne dans
/// le même process) rappellerait `AuthService.getComptes()` — donc à nouveau
/// `RepositoryProvider.current` — bouclant sur lui-même indéfiniment. Dans
/// une utilisation réelle, client et serveur sont deux process/postes
/// distincts, donc cette collision n'existe pas ; ici on l'évite en gardant
/// `RepositoryProvider.current` sur `LocalRepository` pendant tout le test
/// et en pilotant `RemoteRepository` explicitement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('syca_client_test_');

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTemporaryDirectory') return tempDir.path;
      return null;
    });

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await NetworkConnectionService.instance.disconnect();
    RepositoryProvider.current = const LocalRepository();
    await AccountingServerService.instance.stop();
    await DatabaseService.closeDatabase();
    NetworkSessionService.instance.clear();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'NetworkConnectionService.connect() : login réel, token en mémoire, '
    'bascule et restauration de RepositoryProvider',
    () async {
      final dossierPath = p.join(tempDir.path, 'entreprise_test.syca');
      await DatabaseService.createDatabase(
        dossierPath,
        adminLogin: 'chef',
        adminPassword: 'ChefPassw0rd!',
      );
      // `createDatabase` ne construit que le schéma de base (`onCreate`) ;
      // les colonnes ajoutées par migration (ex. `password_algo`,
      // nécessaire à `AuthService.login`) ne sont appliquées qu'à
      // l'ouverture (`onOpen`), comme lors d'un usage réel où le dossier est
      // fermé puis rouvert avant d'être partagé sur le réseau.
      await DatabaseService.closeDatabase();
      await DatabaseService.connectToDatabase(dossierPath);
      await AccountingServerService.instance.start();

      await HttpOverrides.runWithHttpOverrides(() async {
        expect(RepositoryProvider.current, isA<LocalRepository>());

        await NetworkConnectionService.instance.connect(
          host: '127.0.0.1',
          port: AccountingServerService.port,
          login: 'chef',
          password: 'ChefPassw0rd!',
        );

        expect(
          NetworkConnectionService.instance.status,
          NetworkConnectionStatus.connected,
        );
        expect(NetworkConnectionService.instance.currentUser?['login'], 'chef');
        expect(RepositoryProvider.current, isA<RemoteRepository>());

        // Identifiants incorrects après une connexion : NetworkApiException 401.
        await expectLater(
          NetworkClient(host: '127.0.0.1', port: AccountingServerService.port)
              .login('chef', 'mauvais-mot-de-passe'),
          throwsA(isA<NetworkApiException>()),
        );

        await NetworkConnectionService.instance.disconnect();
        expect(
          NetworkConnectionService.instance.status,
          NetworkConnectionStatus.disconnected,
        );
        expect(RepositoryProvider.current, isA<LocalRepository>());
      }, _RealHttpOverrides());
    },
  );

  test(
    'RemoteRepository : CRUD réel sur compte/tiers/journal via le serveur '
    'embarqué (query/insert/update/soft-delete)',
    () async {
      final dossierPath = p.join(tempDir.path, 'entreprise_test.syca');
      await DatabaseService.createDatabase(
        dossierPath,
        adminLogin: 'chef',
        adminPassword: 'ChefPassw0rd!',
      );
      // `createDatabase` ne construit que le schéma de base (`onCreate`) ;
      // les colonnes ajoutées par migration (ex. `password_algo`,
      // nécessaire à `AuthService.login`) ne sont appliquées qu'à
      // l'ouverture (`onOpen`), comme lors d'un usage réel où le dossier est
      // fermé puis rouvert avant d'être partagé sur le réseau.
      await DatabaseService.closeDatabase();
      await DatabaseService.connectToDatabase(dossierPath);
      await AccountingServerService.instance.start();

      await HttpOverrides.runWithHttpOverrides(() async {
        final client = NetworkClient(
          host: '127.0.0.1',
          port: AccountingServerService.port,
        );
        await client.login('chef', 'ChefPassw0rd!');
        addTearDown(client.logout);
        final remote = RemoteRepository(client);

        // query() : la liste des comptes seedés (plan SYCEBNL) doit être non
        // vide et refléter exactement ce que voit le serveur en local.
        final comptesAvant = await remote.query(
          'compte',
          where: 'is_active = ? AND deleted_at IS NULL',
          whereArgs: [1],
          orderBy: 'numero_compte ASC',
        );
        expect(comptesAvant, isNotEmpty);

        final localComptesAvant = await DatabaseService.database.query(
          'compte',
          where: 'is_active = ? AND deleted_at IS NULL',
          whereArgs: [1],
        );
        expect(comptesAvant.length, localComptesAvant.length);

        // insert() : créer un compte via HTTP doit apparaître dans la vraie
        // base SQLite du serveur (pas une copie locale).
        await remote.insert('compte', {
          'numero_compte': '999999',
          'intitule': 'Compte test réseau',
          'type': 'detail',
          'nature': 'actif',
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        final localApresInsert = await DatabaseService.database.query(
          'compte',
          where: 'numero_compte = ?',
          whereArgs: ['999999'],
        );
        expect(localApresInsert, hasLength(1));
        expect(localApresInsert.first['intitule'], 'Compte test réseau');
        final compteId = localApresInsert.first['id'] as int;

        // query() avec where 'id = ?' : émulation du filtre côté client.
        final parId = await remote.query(
          'compte',
          where: 'id = ?',
          whereArgs: [compteId],
        );
        expect(parId, hasLength(1));
        expect(parId.first['numero_compte'], '999999');

        // update() : PUT réel, vérifié dans la vraie base.
        await remote.update(
          'compte',
          {'intitule': 'Compte test réseau modifié'},
          where: 'id = ?',
          whereArgs: [compteId],
        );
        final localApresUpdate = await DatabaseService.database.query(
          'compte',
          where: 'id = ?',
          whereArgs: [compteId],
        );
        expect(
          localApresUpdate.first['intitule'],
          'Compte test réseau modifié',
        );

        // update() posant deleted_at : doit être routé vers DELETE (soft
        // delete réel côté serveur), pas silencieusement ignoré par un PUT.
        // Testé sur 'journal' plutôt que 'compte'/'tiers' : ces deux derniers
        // ont un bug préexistant, indépendant du travail réseau (leur
        // AuthService.deleteXxx interroge une table 'ligne_ecriture' qui
        // n'existe pas — la vraie table s'appelle 'ecritures' — et échoue
        // donc systématiquement, y compris en local).
        await remote.insert('journal', {
          'code': 'RES',
          'libelle': 'Journal test réseau',
          'type': 'operations_diverses',
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        final localJournal = await DatabaseService.database.query(
          'journal',
          where: 'code = ?',
          whereArgs: ['RES'],
        );
        expect(localJournal, hasLength(1));
        final journalId = localJournal.first['id'] as int;

        await remote.update(
          'journal',
          {
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [journalId],
        );
        final localApresDelete = await DatabaseService.database.query(
          'journal',
          where: 'id = ?',
          whereArgs: [journalId],
        );
        expect(localApresDelete.first['deleted_at'], isNotNull);

        // Table non exposée par le serveur (étape 3) : erreur claire, pas un
        // échec silencieux.
        expect(
          () => remote.query('utilisateur'),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => remote.rawQuery('SELECT 1'),
          throwsA(isA<UnsupportedError>()),
        );
      }, _RealHttpOverrides());
    },
  );

  test(
    'NetworkConnectionService.connect() : serveur injoignable → '
    'NetworkUnavailableException, pas de bascule de RepositoryProvider',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        // Aucun serveur ne tourne sur ce port : la connexion doit échouer
        // proprement (timeout/connexion refusée), pas planter l'appli.
        await expectLater(
          NetworkConnectionService.instance.connect(
            host: '127.0.0.1',
            port: 8799,
            login: 'chef',
            password: 'x',
          ),
          throwsA(isA<NetworkUnavailableException>()),
        );

        expect(RepositoryProvider.current, isA<LocalRepository>());
      }, _RealHttpOverrides());
    },
  );
}

class _RealHttpOverrides extends HttpOverrides {}
