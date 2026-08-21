import 'package:flutter/material.dart';

/// Habillage visuel commun aux boutons de téléchargement (PDF / Excel) de
/// SYCEBNL.
///
/// Deux briques complémentaires, purement décoratives : aucune logique
/// métier, aucune action de téléchargement n'est portée ici.
///
///  * [DownloadIcon] ajoute une petite flèche vers le bas à l'icône du
///    format (PDF, Excel, ...) pour signaler l'action de téléchargement ;
///  * [DownloadTooltip] affiche, au survol de la souris uniquement, un
///    libellé « Télécharger PDF » / « Télécharger Excel » sous le bouton,
///    en fondu, sans décaler les autres éléments de l'interface.
///
/// Usage typique :
/// ```dart
/// DownloadTooltip.pdf(
///   child: ElevatedButton.icon(
///     onPressed: _exportPdf,
///     icon: const DownloadIcon(Icons.picture_as_pdf, size: 16, color: Colors.white),
///     label: const Text('PDF'),
///   ),
/// )
/// ```

/// Libellés affichés au survol des boutons de téléchargement.
const String kDownloadPdfLabel = 'Télécharger PDF';
const String kDownloadExcelLabel = 'Télécharger Excel';

/// Couleurs de référence des boutons PDF / Excel, reprises telles quelles de
/// la page « Balance Générale des Comptes » (écran de référence pour
/// l'ensemble de l'application). Toute page qui télécharge un PDF ou un
/// Excel doit utiliser ces mêmes couleurs.
final Color kDownloadPdfColor = Colors.red.shade600;
final Color kDownloadExcelColor = Colors.green.shade600;

/// Icône de format suffixée d'une discrète flèche vers le bas.
///
/// La flèche reprend automatiquement la couleur et la taille de l'icône
/// principale (à 65 %), de sorte que le bouton conserve son style d'origine.
class DownloadIcon extends StatelessWidget {
  const DownloadIcon(this.icon, {super.key, this.size, this.color});

  /// Icône du format exporté (`Icons.picture_as_pdf`, `Icons.table_chart`, ...).
  final IconData icon;

  /// Taille de l'icône principale. Reprend le thème d'icône ambiant si nulle
  /// (cas des `IconButton` et des boutons de barre d'application).
  final double? size;

  /// Couleur des deux icônes. Reprend le thème d'icône ambiant si nulle.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final double baseSize = size ?? IconTheme.of(context).size ?? 24.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: baseSize, color: color),
        SizedBox(width: baseSize * 0.1),
        Icon(
          Icons.arrow_downward_rounded,
          size: baseSize * 0.65,
          color: color,
        ),
      ],
    );
  }
}

/// Info-bulle de téléchargement affichée sous le bouton, en fondu, au survol.
///
/// S'appuie sur le [Tooltip] de Material : le libellé est rendu dans une
/// couche superposée (overlay), il n'occupe donc aucune place dans la mise en
/// page et ne déplace pas les éléments voisins. Il disparaît dès que le
/// curseur quitte le bouton.
class DownloadTooltip extends StatelessWidget {
  const DownloadTooltip({
    super.key,
    required this.message,
    required this.child,
    this.verticalOffset = 26,
  });

  /// Info-bulle « Télécharger PDF ».
  const DownloadTooltip.pdf({
    super.key,
    required this.child,
    this.verticalOffset = 26,
  }) : message = kDownloadPdfLabel;

  /// Info-bulle « Télécharger Excel ».
  const DownloadTooltip.excel({
    super.key,
    required this.child,
    this.verticalOffset = 26,
  }) : message = kDownloadExcelLabel;

  /// Texte affiché au survol.
  final String message;

  /// Bouton de téléchargement existant, inchangé.
  final Widget child;

  /// Distance entre le centre du bouton et le haut de l'info-bulle.
  /// À ajuster pour les boutons plus hauts (`IconButton` : 28 à 30).
  final double verticalOffset;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      // Toujours sous le bouton (Flutter bascule au-dessus uniquement si la
      // place manque en bas de l'écran).
      preferBelow: true,
      verticalOffset: verticalOffset,
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF21F2937),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
