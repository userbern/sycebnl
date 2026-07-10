import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Exception levée quand le mot de passe (ou la clé de récupération) fourni
/// ne permet pas de déchiffrer le dossier.
class WrongPasswordException implements Exception {
  final String message;
  WrongPasswordException([this.message = 'Mot de passe incorrect']);
  @override
  String toString() => message;
}

/// Résultat du déverrouillage d'un dossier chiffré : chemin du fichier
/// temporaire déchiffré, prêt à être ouvert par sqflite.
class DecryptedDossier {
  final String tempPath;
  final String realPath;
  DecryptedDossier(this.tempPath, this.realPath);
}

/// Service central de sécurité des dossiers comptables :
/// - chiffrement/déchiffrement AES-256-GCM du fichier .db entier
/// - dérivation Argon2id (mot de passe, clé de récupération)
/// - génération d'UUID de dossier et de clé de récupération lisible
/// - gestion des fichiers temporaires déchiffrés (création, nettoyage au crash)
///
/// Format du fichier chiffré (voir aussi table `dossier_security` dans
/// [DatabaseService] pour les métadonnées qui, elles, voyagent avec le
/// contenu déchiffré) :
///   magic(8="SYCENC01") | passwordSalt(16) | recoverySalt(16) | nonce(12)
///   | wrappedKeyByPassword(48) | wrappedKeyByRecovery(48) | ciphertext+tag
///
/// La clé de données (32 octets aléatoires, une par dossier) chiffre le
/// contenu du fichier. Elle est elle-même "enveloppée" (chiffrée) deux fois :
/// une fois sous une clé dérivée du mot de passe, une fois sous une clé
/// dérivée de la clé de récupération. Cela permet de vérifier une clé de
/// récupération ou de changer le mot de passe sans jamais redéchiffrer tout
/// le fichier.
class DossierCryptoService {
  DossierCryptoService._();

  static const List<int> _magic = [
    0x53, 0x59, 0x43, 0x45, 0x4e, 0x43, 0x30, 0x31, // "SYCENC01"
  ];
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _wrappedKeyLength = 32 + 16; // dataKey(32) + GCM tag(16)
  static const int _headerLength =
      8 + _saltLength + _saltLength + _nonceLength + _wrappedKeyLength * 2;

  static const _uuid = Uuid();
  static final _aesGcm = AesGcm.with256bits();

  /// Paramètres Argon2id recommandés OWASP pour un usage desktop interactif.
  static Argon2id _argon2id({int hashLength = 32}) => Argon2id(
        parallelism: 1,
        memory: 19456, // 19 MiB
        iterations: 2,
        hashLength: hashLength,
      );

  static const argon2ParamsJson =
      '{"memory":19456,"iterations":2,"parallelism":1}';

  // ---------------------------------------------------------------------
  // Session ouverte (pour rechiffrement à la fermeture / au changement de
  // dossier). Le mot de passe est gardé en mémoire uniquement pendant la
  // session, le temps de pouvoir rechiffrer sans le redemander.
  // ---------------------------------------------------------------------

  static String? _openTempPath;
  static String? _openRealPath;
  static String? _openPassword;

  static bool get hasOpenEncryptedSession => _openRealPath != null;

  /// Chemin réel (chiffré) du dossier actuellement ouvert, si une session
  /// de dossier chiffré est en cours (null sinon).
  static String? get openRealPath => _openRealPath;

  static void registerOpenSession({
    required String tempPath,
    required String realPath,
    required String password,
  }) {
    _openTempPath = tempPath;
    _openRealPath = realPath;
    _openPassword = password;
  }

  /// Rechiffre et clôture la session ouverte, si une session de dossier
  /// chiffré est en cours (no-op sinon). À appeler avant fermeture de
  /// l'application ou changement de dossier.
  static Future<void> closeOpenSessionAndReencrypt() async {
    final tempPath = _openTempPath;
    final realPath = _openRealPath;
    final password = _openPassword;
    if (tempPath == null || realPath == null || password == null) return;
    _openTempPath = null;
    _openRealPath = null;
    _openPassword = null;
    if (await File(tempPath).exists()) {
      await encryptFromTemp(tempPath, realPath, password);
    }
  }

  // ---------------------------------------------------------------------
  // Détection
  // ---------------------------------------------------------------------

  /// Vérifie si [filePath] est un dossier chiffré par ce module (en-tête
  /// magique) sans nécessiter de mot de passe. Retourne false pour un
  /// fichier SQLite classique (dossier créé avant cette fonctionnalité, ou
  /// créé sans mot de passe).
  static Future<bool> isFileEncrypted(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    final raf = await file.open();
    try {
      final header = await raf.read(_magic.length);
      if (header.length < _magic.length) return false;
      for (var i = 0; i < _magic.length; i++) {
        if (header[i] != _magic[i]) return false;
      }
      return true;
    } finally {
      await raf.close();
    }
  }

  // ---------------------------------------------------------------------
  // UUID / clé de récupération
  // ---------------------------------------------------------------------

  static String generateDossierUuid() => _uuid.v4();

  /// Génère une clé de récupération lisible au format XXXX-XXXX-XXXX-XXXX,
  /// alphabet réduit pour éviter les caractères ambigus (0/O, 1/I).
  static String generateRecoveryKey() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var group = 0; group < 4; group++) {
      if (group > 0) buffer.write('-');
      for (var i = 0; i < 4; i++) {
        buffer.write(alphabet[random.nextInt(alphabet.length)]);
      }
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------
  // Argon2id générique (mot de passe utilisateur / hachage clé de récup.)
  // ---------------------------------------------------------------------

  /// Hache [secret] avec Argon2id. Retourne (hash base64, sel base64).
  static Future<(String hash, String salt)> hashSecret(String secret) async {
    final saltBytes = _randomBytes(_saltLength);
    final key = await _argon2id().deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: saltBytes,
    );
    final hashBytes = await key.extractBytes();
    return (base64Encode(hashBytes), base64Encode(saltBytes));
  }

  static Future<bool> verifySecret(
    String secret,
    String expectedHashBase64,
    String saltBase64,
  ) async {
    final key = await _argon2id().deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: base64Decode(saltBase64),
    );
    final hashBytes = await key.extractBytes();
    return _constantTimeEquals(base64Encode(hashBytes), expectedHashBase64);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  // ---------------------------------------------------------------------
  // Assistance éditeur (déverrouillage d'un seul dossier, pas de clé
  // maître). Voir la documentation en tête de fichier.
  // ---------------------------------------------------------------------

  /// Clé publique X25519 de l'éditeur (base64), générée hors-ligne une seule
  /// fois. La clé privée correspondante n'est JAMAIS embarquée dans l'app :
  /// elle reste chez l'éditeur, dans un outil séparé, hors du périmètre de
  /// ce dépôt. Tant que cette constante est vide, l'assistance éditeur est
  /// inerte (aucune enveloppe générée) — aucune régression pour les dossiers
  /// existants.
  static const String editorPublicKeyBase64 = '';

  /// Enveloppe la clé de données du dossier pour l'éditeur, via un échange
  /// de clés X25519 éphémère + HKDF + AES-256-GCM. Seule la clé privée de
  /// l'éditeur (jamais dans l'app) peut déchiffrer ce blob, et uniquement
  /// pour ce dossier précis (clé éphémère à usage unique, immédiatement
  /// jetée après l'enveloppement). Retourne null si aucune clé publique
  /// éditeur n'est configurée.
  static Future<String?> _wrapDataKeyForEditor(
    List<int> dataKeyBytes,
    String dossierUuid,
  ) async {
    if (editorPublicKeyBase64.isEmpty) return null;

    final x25519 = X25519();
    final ephemeralKeyPair = await x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    final editorPublicKey = SimplePublicKey(
      base64Decode(editorPublicKeyBase64),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: editorPublicKey,
    );

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final wrapKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode('sycebnl-editor-unlock-v1'),
    );

    final nonce = _randomBytes(_nonceLength);
    final box = await _aesGcm.encrypt(
      dataKeyBytes,
      secretKey: wrapKey,
      nonce: nonce,
    );

    return jsonEncode({
      'v': 1,
      'dossierUuid': dossierUuid,
      'ephemeralPublicKey': base64Encode(ephemeralPublicKey.bytes),
      'nonce': base64Encode(nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  // ---------------------------------------------------------------------
  // Chiffrement / déchiffrement du fichier
  // ---------------------------------------------------------------------

  /// Génère la clé de données (32 octets aléatoires) qui chiffrera le
  /// contenu du dossier. À utiliser avec [computeEditorUnlockBlob] avant
  /// [encryptNewFile] si l'appelant a besoin de persister l'enveloppe
  /// éditeur (qui doit être stockée dans `dossier_security`, donc avant que
  /// le fichier ne soit chiffré et la base fermée).
  static List<int> generateDataKey() => _randomBytes(32);

  /// Calcule l'enveloppe d'assistance éditeur pour une clé de données déjà
  /// générée. Voir [editorPublicKeyBase64] et [_wrapDataKeyForEditor].
  static Future<String?> computeEditorUnlockBlob(
    List<int> dataKeyBytes,
    String dossierUuid,
  ) {
    return _wrapDataKeyForEditor(dataKeyBytes, dossierUuid);
  }

  /// Chiffre pour la première fois un fichier .db existant en clair, avec
  /// [password] et une [recoveryKey] déjà générée. Écrit le résultat en
  /// remplaçant [filePath] (écriture atomique via fichier temporaire + rename).
  /// [dataKeyBytes] doit provenir de [generateDataKey] si l'appelant a besoin
  /// de calculer l'enveloppe éditeur au préalable ; sinon une clé est générée
  /// automatiquement.
  static Future<void> encryptNewFile(
    String filePath,
    String password,
    String recoveryKey, {
    List<int>? dataKeyBytes,
  }) async {
    final plainBytes = await File(filePath).readAsBytes();
    dataKeyBytes ??= _randomBytes(32);

    final passwordSalt = _randomBytes(_saltLength);
    final recoverySalt = _randomBytes(_saltLength);
    final wrappedByPassword =
        await _wrapDataKey(dataKeyBytes, password, passwordSalt);
    final wrappedByRecovery =
        await _wrapDataKey(dataKeyBytes, recoveryKey, recoverySalt);

    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _aesGcm.encrypt(
      plainBytes,
      secretKey: SecretKey(dataKeyBytes),
      nonce: nonce,
    );

    final header = BytesBuilder()
      ..add(_magic)
      ..add(passwordSalt)
      ..add(recoverySalt)
      ..add(nonce)
      ..add(wrappedByPassword)
      ..add(wrappedByRecovery);

    final output = BytesBuilder()
      ..add(header.toBytes())
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);

    await _atomicWrite(filePath, output.toBytes());
  }

  /// Déchiffre [filePath] vers un fichier temporaire en utilisant le mot de
  /// passe. Lève [WrongPasswordException] si le mot de passe est incorrect.
  static Future<DecryptedDossier> decryptToTemp(
    String filePath,
    String password,
  ) {
    return _decryptToTempUsing(filePath, password, useRecoveryPath: false);
  }

  /// Déchiffre [filePath] vers un fichier temporaire en utilisant la clé de
  /// récupération. Lève [WrongPasswordException] si la clé est incorrecte.
  static Future<DecryptedDossier> decryptToTempViaRecoveryKey(
    String filePath,
    String recoveryKey,
  ) {
    return _decryptToTempUsing(filePath, recoveryKey, useRecoveryPath: true);
  }

  static Future<DecryptedDossier> _decryptToTempUsing(
    String filePath,
    String secret, {
    required bool useRecoveryPath,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    if (bytes.length < _headerLength) {
      throw WrongPasswordException('Fichier chiffré invalide ou corrompu');
    }

    var offset = _magic.length;
    final passwordSalt = bytes.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final recoverySalt = bytes.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final nonce = bytes.sublist(offset, offset + _nonceLength);
    offset += _nonceLength;
    final wrappedByPassword = bytes.sublist(offset, offset + _wrappedKeyLength);
    offset += _wrappedKeyLength;
    final wrappedByRecovery = bytes.sublist(offset, offset + _wrappedKeyLength);
    offset += _wrappedKeyLength;
    final cipherWithTag = bytes.sublist(offset);

    final salt = useRecoveryPath ? recoverySalt : passwordSalt;
    final wrapped = useRecoveryPath ? wrappedByRecovery : wrappedByPassword;

    List<int> dataKeyBytes;
    try {
      dataKeyBytes = await _unwrapDataKey(wrapped, secret, salt);
    } on SecretBoxAuthenticationError {
      throw WrongPasswordException();
    }

    final macLength = _aesGcm.macAlgorithm.macLength;
    final cipherText = cipherWithTag.sublist(0, cipherWithTag.length - macLength);
    final macBytes = cipherWithTag.sublist(cipherWithTag.length - macLength);

    final List<int> plainBytes;
    try {
      plainBytes = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: SecretKey(dataKeyBytes),
      );
    } on SecretBoxAuthenticationError {
      throw WrongPasswordException();
    }

    final tempDir = await _tempDir();
    final tempPath = p.join(
      tempDir.path,
      '${_uuid.v4()}.db',
    );
    await File(tempPath).writeAsBytes(plainBytes, flush: true);
    await _registerManifestEntry(tempPath, filePath);

    return DecryptedDossier(tempPath, filePath);
  }

  /// Rechiffre le contenu de [tempPath] (modifié par l'application) vers
  /// [realPath], en conservant les enveloppes existantes de la clé de
  /// données (mot de passe + clé de récupération), puis supprime le
  /// fichier temporaire. Un nouveau nonce est utilisé à chaque appel.
  static Future<void> encryptFromTemp(
    String tempPath,
    String realPath,
    String password,
  ) async {
    final oldBytes = await File(realPath).readAsBytes();
    if (oldBytes.length < _headerLength) {
      throw WrongPasswordException('Fichier chiffré invalide ou corrompu');
    }
    var offset = _magic.length;
    final passwordSalt = oldBytes.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final recoverySalt = oldBytes.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    offset += _nonceLength; // ancien nonce, ignoré
    final wrappedByPassword =
        oldBytes.sublist(offset, offset + _wrappedKeyLength);
    offset += _wrappedKeyLength;
    final wrappedByRecovery =
        oldBytes.sublist(offset, offset + _wrappedKeyLength);

    List<int> dataKeyBytes;
    try {
      dataKeyBytes = await _unwrapDataKey(wrappedByPassword, password, passwordSalt);
    } on SecretBoxAuthenticationError {
      throw WrongPasswordException();
    }

    final plainBytes = await File(tempPath).readAsBytes();
    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _aesGcm.encrypt(
      plainBytes,
      secretKey: SecretKey(dataKeyBytes),
      nonce: nonce,
    );

    final header = BytesBuilder()
      ..add(_magic)
      ..add(passwordSalt)
      ..add(recoverySalt)
      ..add(nonce)
      ..add(wrappedByPassword)
      ..add(wrappedByRecovery);

    final output = BytesBuilder()
      ..add(header.toBytes())
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);

    await _atomicWrite(realPath, output.toBytes());
    await _removeTemp(tempPath);
  }

  /// Change le mot de passe (ré-enveloppe uniquement la clé de données,
  /// sans redéchiffrer/rechiffrer tout le contenu du fichier). Nécessite le
  /// mot de passe actuel pour retrouver la clé de données.
  static Future<void> rewrapWithNewPassword(
    String realPath,
    String currentPassword,
    String newPassword,
  ) async {
    await _rewrap(realPath, currentPassword, newPassword, useRecoveryPath: false);
  }

  /// Réinitialise le mot de passe à partir d'une clé de récupération valide,
  /// sans redéchiffrer/rechiffrer tout le contenu du fichier.
  static Future<void> resetPasswordViaRecoveryKey(
    String realPath,
    String recoveryKey,
    String newPassword,
  ) async {
    await _rewrap(realPath, recoveryKey, newPassword, useRecoveryPath: true);
  }

  /// Génère et applique une nouvelle clé de récupération (ré-enveloppe la
  /// clé de données sous cette nouvelle clé). Nécessite le mot de passe
  /// actuel. Retourne la nouvelle clé de récupération en clair (à afficher
  /// une seule fois).
  static Future<String> regenerateRecoveryKey(
    String realPath,
    String currentPassword,
  ) async {
    final bytes = await File(realPath).readAsBytes();
    if (bytes.length < _headerLength) {
      throw WrongPasswordException('Fichier chiffré invalide ou corrompu');
    }
    var offset = _magic.length;
    final passwordSalt = bytes.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    offset += _saltLength; // ancien sel de récupération, remplacé
    final nonce = bytes.sublist(offset, offset + _nonceLength);
    offset += _nonceLength;
    final wrappedByPassword = bytes.sublist(offset, offset + _wrappedKeyLength);
    offset += _wrappedKeyLength;
    offset += _wrappedKeyLength; // ancienne enveloppe de récupération, remplacée
    final payload = bytes.sublist(offset);

    List<int> dataKeyBytes;
    try {
      dataKeyBytes =
          await _unwrapDataKey(wrappedByPassword, currentPassword, passwordSalt);
    } on SecretBoxAuthenticationError {
      throw WrongPasswordException();
    }

    final newRecoveryKey = generateRecoveryKey();
    final newRecoverySalt = _randomBytes(_saltLength);
    final wrappedByRecovery =
        await _wrapDataKey(dataKeyBytes, newRecoveryKey, newRecoverySalt);

    final header = BytesBuilder()
      ..add(_magic)
      ..add(passwordSalt)
      ..add(newRecoverySalt)
      ..add(nonce)
      ..add(wrappedByPassword)
      ..add(wrappedByRecovery);

    final output = BytesBuilder()
      ..add(header.toBytes())
      ..add(payload);

    await _atomicWrite(realPath, output.toBytes());
    return newRecoveryKey;
  }

  static Future<void> _rewrap(
    String realPath,
    String currentSecret,
    String newPassword, {
    required bool useRecoveryPath,
  }) async {
    final bytes = await File(realPath).readAsBytes();
    if (bytes.length < _headerLength) {
      throw WrongPasswordException('Fichier chiffré invalide ou corrompu');
    }
    var offset = _magic.length;
    final passwordSalt = bytes.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final recoverySalt = bytes.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final nonce = bytes.sublist(offset, offset + _nonceLength);
    offset += _nonceLength;
    final wrappedByPassword = bytes.sublist(offset, offset + _wrappedKeyLength);
    offset += _wrappedKeyLength;
    final wrappedByRecovery = bytes.sublist(offset, offset + _wrappedKeyLength);
    offset += _wrappedKeyLength;
    final payload = bytes.sublist(offset);

    final currentWrapped = useRecoveryPath ? wrappedByRecovery : wrappedByPassword;
    final currentSalt = useRecoveryPath ? recoverySalt : passwordSalt;

    List<int> dataKeyBytes;
    try {
      dataKeyBytes =
          await _unwrapDataKey(currentWrapped, currentSecret, currentSalt);
    } on SecretBoxAuthenticationError {
      throw WrongPasswordException();
    }

    final newPasswordSalt = _randomBytes(_saltLength);
    final newWrappedByPassword =
        await _wrapDataKey(dataKeyBytes, newPassword, newPasswordSalt);

    final header = BytesBuilder()
      ..add(_magic)
      ..add(newPasswordSalt)
      ..add(recoverySalt)
      ..add(nonce)
      ..add(newWrappedByPassword)
      ..add(wrappedByRecovery);

    final output = BytesBuilder()
      ..add(header.toBytes())
      ..add(payload);

    await _atomicWrite(realPath, output.toBytes());
  }

  static Future<List<int>> _wrapDataKey(
    List<int> dataKeyBytes,
    String secret,
    List<int> salt,
  ) async {
    final wrapKey = await _argon2id().deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: salt,
    );
    // Nonce fixe (zéros) acceptable ici car la clé de wrap change à chaque
    // appel (nouveau sel Argon2id à chaque ré-enveloppement) — pas de
    // réutilisation clé+nonce.
    final fixedNonce = List<int>.filled(_nonceLength, 0);
    final box = await _aesGcm.encrypt(
      dataKeyBytes,
      secretKey: wrapKey,
      nonce: fixedNonce,
    );
    return [...box.cipherText, ...box.mac.bytes];
  }

  static Future<List<int>> _unwrapDataKey(
    List<int> wrapped,
    String secret,
    List<int> salt,
  ) async {
    final wrapKey = await _argon2id().deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: salt,
    );
    final macLength = _aesGcm.macAlgorithm.macLength;
    final cipherText = wrapped.sublist(0, wrapped.length - macLength);
    final macBytes = wrapped.sublist(wrapped.length - macLength);
    final fixedNonce = List<int>.filled(_nonceLength, 0);
    return _aesGcm.decrypt(
      SecretBox(cipherText, nonce: fixedNonce, mac: Mac(macBytes)),
      secretKey: wrapKey,
    );
  }

  static Future<void> _atomicWrite(String path, List<int> bytes) async {
    final tmp = '$path.tmp';
    await File(tmp).writeAsBytes(bytes, flush: true);
    await File(tmp).rename(path);
  }

  // ---------------------------------------------------------------------
  // Fichiers temporaires / résilience au crash
  // ---------------------------------------------------------------------

  static Future<Directory> _tempDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'SYCEBNL_tmp'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _manifestFile() async {
    final dir = await _tempDir();
    return File(p.join(dir.path, 'manifest.json'));
  }

  static Future<void> _registerManifestEntry(
    String tempPath,
    String realPath,
  ) async {
    final manifestFile = await _manifestFile();
    Map<String, dynamic> manifest = {};
    if (await manifestFile.exists()) {
      try {
        manifest = jsonDecode(await manifestFile.readAsString());
      } catch (_) {
        manifest = {};
      }
    }
    manifest[tempPath] = {
      'realPath': realPath,
      'openedAt': DateTime.now().toIso8601String(),
    };
    await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
  }

  static Future<void> _removeTemp(String tempPath) async {
    final file = File(tempPath);
    if (await file.exists()) {
      await file.delete();
    }
    final manifestFile = await _manifestFile();
    if (await manifestFile.exists()) {
      try {
        final manifest =
            jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        manifest.remove(tempPath);
        await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
      } catch (_) {
        // manifeste corrompu : ignoré, sera nettoyé au prochain démarrage.
      }
    }
  }

  /// À appeler une fois au démarrage de l'application : supprime les
  /// fichiers temporaires déchiffrés laissés par une session interrompue
  /// (crash) ainsi que les éventuels `.tmp` de ré-écriture atomique
  /// interrompue. Le fichier réel chiffré n'est jamais dans un état
  /// intermédiaire (grâce à l'écriture atomique tmp+rename), donc cette
  /// opération ne perd aucune donnée validée.
  static Future<void> cleanupStaleTempFiles() async {
    final dir = await _tempDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (name == 'manifest.json') continue;
        try {
          await entity.delete();
        } catch (_) {
          // fichier verrouillé ou déjà supprimé, ignoré.
        }
      }
    }
    final manifestFile = await _manifestFile();
    if (await manifestFile.exists()) {
      await manifestFile.writeAsString('{}', flush: true);
    }
  }
}
