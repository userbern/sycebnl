import 'package:flutter_test/flutter_test.dart';
import 'package:sycebnl_accounting/models/utilisateur.dart';

void main() {
  group('Utilisateur model', () {
    test('builds from map and exposes computed helpers', () {
      final utilisateur = Utilisateur.fromMap({
        'id': 3,
        'login': 'admin',
        'password': 'hash',
        'nom': 'Diallo',
        'prenom': 'Awa',
        'email': 'awa@example.com',
        'role': 'admin',
        'is_active': 1,
        'created_at': '2026-04-29T12:00:00.000Z',
        'updated_at': '2026-04-29T12:10:00.000Z',
        'deleted_at': null,
      });

      expect(utilisateur.id, 3);
      expect(utilisateur.login, 'admin');
      expect(utilisateur.passwordHash, 'hash');
      expect(utilisateur.fullName, 'Awa Diallo');
      expect(utilisateur.isAdmin, isTrue);
      expect(utilisateur.isActive, isTrue);
    });

    test('serializes to maps used by persistence layers', () {
      final utilisateur = Utilisateur(
        id: 9,
        login: 'user1',
        passwordHash: 'secret',
        nom: 'Kane',
        prenom: 'Moussa',
        email: 'moussa@example.com',
        role: 'utilisateur',
        isActive: false,
        createdAt: DateTime.parse('2026-04-29T12:30:00.000Z'),
        updatedAt: DateTime.parse('2026-04-29T12:31:00.000Z'),
      );

      final map = utilisateur.toMap();
      final usersMap = utilisateur.toUsersMap();

      expect(map['login'], 'user1');
      expect(map['password'], 'secret');
      expect(usersMap['password_hash'], 'secret');
      expect(usersMap['is_active'], 0);
      expect(usersMap['nom'], 'Kane');
    });
  });
}
