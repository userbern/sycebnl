import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'welcome_page.dart';

/// Écran de démarrage affiché brièvement au lancement de l'application,
/// avant l'écran d'accueil.
class SplashPage extends StatefulWidget {
  /// Chemin d'un dossier comptable (.syca) à ouvrir automatiquement, transmis
  /// depuis `main.dart` (ex. lancement par double-clic sur un fichier associé).
  final String? initialFilePath;

  const SplashPage({super.key, this.initialFilePath});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WelcomePage(initialFilePath: widget.initialFilePath),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade100, Colors.blue.shade100],
          ),
        ),
        child: const Center(
          child: AppLogo(size: 160),
        ),
      ),
    );
  }
}
