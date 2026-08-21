import 'i_accounting_repository.dart';
import 'repository_provider.dart';
import '../models/compte.dart';
import '../models/kpi.dart';

/// Moteur centralisé de calcul des indicateurs (KPI) comptables.
///
/// Principe : une seule requête groupée ([getSoldesComptes]) ramène le solde
/// de chaque compte pour un exercice (et une période optionnelle) ; tous les
/// KPI sont ensuite calculés en mémoire à partir de cette même liste, pour
/// éviter de multiplier les requêtes SQL. Lecture seule : aucune table n'est
/// modifiée.
class KpiService {
  static IAccountingRepository get database => RepositoryProvider.current;

  static String _formatSqlDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Date comptable réelle d'une écriture, avec repli sur
  /// année/mois de la période + jour de l'écriture. Même pattern que
  /// `grand_livre_page.dart` et `balance_resultat_page.dart`, pour rester
  /// cohérent avec les états déjà affichés dans l'application.
  static const String _dateExpr =
      "date(COALESCE(e.date_comptable, jp.annee || '-' || printf('%02d', jp.mois) || '-' || printf('%02d', e.jour)))";

  // ---------------------------------------------------------------------
  // Moteur générique
  // ---------------------------------------------------------------------

  /// Solde (débit total, crédit total) de chaque compte mouvementé sur
  /// l'exercice [exerciceId], optionnellement restreint à [dateDebut] -
  /// [dateFin]. Requête unique, groupée par compte.
  static Future<List<SoldeCompte>> getSoldesComptes(
    int exerciceId, {
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final where = StringBuffer('jp.exercice_id = ? AND c.deleted_at IS NULL');
    final args = <dynamic>[exerciceId];

    if (dateDebut != null) {
      where.write(' AND $_dateExpr >= date(?)');
      args.add(_formatSqlDate(dateDebut));
    }
    if (dateFin != null) {
      where.write(' AND $_dateExpr <= date(?)');
      args.add(_formatSqlDate(dateFin));
    }

    final rows = await database.rawQuery('''
      SELECT c.numero_compte, c.intitule, c.nature,
             COALESCE(SUM(e.montant_debit), 0) AS total_debit,
             COALESCE(SUM(e.montant_credit), 0) AS total_credit
      FROM compte c
      JOIN ecritures e ON e.numero_compte = c.numero_compte
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      WHERE $where
      GROUP BY c.numero_compte, c.intitule, c.nature
    ''', args);

    return rows.map((r) => SoldeCompte.fromMap(r)).toList();
  }

  /// Nombre d'écritures de l'exercice (et de la période optionnelle).
  /// Ne peut pas être dérivé de [getSoldesComptes] (ce n'est pas un solde
  /// par compte), d'où une requête dédiée mais minimale (COUNT simple).
  static Future<int> getNombreEcritures(
    int exerciceId, {
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final where = StringBuffer('jp.exercice_id = ?');
    final args = <dynamic>[exerciceId];

    if (dateDebut != null) {
      where.write(' AND $_dateExpr >= date(?)');
      args.add(_formatSqlDate(dateDebut));
    }
    if (dateFin != null) {
      where.write(' AND $_dateExpr <= date(?)');
      args.add(_formatSqlDate(dateFin));
    }

    final rows = await database.rawQuery('''
      SELECT COUNT(*) AS nb
      FROM ecritures e
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      WHERE $where
    ''', args);

    return (rows.first['nb'] as num?)?.toInt() ?? 0;
  }

  /// Exercice précédent au sens strict demandé : le dernier exercice dont
  /// `date_debut` est antérieure à celle de [exerciceId] (aucune dépendance
  /// à `is_cloture`, qui n'est pas encore renseigné dans l'application, ni à
  /// l'ordre des identifiants).
  static Future<Map<String, dynamic>?> getExercicePrecedent(
    int exerciceId,
  ) async {
    final rows = await database.rawQuery('''
      SELECT * FROM exercice
      WHERE deleted_at IS NULL
        AND date_debut < (SELECT date_debut FROM exercice WHERE id = ?)
      ORDER BY date_debut DESC
      LIMIT 1
    ''', [exerciceId]);

    return rows.isNotEmpty ? rows.first : null;
  }

  static Iterable<SoldeCompte> _parPrefixe(
    List<SoldeCompte> soldes,
    String prefixe,
  ) =>
      soldes.where((s) => s.numeroCompte.startsWith(prefixe));

  static Iterable<SoldeCompte> _parNature(
    List<SoldeCompte> soldes,
    Set<NatureCompte> natures,
  ) =>
      soldes.where((s) => natures.contains(s.nature));

  static double _sumDebit(Iterable<SoldeCompte> l) =>
      l.fold(0.0, (s, c) => s + c.totalDebit);

  static double _sumCredit(Iterable<SoldeCompte> l) =>
      l.fold(0.0, (s, c) => s + c.totalCredit);

  static double _sumSolde(Iterable<SoldeCompte> l) =>
      l.fold(0.0, (s, c) => s + c.solde);

  // ---------------------------------------------------------------------
  // KPI du lot 1 — calculés à partir d'une liste de SoldeCompte déjà
  // chargée (aucune requête SQL supplémentaire).
  // ---------------------------------------------------------------------

  /// Trésorerie : classe 5, solde débiteur normal (débit - crédit).
  static double getTresorerie(List<SoldeCompte> soldes) =>
      _sumSolde(_parPrefixe(soldes, '5'));

  /// Total des produits : classe 7 (AO) + comptes de nature produitsHAO
  /// (classe 8, 2e chiffre pair), solde créditeur normal.
  static double getTotalProduits(List<SoldeCompte> soldes) {
    final comptes = [
      ..._parPrefixe(soldes, '7'),
      ..._parNature(soldes, {NatureCompte.produitsHAO}),
    ];
    return _sumCredit(comptes) - _sumDebit(comptes);
  }

  /// Total des charges : classe 6 (AO) + comptes de nature chargesHAO
  /// (classe 8, 2e chiffre impair), solde débiteur normal.
  static double getTotalCharges(List<SoldeCompte> soldes) {
    final comptes = [
      ..._parPrefixe(soldes, '6'),
      ..._parNature(soldes, {NatureCompte.chargesHAO}),
    ];
    return _sumDebit(comptes) - _sumCredit(comptes);
  }

  /// Résultat : même méthode que `balance_resultat_page.dart`
  /// (`_buildNatureResultatWidget`) — différentiel crédit - débit sur
  /// l'ensemble des comptes de classes 6, 7 et 8, pour ne jamais afficher un
  /// chiffre différent de la Balance des résultats existante.
  static double getResultat(List<SoldeCompte> soldes) {
    final gestion = soldes.where((s) {
      final n = int.tryParse(s.numeroCompte[0]) ?? 0;
      return n >= 6 && n <= 8;
    });
    return _sumCredit(gestion) - _sumDebit(gestion);
  }

  /// Créances : parmi les comptes de tiers (classe 4), somme des soldes
  /// débiteurs uniquement, compte par compte (un compte fournisseur
  /// exceptionnellement débiteur, ex. avance versée, compte donc ici).
  static double getCreances(List<SoldeCompte> soldes) => _parPrefixe(
        soldes,
        '4',
      ).where((s) => s.solde > 0).fold(0.0, (s, c) => s + c.solde);

  /// Dettes : parmi les comptes de tiers (classe 4), somme des soldes
  /// créditeurs uniquement, compte par compte (symétrique de
  /// [getCreances]).
  static double getDettes(List<SoldeCompte> soldes) => _parPrefixe(
        soldes,
        '4',
      ).where((s) => s.solde < 0).fold(0.0, (s, c) => s - c.solde);

  /// Immobilisations : classe 2, solde débiteur normal.
  static double getImmobilisations(List<SoldeCompte> soldes) =>
      _sumSolde(_parPrefixe(soldes, '2'));

  /// Stocks : classe 3, solde débiteur normal.
  static double getStocks(List<SoldeCompte> soldes) =>
      _sumSolde(_parPrefixe(soldes, '3'));

  /// Fonds propres / ressources durables : classe 1, solde créditeur
  /// normal.
  static double getFondsPropres(List<SoldeCompte> soldes) {
    final comptes = _parPrefixe(soldes, '1');
    return _sumCredit(comptes) - _sumDebit(comptes);
  }

  /// Budget consommé de l'exercice [exerciceId] : montant prévu (somme des
  /// `sous_rubrique.montant` des budgets rattachés à l'exercice) comparé au
  /// montant réalisé (somme des ventilations analytiques liées à une ligne
  /// budgétaire, sur des écritures effectivement passées dans l'exercice).
  /// Deux requêtes agrégées dédiées : ce périmètre (budget) est disjoint de
  /// [getSoldesComptes] et ne peut pas en être dérivé.
  static Future<BudgetConsommeResult> getBudgetConsomme(
    int exerciceId,
  ) async {
    final prevuRows = await database.rawQuery('''
      SELECT COALESCE(SUM(sr.montant), 0) AS prevu
      FROM sous_rubrique sr
      JOIN ligne_budgetaire lb ON lb.id = sr.ligne_budgetaire_id
        AND lb.deleted_at IS NULL
      JOIN poste_budgetaire pb ON pb.id = lb.poste_budgetaire_id
        AND pb.deleted_at IS NULL
      JOIN budget b ON b.id = pb.budget_id AND b.deleted_at IS NULL
      WHERE b.exercice_id = ? AND sr.deleted_at IS NULL
    ''', [exerciceId]);

    final realiseRows = await database.rawQuery('''
      SELECT COALESCE(SUM(va.montant_ventile), 0) AS realise
      FROM ventilations_analytiques va
      JOIN ecritures e ON e.id = va.ecriture_id
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      WHERE jp.exercice_id = ?
        AND va.id_ligne_budgetaire IS NOT NULL
        AND va.deleted_at IS NULL
    ''', [exerciceId]);

    return BudgetConsommeResult(
      montantPrevu: (prevuRows.first['prevu'] as num?)?.toDouble() ?? 0,
      montantRealise:
          (realiseRows.first['realise'] as num?)?.toDouble() ?? 0,
    );
  }

  // ---------------------------------------------------------------------
  // Comparaison exercice actuel / exercice précédent
  // ---------------------------------------------------------------------

  /// Calcule un KPI sur l'exercice courant et, si un exercice précédent
  /// existe, sur ce dernier (selon la règle [getExercicePrecedent]), pour en
  /// déduire le pourcentage d'évolution.
  static Future<KpiResult> avecComparaisonExercicePrecedent({
    required String code,
    required String libelle,
    required double Function(List<SoldeCompte>) compute,
    required List<SoldeCompte> soldesExerciceActuel,
    required int exerciceActuelId,
  }) async {
    final valeur = compute(soldesExerciceActuel);

    final exercicePrecedent = await getExercicePrecedent(exerciceActuelId);
    double? valeurPrecedente;
    double? evolutionPct;

    if (exercicePrecedent != null) {
      final idPrecedent = exercicePrecedent['id'] as int;
      final soldesPrecedents = await getSoldesComptes(idPrecedent);
      valeurPrecedente = compute(soldesPrecedents);
      if (valeurPrecedente != 0) {
        evolutionPct =
            (valeur - valeurPrecedente) / valeurPrecedente.abs() * 100;
      }
    }

    return KpiResult(
      code: code,
      libelle: libelle,
      valeur: valeur,
      exerciceId: exerciceActuelId,
      valeurPrecedente: valeurPrecedente,
      evolutionPct: evolutionPct,
    );
  }

  /// Calcule l'ensemble des KPI du dashboard DG (lot 1) en une seule
  /// récupération des soldes comptables (+ une seule requête de comptage
  /// des écritures), avec comparaison optionnelle à l'exercice précédent.
  static Future<Map<String, KpiResult>> getDashboardKpis(
    int exerciceId, {
    DateTime? dateDebut,
    DateTime? dateFin,
    bool avecComparaison = true,
  }) async {
    final soldes = await getSoldesComptes(
      exerciceId,
      dateDebut: dateDebut,
      dateFin: dateFin,
    );
    final nombreEcritures = await getNombreEcritures(
      exerciceId,
      dateDebut: dateDebut,
      dateFin: dateFin,
    );

    final definitions = <String, ({String libelle, double Function(List<SoldeCompte>) compute})>{
      'tresorerie': (libelle: 'Trésorerie', compute: getTresorerie),
      'produits': (libelle: 'Total des produits', compute: getTotalProduits),
      'charges': (libelle: 'Total des charges', compute: getTotalCharges),
      'resultat': (libelle: 'Résultat', compute: getResultat),
      'creances': (libelle: 'Créances', compute: getCreances),
      'dettes': (libelle: 'Dettes', compute: getDettes),
      'immobilisations': (
        libelle: 'Immobilisations',
        compute: getImmobilisations
      ),
      'stocks': (libelle: 'Stocks', compute: getStocks),
      'fonds_propres': (libelle: 'Fonds propres', compute: getFondsPropres),
    };

    final resultats = <String, KpiResult>{};
    for (final entry in definitions.entries) {
      resultats[entry.key] = avecComparaison
          ? await avecComparaisonExercicePrecedent(
              code: entry.key,
              libelle: entry.value.libelle,
              compute: entry.value.compute,
              soldesExerciceActuel: soldes,
              exerciceActuelId: exerciceId,
            )
          : KpiResult(
              code: entry.key,
              libelle: entry.value.libelle,
              valeur: entry.value.compute(soldes),
              exerciceId: exerciceId,
            );
    }

    resultats['nombre_ecritures'] = KpiResult(
      code: 'nombre_ecritures',
      libelle: "Nombre d'écritures",
      valeur: nombreEcritures.toDouble(),
      exerciceId: exerciceId,
      dateDebut: dateDebut,
      dateFin: dateFin,
    );

    return resultats;
  }

  /// Mouvements mensuels (débit/crédit) des comptes dont le numéro commence
  /// par l'un des [classePrefixes], pour l'exercice [exerciceId]. Sert aux
  /// graphiques d'évolution (produits, charges, trésorerie) du dashboard :
  /// une requête groupée par mois de la période de saisie (`jp.annee`,
  /// `jp.mois`), plutôt qu'un re-calcul de [getSoldesComptes] par mois.
  static Future<List<Map<String, dynamic>>> getEvolutionMensuelle(
    int exerciceId,
    List<String> classePrefixes,
  ) async {
    final prefixConditions =
        classePrefixes.map((_) => 'c.numero_compte LIKE ?').join(' OR ');
    final args = <dynamic>[
      exerciceId,
      ...classePrefixes.map((p) => '$p%'),
    ];

    return database.rawQuery('''
      SELECT jp.annee, jp.mois,
             COALESCE(SUM(e.montant_debit), 0) AS total_debit,
             COALESCE(SUM(e.montant_credit), 0) AS total_credit
      FROM ecritures e
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      JOIN compte c ON c.numero_compte = e.numero_compte
      WHERE jp.exercice_id = ? AND c.deleted_at IS NULL AND ($prefixConditions)
      GROUP BY jp.annee, jp.mois
      ORDER BY jp.annee, jp.mois
    ''', args);
  }

  // ---------------------------------------------------------------------
  // Drill-down : classe → groupe → compte → écritures
  // ---------------------------------------------------------------------

  /// Regroupe une liste de [SoldeCompte] déjà chargée par préfixe de
  /// [longueurPrefixe] chiffres (1 = classe, 2 = groupe...), sans requête
  /// SQL supplémentaire. La longueur réelle du numéro de compte est
  /// respectée (un numéro plus court que [longueurPrefixe] forme son propre
  /// groupe).
  static List<SoldeGroupe> regrouperParPrefixe(
    List<SoldeCompte> soldes,
    int longueurPrefixe,
  ) {
    final groupes = <String, List<SoldeCompte>>{};
    for (final s in soldes) {
      final longueur = s.numeroCompte.length < longueurPrefixe
          ? s.numeroCompte.length
          : longueurPrefixe;
      final prefixe = s.numeroCompte.substring(0, longueur);
      groupes.putIfAbsent(prefixe, () => []).add(s);
    }

    final resultat = groupes.entries
        .map((e) => SoldeGroupe(
              prefixe: e.key,
              totalDebit: _sumDebit(e.value),
              totalCredit: _sumCredit(e.value),
              nombreComptes: e.value.length,
            ))
        .toList()
      ..sort((a, b) => a.prefixe.compareTo(b.prefixe));

    return resultat;
  }

  /// Comptes (soldes détaillés) dont le numéro commence par [prefixe],
  /// pour le niveau "compte" du drill-down. Toujours dérivé en mémoire de
  /// [soldes], jamais d'une nouvelle requête.
  static List<SoldeCompte> comptesDuPrefixe(
    List<SoldeCompte> soldes,
    String prefixe,
  ) =>
      _parPrefixe(soldes, prefixe).toList()
        ..sort((a, b) => a.numeroCompte.compareTo(b.numeroCompte));

  /// Dernier niveau du drill-down : les écritures qui composent le solde
  /// d'un compte précis, pour l'exercice (et la période optionnelle)
  /// donnés. Seule requête du drill-down qui touche à nouveau la base,
  /// puisque le détail ligne à ligne n'est pas dans [SoldeCompte].
  static Future<List<Map<String, dynamic>>> getEcrituresCompte(
    String numeroCompte,
    int exerciceId, {
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final where = StringBuffer(
      'jp.exercice_id = ? AND e.numero_compte = ?',
    );
    final args = <dynamic>[exerciceId, numeroCompte];

    if (dateDebut != null) {
      where.write(' AND $_dateExpr >= date(?)');
      args.add(_formatSqlDate(dateDebut));
    }
    if (dateFin != null) {
      where.write(' AND $_dateExpr <= date(?)');
      args.add(_formatSqlDate(dateFin));
    }

    return database.rawQuery('''
      SELECT
        e.id,
        e.numero_compte,
        e.numero_document,
        e.reference,
        e.libelle,
        jp.code_journal,
        $_dateExpr AS date_comptable,
        e.montant_debit,
        e.montant_credit
      FROM ecritures e
      JOIN journaux_periodes jp ON jp.id = e.journal_periode_id
      WHERE $where
      ORDER BY date_comptable, e.numero_enregistrement
    ''', args);
  }
}
