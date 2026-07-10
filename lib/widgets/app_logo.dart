import 'package:flutter/material.dart';

/// Logo officiel de l'application, seul point de référence à
/// `assets/images/logo.png` dans le code Dart : remplacer ce fichier suffit
/// à mettre à jour le logo partout où [AppLogo] est utilisé (icône exclue,
/// voir `dart run flutter_launcher_icons` documenté dans pubspec.yaml).
class AppLogo extends StatelessWidget {
  final double size;
  final BoxFit fit;

  const AppLogo({super.key, this.size = 48, this.fit = BoxFit.contain});

  static const String assetPath = 'assets/images/logo.png';

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
