import 'package:intl/intl.dart';

/// Formate un montant avec séparateurs de milliers (espace) et sans
/// décimales, ex: 1234567.5 -> "1 234 568".
final NumberFormat _montantFormat = NumberFormat.decimalPattern('fr_FR')
  ..minimumFractionDigits = 0
  ..maximumFractionDigits = 0;

String formatMontant(num montant) => _montantFormat.format(montant);

/// Formate un montant sans décimales (pour les affichages compacts), ex:
/// 1234567 -> "1 234 567".
final NumberFormat _montantEntierFormat = NumberFormat.decimalPattern('fr_FR');

String formatMontantEntier(num montant) => _montantEntierFormat.format(montant);

/// Formate un montant avec séparateurs de milliers et suffixe devise FCFA,
/// sans abréviation (ex: 30000000 -> "30 000 000 FCFA", 0 -> "0 FCFA",
/// -91107500 -> "-91 107 500 FCFA").
String formatMontantFcfa(num montant) => '${formatMontant(montant)} FCFA';

/// Formate une date au format français jj/mm/aaaa.
String formatDateFr(DateTime date) => DateFormat('dd/MM/yyyy', 'fr_FR').format(date);

/// Formate une date au format français long, ex: "7 août 2026".
String formatDateFrLongue(DateTime date) =>
    DateFormat('d MMMM yyyy', 'fr_FR').format(date);
