import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sycebnl_accounting/services/auth_service.dart';
import 'package:sycebnl_accounting/services/database_service.dart';
import 'package:sycebnl_accounting/services/dossier_crypto_service.dart';
import 'package:sycebnl_accounting/services/network/accounting_server_service.dart';
import 'package:sycebnl_accounting/services/network/network_session_service.dart';

/// Test d'intégration bout en bout du chiffrement `.syca` combiné au partage
/// réseau : crée un dossier chiffré, le déverrouille comme le ferait le chef
/// comptable, démarre le vrai serveur HTTP embarqué sur `127.0.0.1`, puis
/// s'y connecte avec un vrai client HTTP pour vérifier que la lecture/
/// écriture, les permissions et la révocation immédiate d'accès fonctionnent
/// réellement (pas seulement en théorie).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('syca_network_test_');

    // DossierCryptoService utilise path_provider pour stager les fichiers
    // déchiffrés temporaires : on simule le channel avec notre dossier
    // temporaire de test.
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
    await AccountingServerService.instance.stop();
    await DatabaseService.closeDatabase();
    NetworkSessionService.instance.clear();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Map<String, dynamic>> sendRequest(
    HttpClient client,
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(
      'http://127.0.0.1:${AccountingServerService.port}$path',
    );
    final request =
        method == 'POST'
            ? await client.postUrl(uri)
            : await client.getUrl(uri);
    if (token != null) {
      request.headers.set('Authorization', 'Bearer $token');
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return {
      'status': response.statusCode,
      'body': responseBody.isEmpty ? {} : jsonDecode(responseBody),
    };
  }

  test(
    'dossier .syca chiffré : déverrouillage, partage réseau, permissions et révocation immédiate',
    () async {
      final dossierPath = p.join(tempDir.path, 'entreprise_test.syca');
      const chefPassword = 'ChefPassw0rd!';

      // 1. Créer le dossier en clair avec un admin (le chef comptable).
      await DatabaseService.createDatabase(
        dossierPath,
        adminLogin: 'chef',
        adminPassword: chefPassword,
      );

      // `createDatabase` ne construit que le schéma de base (`onCreate`) ;
      // les colonnes ajoutées par migration (ex. `password_algo`) ne sont
      // appliquées qu'à l'ouverture (`onOpen`), comme lors d'un usage réel
      // où le dossier est fermé puis rouvert.
      await DatabaseService.closeDatabase();
      await DatabaseService.connectToDatabase(dossierPath);

      // Un stagiaire avec seulement la lecture sur le plan comptable.
      final stagiaireId = await AuthService.createUser(
        login: 'stagiaire',
        password: 'Stagiaire123!',
        nom: 'Kouassi',
        prenom: 'Awa',
      );
      final modules = await AuthService.getAllModules();
      final planComptableModuleId =
          modules.firstWhere((m) => m['nom'] == 'plan_comptable')['id']
              as int;
      await AuthService.updatePermissions(stagiaireId, [
        {
          'moduleId': planComptableModuleId,
          'lecture': true,
          'ajout': false,
          'modification': false,
          'suppression': false,
        },
      ]);

      // 2. Chiffrer le dossier.
      await DatabaseService.enableDossierEncryption(dossierPath, chefPassword);
      expect(await DossierCryptoService.isFileEncrypted(dossierPath), isTrue);

      // 3. Déverrouiller comme le ferait le chef comptable à l'ouverture.
      final decrypted = await DossierCryptoService.decryptToTemp(
        dossierPath,
        chefPassword,
      );
      await DatabaseService.connectToDatabase(decrypted.tempPath);

      // 4. Activer le partage réseau du dossier déchiffré.
      await AccountingServerService.instance.start();

      // TestWidgetsFlutterBinding installe par défaut un HttpOverrides qui
      // fait échouer toute vraie requête réseau (pour éviter les tests
      // flaky sur des services externes). Ici, on veut justement un vrai
      // aller-retour TCP en boucle locale contre notre propre serveur :
      // on désactive donc cet override pour la durée du test.
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        addTearDown(() => client.close(force: true));

        // 5a. Login réseau du stagiaire.
        final loginResult = await sendRequest(
          client,
          'POST',
          '/auth/login',
          body: {'login': 'stagiaire', 'password': 'Stagiaire123!'},
        );
        expect(loginResult['status'], 200);
        final token = (loginResult['body'] as Map)['token'] as String;
        expect(token, isNotEmpty);

        // 5b. Lecture autorisée : le plan comptable réellement déchiffré
        // est servi par le serveur (preuve que le déchiffrement + l'ouverture
        // SQLite fonctionnent bout en bout, pas juste la couche crypto seule).
        final comptesResult = await sendRequest(
          client,
          'GET',
          '/comptes',
          token: token,
        );
        expect(comptesResult['status'], 200);
        expect(comptesResult['body'], isA<List>());
        expect((comptesResult['body'] as List), isNotEmpty);

        // 5c. Écriture refusée : le stagiaire n'a pas la permission 'ajout',
        // vérifiée côté serveur (pas seulement côté client).
        final createResult = await sendRequest(
          client,
          'POST',
          '/comptes',
          token: token,
          body: {
            'numero_compte': '999999',
            'intitule': 'Test',
            'type': 'detail',
            'nature': 'actif',
          },
        );
        expect(createResult['status'], 403);

        // 6. L'admin désactive le stagiaire pendant que sa session réseau
        // est encore ouverte : l'accès doit être perdu immédiatement, pas
        // seulement au prochain login.
        await AuthService.updateUser(id: stagiaireId, isActive: false);

        final afterDeactivation = await sendRequest(
          client,
          'GET',
          '/comptes',
          token: token,
        );
        expect(afterDeactivation['status'], 401);

        // Une nouvelle tentative de connexion doit aussi être refusée.
        final loginAfterDeactivation = await sendRequest(
          client,
          'POST',
          '/auth/login',
          body: {'login': 'stagiaire', 'password': 'Stagiaire123!'},
        );
        expect(loginAfterDeactivation['status'], 401);
      }, _RealHttpOverrides());
    },
  );
}

/// `HttpOverrides` neutre (comportement par défaut de `dart:io`), utilisé
/// pour contourner celui installé par `flutter_test` qui bloque toute vraie
/// requête réseau.
class _RealHttpOverrides extends HttpOverrides {}
