import 'package:flutter/material.dart';
import 'saisie_comptable.dart';

/// Catégories affichées dans la recherche globale de la Top Bar.
enum GlobalSearchCategory {
  compte,
  tiers,
  journal,
  projet,
  bailleur,
  ecriture,
  fonctionnalite,
}

extension GlobalSearchCategoryInfo on GlobalSearchCategory {
  String get label {
    switch (this) {
      case GlobalSearchCategory.compte:
        return 'Comptes';
      case GlobalSearchCategory.tiers:
        return 'Tiers';
      case GlobalSearchCategory.journal:
        return 'Journaux';
      case GlobalSearchCategory.projet:
        return 'Projets';
      case GlobalSearchCategory.bailleur:
        return 'Bailleurs';
      case GlobalSearchCategory.ecriture:
        return 'Écritures comptables';
      case GlobalSearchCategory.fonctionnalite:
        return 'Fonctionnalités';
    }
  }

  IconData get icon {
    switch (this) {
      case GlobalSearchCategory.compte:
        return Icons.account_balance_wallet;
      case GlobalSearchCategory.tiers:
        return Icons.people;
      case GlobalSearchCategory.journal:
        return Icons.book;
      case GlobalSearchCategory.projet:
        return Icons.folder;
      case GlobalSearchCategory.bailleur:
        return Icons.account_balance;
      case GlobalSearchCategory.ecriture:
        return Icons.receipt_long;
      case GlobalSearchCategory.fonctionnalite:
        return Icons.apps;
    }
  }

  Color get color {
    switch (this) {
      case GlobalSearchCategory.compte:
        return Colors.green.shade600;
      case GlobalSearchCategory.tiers:
        return Colors.orange.shade700;
      case GlobalSearchCategory.journal:
        return Colors.purple.shade600;
      case GlobalSearchCategory.projet:
        return Colors.teal.shade600;
      case GlobalSearchCategory.bailleur:
        return Colors.indigo.shade600;
      case GlobalSearchCategory.ecriture:
        return Colors.brown.shade500;
      case GlobalSearchCategory.fonctionnalite:
        return Colors.blueGrey.shade600;
    }
  }
}

/// Un résultat affiché dans le panneau déroulant de la recherche globale.
class GlobalSearchResult {
  final GlobalSearchCategory category;
  final String title;
  final String? subtitle;

  /// Index de page HomePage à ouvrir (compte, tiers, journal, projet,
  /// bailleur, fonctionnalité).
  final int? pageIndex;

  /// Période de journal à ouvrir directement en saisie (écritures).
  final JournalPeriode? journalPeriode;

  const GlobalSearchResult({
    required this.category,
    required this.title,
    this.subtitle,
    this.pageIndex,
    this.journalPeriode,
  });
}
