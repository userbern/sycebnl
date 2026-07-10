import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'services/app_config_service.dart';
import 'services/app_database.dart';
import 'services/database_service.dart';
import 'services/dossier_crypto_service.dart';
import 'services/export_service.dart';
import 'services/file_association_service.dart';
import 'pages/splash_page.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser SQLite FFI pour les plateformes desktop (Windows, Linux, macOS)
  if (_isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();
    // Intercepte la fermeture de la fenêtre pour demander confirmation.
    await windowManager.setPreventClose(true);
  }

  // Initialiser la base de données de configuration de l'application
  await AppConfigService.initialize();

  // Nettoyer les fichiers temporaires déchiffrés laissés par une session
  // interrompue (crash) du module Sécurité du dossier comptable.
  await DossierCryptoService.cleanupStaleTempFiles();

  // Précharge le logo officiel pour les en-têtes des exports PDF.
  await ExportService.preloadLogo();

  // Associe l'extension .syca à l'application (double-clic ouvre le dossier).
  await FileAssociationService.registerIfNeeded();

  // Si l'app a été lancée par double-clic sur un dossier comptable, son
  // chemin arrive en argument de ligne de commande.
  final launchFilePath = args.isNotEmpty && AppDatabase.isAccountingFile(args.first)
      ? args.first
      : null;

  runApp(MyApp(initialFilePath: launchFilePath));
}

class MyApp extends StatefulWidget {
  final String? initialFilePath;

  const MyApp({super.key, this.initialFilePath});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      await windowManager.destroy();
      return;
    }

    final confirmer = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Quitter l\'application'),
            content: const Text(
              'Voulez-vous vraiment quitter l\'application ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Quitter'),
              ),
            ],
          ),
    );

    if (confirmer == true) {
      if (DossierCryptoService.hasOpenEncryptedSession) {
        if (DatabaseService.isConnected) {
          await DatabaseService.database.close();
        }
        await DossierCryptoService.closeOpenSessionAndReencrypt();
      }
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SYCEBNL Accounting',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      locale: const Locale('fr', 'FR'),
      home: SplashPage(initialFilePath: widget.initialFilePath),
      debugShowCheckedModeBanner: false,
    );
  }
}
