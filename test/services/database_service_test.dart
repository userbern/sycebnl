import 'package:flutter_test/flutter_test.dart';
import 'package:sycebnl_accounting/services/database_service.dart';

void main() {
  group('DatabaseService crypto helpers', () {
    test('hashPassword produces deterministic sha256 hashes', () {
      final hash = DatabaseService.hashPassword('secret123');

      expect(hash, hasLength(64));
      expect(hash, DatabaseService.hashPassword('secret123'));
      expect(hash, isNot(DatabaseService.hashPassword('another-secret')));
    });

    test('verifyPassword matches the provided hash', () {
      final hash = DatabaseService.hashPassword('monMotDePasse');

      expect(DatabaseService.verifyPassword('monMotDePasse', hash), isTrue);
      expect(DatabaseService.verifyPassword('wrong', hash), isFalse);
    });
  });
}
