import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
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
import 'widgets/app_logo.dart';

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

  // Initialiser les données de formatage de date en français.
  await initializeDateFormatting('fr_FR', null);

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
      final remainingSeconds = ValueNotifier<int>(_closeTimeoutSeconds);
      if (context.mounted) {
        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => Dialog(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 28,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.92, end: 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeInOut,
                          builder:
                              (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                          child: const AppLogo(size: 96),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 220,
                          child: ValueListenableBuilder<int>(
                            valueListenable: remainingSeconds,
                            builder: (context, value, _) {
                              final elapsedFraction =
                                  (_closeTimeoutSeconds - value) /
                                  _closeTimeoutSeconds;
                              return TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: elapsedFraction -
                                      (1 / _closeTimeoutSeconds),
                                  end: elapsedFraction,
                                ),
                                duration: const Duration(seconds: 1),
                                curve: Curves.linear,
                                builder:
                                    (context, progress, _) =>
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress.clamp(0.0, 1.0),
                                            minHeight: 6,
                                          ),
                                        ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<int>(
                          valueListenable: remainingSeconds,
                          builder: (context, value, _) {
                            final message = _closingMessages[
                                (_closeTimeoutSeconds - value) %
                                    _closingMessages.length];
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                message,
                                key: ValueKey(message),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        );
      }

      final countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (remainingSeconds.value > 0) remainingSeconds.value--;
      });

      final closeStopwatch = Stopwatch()..start();
      final results = await Future.wait([
        Future.any([
          _performClosingWork().then((_) => false),
          Future.delayed(
            const Duration(seconds: _closeTimeoutSeconds),
            () => true,
          ),
        ]),
        // Garantit que la boîte "Fermeture en cours" reste visible au moins
        // ce temps, même si la fermeture réelle est quasi instantanée.
        Future.delayed(_minClosingDialogDuration),
      ]);
      final timedOut = results[0] as bool;
      countdownTimer.cancel();

      if (timedOut) {
        debugPrint(
            '[Fermeture] Délai de ${_closeTimeoutSeconds}s dépassé, fermeture forcée '
            '(${closeStopwatch.elapsedMilliseconds} ms écoulés — fermeture normale non terminée)');
      } else {
        debugPrint(
            '[Fermeture] Fermeture normale terminée en ${closeStopwatch.elapsedMilliseconds} ms');
      }
      await windowManager.destroy();
    }
  }

  static const int _closeTimeoutSeconds = 5;
  static const Duration _minClosingDialogDuration = Duration(milliseconds: 900);

  static const List<String> _closingMessages = [
    'Enregistrement des données…',
    'Sécurisation du dossier…',
    'Fermeture des connexions…',
    'Finalisation…',
  ];

  Future<void> _performClosingWork() async {
    final closeStopwatch = Stopwatch()..start();
    if (DatabaseService.isConnected) {
      await DatabaseService.database.close();
      debugPrint(
          '[Fermeture] DB fermée en ${closeStopwatch.elapsedMilliseconds} ms');
    }
    if (DossierCryptoService.hasOpenEncryptedSession) {
      closeStopwatch.reset();
      await DossierCryptoService.closeOpenSessionAndReencrypt();
      debugPrint(
          '[Fermeture] Rechiffrement terminé en ${closeStopwatch.elapsedMilliseconds} ms');
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
