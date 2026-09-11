import 'compte.dart';

/// Solde agrégé d'un compte pour un exercice (et éventuellement une période)
/// donné. Brique de base commune à tous les KPI : une seule récupération de
/// [SoldeCompte] permet ensuite de calculer plusieurs KPI en mémoire, sans
/// multiplier les requêtes SQL.
class SoldeCompte {
  final String numeroCompte;
  final String intitule;
  final NatureCompte nature;
  final double totalDebit;
  final double totalCredit;

  const SoldeCompte({
    required this.numeroCompte,
    required this.intitule,
    required this.nature,
    required this.totalDebit,
    required this.totalCredit,
  });

  /// Solde réel du compte (débit - crédit), sans inversion de signe selon la
  /// nature : cohérent avec le calcul déjà utilisé dans le reste de
  /// l'application (Balance des comptes, Grand livre).
  double get solde => totalDebit - totalCredit;

  factory SoldeCompte.fromMap(Map<String, dynamic> map) {
    return SoldeCompte(
      numeroCompte: map['numero_compte'] as String,
      intitule: (map['intitule'] ?? '') as String,
      nature: stringToNatureCompte((map['nature'] ?? '') as String),
      totalDebit: (map['total_debit'] as num?)?.toDouble() ?? 0,
      totalCredit: (map['total_credit'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Résultat d'un KPI, avec comparaison optionnelle à l'exercice précédent.
class KpiResult {
  final String code;
  final String libelle;
  final double valeur;
  final int exerciceId;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final double? valeurPrecedente;
  final double? evolutionPct;

  const KpiResult({
    required this.code,
    required this.libelle,
    required this.valeur,
    required this.exerciceId,
    this.dateDebut,
    this.dateFin,
    this.valeurPrecedente,
    this.evolutionPct,
  });
}

/// Regroupement de comptes à un niveau de drill-down donné
/// (classe, groupe ou compte), obtenu par agrégation en mémoire d'une liste
/// de [SoldeCompte] déjà chargée — aucune requête SQL supplémentaire.
class SoldeGroupe {
  final String prefixe;
  final double totalDebit;
  final double totalCredit;
  final int nombreComptes;

  const SoldeGroupe({
    required this.prefixe,
    required this.totalDebit,
    required this.totalCredit,
    required this.nombreComptes,
  });

  double get solde => totalDebit - totalCredit;
}

/// Résultat du KPI "budget consommé" : montant prévu (somme des
/// [sous_rubrique.montant] des budgets de l'exercice) comparé au montant
/// réalisé (somme des ventilations analytiques liées à une ligne
/// budgétaire, sur des écritures réellement passées dans l'exercice).
class BudgetConsommeResult {
  final double montantPrevu;
  final double montantRealise;

  const BudgetConsommeResult({
    required this.montantPrevu,
    required this.montantRealise,
  });

  /// Pourcentage de consommation du budget. `null` si aucun budget prévu
  /// n'est défini pour l'exercice (évite une division par zéro trompeuse).
  double? get pctConsommation =>
      montantPrevu == 0 ? null : (montantRealise / montantPrevu) * 100;
}
