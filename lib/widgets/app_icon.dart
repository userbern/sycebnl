import 'package:flutter/material.dart';

/// Icône officielle de l'application (`assets/images/icone.png`), seul
/// point de référence à cet asset dans le code Dart. Distincte de
/// [AppLogo] (`assets/images/logo.png`), utilisée pour les emplacements
/// compacts (ex. en-tête de l'écran d'accueil).
class AppIcon extends StatelessWidget {
  final double size;
  final BoxFit fit;

  const AppIcon({super.key, this.size = 48, this.fit = BoxFit.contain});

  static const String assetPath = 'assets/images/icone.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
    );
  }
}
