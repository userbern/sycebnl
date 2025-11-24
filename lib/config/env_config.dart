import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration des variables d'environnement
/// Les valeurs sont chargées depuis le fichier .env
class EnvConfig {
  /// URL du projet Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Clé anonyme Supabase
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Vérifie que toutes les variables d'environnement nécessaires sont définies
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }
}
